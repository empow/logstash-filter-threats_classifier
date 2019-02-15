require_relative '../spec_helper'
require 'timecop'
require "logstash/filters/classifier-cache"

describe LogStash::Filters::Empow::ClassifierCache do

    describe "initialize signaure test" do
    	it "test expiration by cache default ttl" do
    		cache = described_class.new(5, 60)

            expect(cache.classify("k")).to be_nil

            Timecop.freeze(Time.now)
            
            cache.put("k", "v", Time.now + 24*60*60)

            Timecop.freeze(Time.now + 59)

            expect(cache.classify("k")).to eq("v")

            Timecop.freeze(Time.now + 61)

            expect(cache.classify("k")).to be_nil
    	end

        it "test expiration by entry ttl" do
            cache = described_class.new(5, 60)

            expect(cache.classify("k")).to be_nil

            Timecop.freeze(Time.now)
            
            cache.put("k", "v", Time.now + 30)

            Timecop.freeze(Time.now + 29)

            expect(cache.classify("k")).to eq("v")

            Timecop.freeze(Time.now + 31)

            expect(cache.classify("k")).to be_nil
        end
    end
end