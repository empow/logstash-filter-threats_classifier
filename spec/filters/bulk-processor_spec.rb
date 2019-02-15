require_relative '../spec_helper'
require "logstash/filters/classifier"
require "logstash/filters/local-classifier"
require "logstash/filters/classification-request"
require "logstash/filters/center-client"
require "logstash/filters/response"
require 'timecop'

describe LogStash::Filters::Empow::Classification::BulkProcessor do
#empow_user, empow_password, cache_size, ttl, async_local_db, elastic_hosts, elastic_index, elastic_username, elastic_password
	let(:time_between_attempts) { 1 }
	let(:batch_size) { 10 }
    let(:max_retries) { 5 }

    describe "test with mocked classifiers" do
    	it "single failed log" do

    		Timecop.freeze(Time.now)

    		req1 = "request1"
            val1 = {}
			val1[:retries] = 1
			val1[:task] = nil
			val1[:request] = req1
			val1[:last_executed] = Time.at(310953600)

			requests = Hash.new
            requests[req1] = val1

            local_classifier = instance_double(LogStash::Filters::Empow::LocalClassifier)
            allow(local_classifier).to receive(:classify).and_return(nil)
            allow(local_classifier).to receive(:close)

            center_result = {}
            center_result[req1] = LogStash::Filters::Empow::FailureReponse.new("failure1")

            online_classifer = instance_double(LogStash::Filters::Empow::ClassificationCenterClient)
            allow(online_classifer).to receive(:classify).and_return(center_result)

            bulk_processor = described_class.new(max_retries, batch_size, time_between_attempts, requests, online_classifer, local_classifier)

            expect(online_classifer).to receive(:classify)
            expect(local_classifier).to receive(:add_to_cache)

            bulk_processor.execute

            #expect(local_classifier).to receive(:add_to_cache)

            # expect(res).to be_nil
            #save_to_cache_and_db

            expect(requests[req1]).to be_nil

    		#Timecop.freeze(Time.now + time_between_attempts)
    		#Timecop.freeze(Time.now + 1 + time_between_attempts)
    	end

    	it "single successful log" do

    		Timecop.freeze(Time.now)

    		req1 = "request1"
            val1 = {}
			val1[:retries] = 1
			val1[:task] = nil
			val1[:request] = req1
			val1[:last_executed] = Time.at(310953600)

			requests = Hash.new
            requests[req1] = val1

            local_classifier = instance_double(LogStash::Filters::Empow::LocalClassifier)
            allow(local_classifier).to receive(:classify).and_return(nil)
            allow(local_classifier).to receive(:close)

            center_result = {}
            center_result[req1] = LogStash::Filters::Empow::SuccessfulReponse.new("result1")

            online_classifer = instance_double(LogStash::Filters::Empow::ClassificationCenterClient)
            allow(online_classifer).to receive(:classify).and_return(center_result)

            bulk_processor = described_class.new(max_retries, batch_size, time_between_attempts, requests, online_classifer, local_classifier)

            expect(online_classifer).to receive(:classify)
            expect(local_classifier).to receive(:save_to_cache_and_db)

            bulk_processor.execute

            expect(requests[req1]).to be_nil
    	end
    end
end