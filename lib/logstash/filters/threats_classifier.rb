# encoding: utf-8
require "logstash/filters/base"
require "elasticsearch"

require_relative "elastic-db"
require_relative "local-classifier"
require_relative "classifier"
require_relative "center-client"
require_relative "plugin-logic"
require_relative "utils"

#
class LogStash::Filters::Threats_Classifier < LogStash::Filters::Base

  config_name "threats_classifier"

  # The username (typically your email address), to access the classification center
  config :username, :validate => :string, :required => true

  # The password to access the classification center
  config :password, :validate => :string, :required => true

  # Set this value only if using the complete empow stack; leave unchanged if using the empow Elastic open source plugin or module
  config :authentication_hash, :validate => :string, :default => '131n94ktfg7lj8hlpnnbkuiql1'

  # The number of responses cached locally
  config :cache_size, :validate => :number, :default => 10000

  # Max number of requests pending response from the classification center
  config :max_pending_requests, :validate => :number, :default => 10000

  # Timeout for response from classification center (seconds)
  config :pending_request_timeout, :validate => :number, :default => 60

  # Maximum number of concurrent threads (workers) classifying logs using the classification center
  config :max_classification_center_workers, :validate => :number, :default => 5

  # Classification center bulk request size (requests)
  config :bulk_request_size, :validate => :number, :default => 50

  # Time (seconds) to wait for batch to fill on classifciation center, before querying for the response
  config :bulk_request_interval, :validate => :number, :default => 2

  # Max number of classification center request retries
  config :max_query_retries, :validate => :number, :default => 5

  # Time (seconds) to wait between queries to the classification center for the final response to a request; the classification center will return an 'in-progress' response if queried before the final response is ready
  config :time_between_queries, :validate => :number, :default => 10

  # The name of the product type field in the log
  # Example: If the log used log_type for the product type, configure the plugin like this:
  # [source,ruby]
  #    filter {
  #      empowclassifier {
  #        username => "happy"
  #        password => "festivus"
  #        product_type_field => "log_type"
  #      }
  #    }
  config :product_type_field, :validate => :string, :default => "product_type"

  # The name of the product name field in the log
  # Example: If the log used product for the product name, configure the plugin like this:
  # [source,ruby]
  #    filter {
  #      empowclassifier {
  #        username => "happy"
  #        password => "festivus"
  #        product_name_field => "product"
  #      }
  #    }
  config :product_name_field, :validate => :string, :default => "product_name"

  # The name of the field containing the terms sent to the classification center
  config :threat_field, :validate => :string, :default => "threat"

  # Indicates whether the source field is internal to the user’s network (for example, an internal host/mail/user/app)
  config :src_internal_field, :validate => :string, :default => "is_src_internal"

  # Indicates whether the dest field is internal to the user’s network (for example, an internal host/mail/user/app)
  config :dst_internal_field, :validate => :string, :default => "is_dst_internal"

  # changes the api root for customers of the commercial empow stack
  config :base_url, :validate => :string, :default => ""

  config :async_local_cache, :validate => :boolean, :default => true

  # elastic config params
  ########################

  config :elastic_hosts, :validate => :array

  # The index or alias to write to
  config :elastic_index, :validate => :string, :default => "empow-intent-db"

  config :elastic_user, :validate => :string
  config :elastic_password, :validate => :password

  # failure tags
  ###############
  config :tag_on_product_type_failure, :validate => :array, :default => ['_empow_no_product_type']
  config :tag_on_signature_failure, :validate => :array, :default => ['_empow_no_signature']
  config :tag_on_timeout, :validate => :array, :default => ['_empow_classifier_timeout']
  config :tag_on_error, :validate => :array, :default => ['_empow_classifier_error']

  CLASSIFICATION_URL = 'https://intent.cloud.empow.co'
  CACHE_TTL = (24*60*60)

  public
  def register
    @logger.info("registering empow classifcation plugin")

    validate_params()

    local_db = create_local_database

    local_classifier = LogStash::Filters::Empow::LocalClassifier.new(@cache_size, CACHE_TTL, @async_local_cache, local_db)

    base_url = get_effective_url()
    online_classifier = LogStash::Filters::Empow::ClassificationCenterClient.new(@username, @password, @authentication_hash, base_url)

    classifer = LogStash::Filters::Empow::Classifier.new(online_classifier, local_classifier, @max_classification_center_workers, @bulk_request_size, @bulk_request_interval, @max_query_retries, @time_between_queries)

    field_handler = LogStash::Filters::Empow::FieldHandler.new(@product_type_field, @product_name_field, @threat_field, @src_internal_field, @dst_internal_field)

    @plugin_core ||= LogStash::Filters::Empow::PluginLogic.new(classifer, field_handler, @pending_request_timeout, @max_pending_requests, @tag_on_timeout, @tag_on_error)

    @logger.info("empow classifcation plugin registered")
  end # def register

  private
  def get_effective_url
    if (@base_url.nil? or @base_url.strip == 0)
      return CLASSIFICATION_URL
    end

    return CLASSIFICATION_URL
  end

  private
  def validate_params
    raise ArgumentError, 'threat field cannot be empty' if LogStash::Filters::Empow::Utils.is_blank_string(@threat_field)

    raise ArgumentError, 'bulk_request_size must be an positive number between 1 and 1000' if (@bulk_request_size < 1 or @bulk_request_size > 1000)

    raise ArgumentError, 'bulk_request_interval must be an greater or equal to 1' if (@bulk_request_interval < 1)
  end

  def close
    @logger.info("closing the empow classifcation plugin")

    @plugin_core.close

    @logger.info("empow classifcation plugin closed")
  end

  def periodic_flush
    true
  end

  public def flush(options = {})
    @logger.debug("entered flush")

    events_to_flush = []

    begin
      parked_events = @plugin_core.flush(options)

      parked_events.each do |event|
        event.uncancel

        events_to_flush << event
      end

    rescue StandardError => e
      @logger.error("encountered an exception while processing flush", :error => e)
    end

    @logger.debug("flush ended", :flushed_event_count => events_to_flush.length)

    return events_to_flush
  end

  public def filter(event)
    res = event

    begin
      res = @plugin_core.classify(event)

      if res.nil?
        return
      end

      # event was classified and returned, not some overflow event
      if res.equal? event
        filter_matched(event)

        return
      end

      # got here with a parked event
      filter_matched(res)

      @logger.debug("filter matched for overflow event", :event => res)

      yield res

    rescue StandardError => e
      @logger.error("encountered an exception while classifying", :error => e, :event => event, :backtrace => e.backtrace)

      @tag_on_error.each{|tag| event.tag(tag)}
    end
  end # def filter

  private def create_local_database
    # if no elastic host has been configured, no local db should be used
    if @elastic_hosts.nil?
      @logger.info("no local persisted cache is configured")
      return nil
    end

    begin
      return LogStash::Filters::Empow::PersistentKeyValueDB.new(:elastic_hosts, :elastic_user, :elastic_password, :elastic_index)
    rescue StandardError => e
      @logger.error("caught an exception while trying to configured persisted cache", e)
    end

    return nil
  end
end
