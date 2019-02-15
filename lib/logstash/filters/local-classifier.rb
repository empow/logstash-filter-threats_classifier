require "concurrent"
require_relative 'classifier-cache'

module LogStash; module Filters; module Empow;
	class LocalClassifier
		include LogStash::Util::Loggable

		def initialize(cache_size, ttl, async_local_db, local_db)
			@logger ||= self.logger

			@logger.debug("initializing in memory cache")
			@logger.debug("cache size #{cache_size}")
			@logger.debug("cache ttl #{ttl}")

			@cache ||= LogStash::Filters::Empow::ClassifierCache.new(cache_size, ttl)
			@ttl = ttl

			@local_db ||= local_db

			@local_db_workers ||= Concurrent::ThreadPoolExecutor.new(min_threads: 1, max_threads: 1)
			@async_local_db ||= async_local_db
		end

		def close
			@logger.debug("shutting down local classifier")

			@local_db_workers.shutdown if !@local_db.nil?

			@local_db_workers.wait_for_termination(1)
			@logger.debug("local classifier shut down")
		end


		def classify(key)
			if !key.nil?
				cached_result = @cache.classify(key)
				return cached_result if !cached_result.nil?
			end

			return classify_using_local_database(key)
		end

		def add_to_cache(key, val, expiration_time)
			return if key.nil?

			@logger.debug? and @logger.info("adding #{key} to cache")

			@cache.put(key, val, Time.now+3600)
		end

		def save_to_cache_and_db(key, val, expiration_time)
			return if key.nil?

			@logger.debug? and @logger.info("adding #{key} to the local db and cache")

			product_type = key[:product_type]
			product = key[:product]
			term = key[:term]

			doc_id = "#{product_type}-#{product}-term"

			@local_db.save(doc_id, product_type, product, term, val) if !@local_db.nil?
			add_to_cache(key, val, expiration_time)
		end

		def read_from_local_database(key)
			res = @local_db.query(key[:product_type], key[:product], key[:term])

			if !res.nil?
				@logger.debug("adding result from db to local cache")
				add_to_cache(key, res, Time.now + @ttl)
			end

			return res
		end

		def read_from_local_database_async(key)
			@local_db_workers.post do
				read_from_local_database(key)
			end
		end

		def classify_using_local_database(key)
			return nil if @local_db.nil? # if a local db wasn't configured

			if (@async_local_db)
				read_from_local_database_async(key)
				return nil
			end

			return read_from_local_database(key)
		end
	end
end; end; end