require_relative '../spec_helper'
require "logstash/filters/local-classifier"
require "logstash/filters/elastic-db"
require "logstash/filters/classification-request"

describe LogStash::Filters::Empow::LocalClassifier do

    describe "sync'ed local database as a fallback" do
    	it "value isn't in memory, later fetched from local db" do
            local_db = instance_double(LogStash::Filters::Empow::PersistentKeyValueDB)
            allow(local_db).to receive(:query).and_return(nil)
            allow(local_db).to receive(:close)

    		classifier = described_class.new(5, 300, false, local_db)

            key = LogStash::Filters::Empow::ClassificationRequest.new("product_type", "product", "threat", true, true)

            expect(classifier.classify(key)).to be_nil

            allow(local_db).to receive(:query).and_return("intent")

            # allow backend thread to process the request
            res = nil

            for i in 1..10 do
                sleep 1

                res = classifier.classify(key)

                break if !res.nil?
            end

            expect(res).to eq("intent")
    	end
    end

    describe "no local database configured" do
        it "value isn't in memory" do
            classifier = described_class.new(5, 300, false, nil)

            key = "key-1"

            expect(classifier.classify(key)).to be_nil
        end
    end
end