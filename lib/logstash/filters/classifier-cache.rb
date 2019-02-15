require 'time'
require "lru_redux"

module LogStash
  module Filters
    module Empow
      class ClassifierCache
        include LogStash::Util::Loggable

        def initialize(cache_size, ttl)
          @logger ||= self.logger

          @logger.debug("cache size #{cache_size}")

          @lru_cache ||= LruRedux::TTL::ThreadSafeCache.new(cache_size, ttl)
        end

        def classify(key)
          return nil if key.nil?

          tuple = @lru_cache[key]

          return nil if tuple.nil?

          expiration_time = tuple[:expiration_time]

          if Time.now > expiration_time
            @lru_cache.evict(key)
            return nil
          end

          res = tuple[:val]

          return res
        end

        def put(key, val, expiration_time)
          return if key.nil?

          @logger.debug("caching new entry", :key => key, :val => val)

          tuple = {}
          tuple[:val] = val
          tuple[:expiration_time] = expiration_time

          @lru_cache[key] = tuple
        end
      end
    end
  end
end