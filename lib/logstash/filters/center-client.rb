require "rest-client"
require "json"
require 'aws-sdk'
require_relative 'cognito-client'
require_relative 'response'
require_relative 'utils'


module LogStash
  module Filters
    module Empow
      class ClassificationCenterClient
        include LogStash::Util::Loggable

        def initialize(username, password, aws_client_id, url_base)
          @logger = self.logger

          @token = nil
          @url_base = url_base
          
          aws_region = 'us-east-2'

          @cognito_client = LogStash::Filters::Empow::CognitoClient.new(username, password, aws_region, aws_client_id)

          @last_authenticate_minute = 0
        end

        public
        def authenticate
          # fixme: should check token expiration and throttle connections on failure
          
          @token = nil

          @logger.debug("reconnecting to the classfication center")

          current_minute = (Time.now.to_i / 60)
          if @last_authenticate_minute < current_minute
            @last_authenticate_minute = current_minute
            @last_minute_failed_login_count = 0
            @last_authentication_error = ''
          end

          # avoid too many authentication requests
          if @last_minute_failed_login_count < 3
            begin
              @token = @cognito_client.authenticate
            rescue Aws::CognitoIdentityProvider::Errors::NotAuthorizedException, Aws::CognitoIdentityProvider::Errors::UserNotFoundException, Aws::CognitoIdentityProvider::Errors::UserNotConfirmedException => e
              @logger.warn("unable to authenticate with classification center", :error => e)
              @last_authentication_error = e.to_s
              inc_unsuccessful_logins()
            rescue StandardError => e
              @logger.warn("unable to authenticate with classification center", :error => e.class.name)
              @last_authentication_error = e.class.name.to_s
              inc_unsuccessful_logins()
            end
          end

          return (!@token.nil?)
        end

        private def inc_unsuccessful_logins()
          @last_minute_failed_login_count = @last_minute_failed_login_count + 1
        end

        public
        def classify(requests)
          authenticate if @token.nil? # try connecting if not already connected

          res = nil

          begin
            res = classify_online(requests)

          rescue RestClient::Unauthorized, RestClient::Forbidden, RestClient::UpgradeRequired => err
            @logger.debug("reconnecting to the empow cloud", :error => err)

            if !authenticate
              return unauthorized_bulk_response(@last_authentication_error, requests)
            end
            
            begin
              res = classify_online(requests)
            rescue StandardError => e
              @logger.debug("encountered an unexpected error on the 2nd attempt", :error => e, :backtrace => e.backtrace)

              error_message = rescue_http_error_result(e)

              return bulk_error(error_message, requests)
            end

          rescue StandardError => e
            @logger.error("encountered an unexpected error while querying the center", :error => e)

            error_message = rescue_http_error_result(e)

            return bulk_error(error_message, requests)
          end

          if res.nil? || res.strip.length == 0
            return bulk_error("no content", requests)
          end

          parsed_json = nil

          begin
            parsed_json = JSON.parse(res)
          rescue StandardError => e
            @logger.error("unable to parse json", :json => res)
            return bulk_error("invalid request", requests)
          end

          return successful_response(requests, parsed_json)
        end

        private
        def rescue_http_error_result(http_error)
          if (http_error.nil? \
            or (!defined?(http_error.http_body) or LogStash::Filters::Empow::Utils.is_blank_string(http_error.http_body)))
            return http_error.to_s
          else
            err = http_error.http_body

            begin
              res = JSON.parse(err)
              msg = res['message']

              return err if LogStash::Filters::Empow::Utils.is_blank_string(msg)

              return msg
            rescue StandardError => e
              @logger.debug("unable to read message body", :error => e)
              return http_error.http_body
            end
          end
        end

        private
        def classify_online(bulk_requests)
          return nil if bulk_requests.nil? or bulk_requests.size == 0

          payload = Array.new(bulk_requests.size)

          bulk_size = bulk_requests.size

          bulk_size.times do |i|
            payload[i] = bulk_requests[i].to_h
          end

          payload_json = payload.to_json

          @logger.debug("before online request", :payload => payload_json)

          return RestClient::Request.execute(
            method:  :post, 
            url:     "#{@url_base}/intent",
            payload: payload_json,
            timeout: 30,
            headers: { content_type: 'application/json', accept: 'application/json', authorization: @token, Bulksize: bulk_size }
          ).body
        end

        private
        def unauthorized_bulk_response(error_message, requests)
          return bulk_error_by_type(LogStash::Filters::Empow::UnauthorizedReponse, error_message, requests)
        end

        private
        def bulk_error(error_message, requests)
          return bulk_error_by_type(LogStash::Filters::Empow::FailureResponse, error_message, requests)
        end

        private
        def bulk_error_by_type(my_type, error_message, requests)
          results = Hash.new

          requests.each do |req|
            res = my_type.new(error_message)
            results[req] = res
          end

          return results
        end

        def successful_response(requests, responses)

          results = Hash.new

          responses.each_with_index do |response, i|
            req = requests[i]
            res = nil

            status = response['responseStatus']

            case status
            when 'SUCCESS'
              res = LogStash::Filters::Empow::SuccessfulResponse.new(response)
            when 'IN_PROGRESS'
              res = LogStash::Filters::Empow::InProgressResponse.new(response)
            else
              failure_reason = response['failedReason']
              res = LogStash::Filters::Empow::FailureResponse.new(failure_reason)
            end

            results[req] = res
          end

          return results
        end

      end
    end
  end
end