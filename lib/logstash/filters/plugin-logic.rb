require 'time'
require "concurrent"
require_relative "classification-request"
require_relative "field-handler"
require_relative 'response'
require_relative 'utils'

module LogStash; module Filters; module Empow;
	class PluginLogic
		include LogStash::Util::Loggable

		def initialize(classifer, field_handler, max_parking_time, max_parked_events, tag_on_timeout, tag_on_error)
			@logger ||= self.logger
			#@logger.info("initializing classifier")

			@field_handler = field_handler

			@max_parking_time = max_parking_time
			@max_parked_events = max_parked_events
			@tag_on_timeout = tag_on_timeout
			@tag_on_error = tag_on_error

			@classifer = classifer
			@parked_events = Concurrent::Array.new
		end

		def close
			@classifer.close
		end

		def classify(event)
			request = @field_handler.event_to_classification_request(event)

			if request.nil?
				@tag_on_error.each{|tag| event.tag(tag)}
				return event
			end

			if classify_event(request, event)
				return event
			else
				park(event)

				if @parked_events.length > @max_parked_events
					tuple = @parked_events.shift
					
					if !tuple.nil?
						unparked_event = tuple[:event]
						unparked_event.uncancel
						return unparked_event
					end
				end

				return nil
			end
		end

		def flush(options = {})
			# tag flushed events, 
			events_to_flush = []

      		if options[:final] # indicating "final flush" special event, flush everything
      			while tuple = @parked_events.shift do
      				events_to_flush << tuple[:event]
      			end
      		else
      			@parked_events.delete_if do |tuple|
      				process_parked_event(tuple, events_to_flush)
      			end
      		end

      		return events_to_flush
		end

		private def process_parked_event(tuple, events_to_flush)
			event = tuple[:event]
			request = @field_handler.event_to_classification_request(event)

			begin
				res = @classifer.classify(request)

				if (parking_time_expired(tuple) or is_valid_classification(res))
					tag_event(res, event)

					# if we're releasing this event based on time expiration, tag it with timeout
					if res.nil? or !res.is_final
						@tag_on_timeout.each{|tag| event.tag(tag)}
					end

					events_to_flush << event
					return true
				end
				
			rescue StandardError => e
				@logger.error("an error occured while processing event, event flushed backed to the stream", :request => request, :backtrace => e.backtrace)
				return true # so that this event will be flushed out of the plugin
			end

			return false
		end

		private
		def is_unauthorized(classification)
			return (!classification.nil? and classification.kind_of?(LogStash::Filters::Empow::UnauthorizedReponse))
		end

		private
		def classify_event(request, event)
			res = @classifer.classify(request)

			if is_valid_classification(res)
				tag_event(res, event)
				return true
			end

			return false
		end

  		private
  		def is_valid_classification(classification)
			return (!classification.nil? and classification.is_final())
  		end

		private
		def tag_event(classification, event)
			return if classification.nil?

			responseBody = classification.response

			@logger.debug("classification response", :classification => responseBody)

			response = responseBody["response"]

			if !response.nil? && response.size > 0
				response.each do |k, v|
					event.set("[empow_classification_response][#{k}]", v)
				end
			end

			if !classification.is_successful()
				@tag_on_error.each{|tag| event.tag(tag)}

				if (!responseBody.nil?)
					LogStash::Filters::Empow::Utils.add_error(event, responseBody)
				end
			end
		end

		private
		def park(event)
			tuple = {}
			tuple[:event] = event
			tuple[:time] = Time.now

			@parked_events << tuple

			event.cancel # don't stream this event just yet ...
		end
		
		private
		def parking_time_expired(tuple)
			return (Time.now - tuple[:time]) > @max_parking_time
		end
	end

end; end; end