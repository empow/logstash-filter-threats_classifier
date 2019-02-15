require 'thread'
require 'time'
java_import java.util.concurrent.ArrayBlockingQueue
java_import java.util.concurrent.TimeUnit
java_import java.lang.InterruptedException

require_relative 'response'

module LogStash; module Filters; module Empow;
	class Classifier
		include LogStash::Util::Loggable

		MAX_CONCURRENT_REQUESTS = 10000
		BATCH_TIMEOUT = 10

		def initialize(online_classifer, local_classifier, online_classification_workers, batch_size, batch_interval, max_retries, time_between_queries)
			@logger ||= self.logger

			@logger.info("initializing classifier")

			@local_classifier = local_classifier
			@online_classifer = online_classifer
			@batch_interval = batch_interval
			@time_between_queries = time_between_queries

			@inflight_requests = Concurrent::Hash.new
			@new_request_queue = java.util.concurrent.ArrayBlockingQueue.new(MAX_CONCURRENT_REQUESTS)

			@bulk_processor = Classification::BulkProcessor.new(max_retries, batch_size, time_between_queries, @inflight_requests, online_classifer, local_classifier, online_classification_workers)

			@worker_pool = Concurrent::FixedThreadPool.new(1)

			@worker_pool.post do
				while @worker_pool.running? do
					begin
						management_task()
					rescue StandardError => e
						@logger.error("encountered an error while running the management task", :error => e, :backtrace => e.backtrace)
					end
				end
			end
			@logger.debug("classifier initialized")

			@last_action_time = Time.now
		end

		public
		def close
			@logger.info("shutting down empow's classifcation plugin")

			@inflight_requests.clear()

			@bulk_processor.close

			@worker_pool.kill()
			@worker_pool.wait_for_termination(5)

			@logger.info("empow classifcation plugin closed")
		end

		private
		def management_task
			begin
				current_time = Time.now

				diff = (current_time - @bulk_processor.get_last_execution_time()).round

				sleep_time = @batch_interval - diff

				sleep_time = 0 if sleep_time < 0 # in case the rounding caused the number to be smaller than zero

				dequeued_request = nil
				begin
					dequeued_request = @new_request_queue.poll(sleep_time, TimeUnit::SECONDS)
				rescue java.lang.InterruptedException => e
				end

				# if this is a 'tick'
				if dequeued_request.nil?
					@bulk_processor.flush_current_batch
				else
					@bulk_processor.add_to_batch(dequeued_request)
				end

				# skip the 'tick' if the timer hasn't expired
				return if current_time - @last_action_time < @time_between_queries

				@last_action_time = current_time
						
				@bulk_processor.retry_queued_requests()
			rescue StandardError => e
				@logger.error("encountered an error while running the management task", :error => e, :backtrace => e.backtrace)
			end
		end

		public
		def classify(request)
			return nil if request.nil?
			
			res = @local_classifier.classify(request)
			
			@logger.trace("cached result", :request => request, :res => res)
			
			return res if !res.nil?

			request_online_classifiction(request)

			return nil
		end

		private
		def request_online_classifiction(req)
			existing_request = @inflight_requests[req]
			
			return if !existing_request.nil? # request already handled by a worker

			@logger.debug("adding request to online classification queue", :request => req)

			task = create_task(req)

			# mark request as in progress
			@inflight_requests[req] = task

			res = @new_request_queue.offer(req)

			@logger.warn("queue full, request reject", :request => req) if !res
		end

		private
		def create_task(request)
			tuple = {}
			tuple[:retries] = 0
			tuple[:request] = request
			tuple[:last_executed] = Time.at(310953600)

			return tuple
		end
	end # class Classifier

	module Classification

		class BulkProcessor
			include LogStash::Util::Loggable

			ERROR_TTL_SECS = 60
			THREAD_IDLE_TIME = 60
			BATCH_TIMEOUT = 10

			public
			def initialize(max_retries, batch_size, sec_between_attempts, requests_queue, online_classifer, local_classifier, max_concurrent_threads)
				@logger ||= self.logger

				@max_retries = max_retries
				@max_batch_size = batch_size
				@sec_between_attempts = sec_between_attempts
				@requests_queue = requests_queue
				@online_classifer = online_classifer
				@local_classifier = local_classifier

				@online_classification_workers = Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: max_concurrent_threads, idletime: THREAD_IDLE_TIME)

				clear_batch(Time.now)
			end

			public
			def close
				@online_classification_workers.kill()
				@online_classification_workers.wait_for_termination(10)
			end

			public
			def add_to_batch(request)				
				# add the new request to the batch
				@current_batch_size = @current_batch_size + 1
				@current_batch << request

				flush_current_batch
			end

			public
			def flush_current_batch
				current_time = Time.now

				# check if the current batch is full or timed out
				if (@current_batch_size == @max_batch_size \
					or (@current_batch_size > 0 and (current_time - @last_execution_time) > BATCH_TIMEOUT))

					bulk_size = @current_batch_size
					batch = @current_batch

					@online_classification_workers.post do
						st = Time.now
						classify_online(batch)
						et = Time.now
						diff = (et - st)

						@logger.debug("response received", :bulk_size => bulk_size, :time => diff)
					end
					
					clear_batch(current_time)
				elsif @current_batch_size == 0
					@last_execution_time = current_time
				end
			end

			public
			def get_last_execution_time
				return @last_execution_time
			end

			private
			def clear_batch(current_time)
				@current_batch = Array.new
				@current_batch_size = 0
				@last_execution_time = current_time
			end

			public
			def retry_queued_requests
				@logger.debug("retrying queued requests")

				current_time = Time.now
				batch_size = 0
				batch = Array.new

				@requests_queue.each do |k, v|
					last_execution_time = v[:last_executed]

					if batch_size == @max_batch_size
						@online_classification_workers.post do
							classify_online(batch)
						end
						
						batch_size = 0
						batch = Array.new
					end

					if last_execution_time + @sec_between_attempts > current_time
						next
					end

					batch << k

					v[:last_executed] = current_time
					v[:retries] = v[:retries] + 1

					batch_size = batch_size + 1
				end

				if batch_size > 0
					@online_classification_workers.post do
						classify_online(batch)
					end
				end

				# remove requests that were in the queue for too long
				@requests_queue.delete_if {|key, value| value[:retries] >= @max_retries }
			end

			private
			def classify_online(bulk_request)

				results = nil
				current_time = Time.now

				batch = Array.new

				bulk_request.each do |req|
					task = @requests_queue[req]

					next if task.nil? # resolved by an earlier thread

					task[:last_executed] = current_time
					task[:retries] = task[:retries] + 1

					batch << req
				end

				begin
					results = @online_classifer.classify(batch)
				rescue StandardError => e
					@logger.debug("bulk request ended with a failure, all requests will be removed from queue", :error => e, :backtrace => e.backtrace)
					
					batch.each do |req|
						@requests_queue.delete(request)
					end
				end

				if results.size != batch.size
					@logger.warn("response array isn't the same size as result array. requests: #{batch.size}. results: #{results.size}")
					return
				end

				results.each do |request, res|
					@logger.debug("processing response", :request => request, :response => res)
					
					begin
						expiration_time = Time.now + get_response_ttl(res)

						if res.is_successful
							# validate the response if needed
							# put the result in memory and in the local db
							@local_classifier.save_to_cache_and_db(request, res, expiration_time)
						else
							@local_classifier.add_to_cache(request, res, expiration_time) # log the failed result for tagging
						end
					rescue StandardError => e
						@logger.error("encountered an error while trying to process result", :request => request, :error => e, :backtrace => e.backtrace)
					end

					if res.is_final # in case of anti-malware, the result may change till the classification process is done
						@requests_queue.delete(request)
					end
				end
			end

			private def get_response_ttl(res)
				return ERROR_TTL_SECS if !res.is_successful

				responseBody = res.response

				ttl = responseBody['ttlseconds']

				if ttl.nil? or ttl < 0
					ttl = 60
				end

				return ttl
			end

		end # class BulkProcessor

	end # module Classification

end; end; end