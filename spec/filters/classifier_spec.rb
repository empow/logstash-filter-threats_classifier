require_relative '../spec_helper'
require "logstash/filters/classifier"
require "logstash/filters/local-classifier"
require "logstash/filters/classification-request"
require "logstash/filters/center-client"

describe LogStash::Filters::Empow::Classifier do
#empow_user, empow_password, cache_size, ttl, async_local_db, elastic_hosts, elastic_index, elastic_username, elastic_password
    describe "test with mocked classifiers" do
    	it "log with no result" do

            local_classifier = instance_double(LogStash::Filters::Empow::LocalClassifier)
            allow(local_classifier).to receive(:classify).and_return(nil)
            allow(local_classifier).to receive(:close)

            online_classifer = instance_double(LogStash::Filters::Empow::ClassificationCenterClient)
            allow(online_classifer).to receive(:classify).and_return(nil)

            req = "request-1"

            classifier = described_class.new(online_classifer, local_classifier)

            expect(local_classifier).to receive(:classify).with(req)

            expect(online_classifer).to receive(:classify)

            res = classifier.classify(req)

            sleep 10

            expect(res).to be_nil

    		classifier.close
    	end


        it "log w/o results locally, online classification arrives later" do

            # local_classifier = instance_double(LogStash::Filters::Empow::LocalClassifier)
            # allow(local_classifier).to receive(:classify).and_return(nil)
            # allow(local_classifier).to receive(:close)

            # online_classifer = instance_double(LogStash::Filters::Empow::ClassificationCenterClient)
            # allow(online_classifer).to receive(:classify).and_return(nil)

            # req = LogStash::Filters::Empow::ClassificationRequest.new('anti-malware', 'lastline', 'assaf.clicker', nil)

            # #online_classifer, local_classifier, local_db_cache, async_local_db, online_classifier_threads
            # classifier = described_class.new(online_classifer, local_classifier, nil, true, 1)

            # expect(local_classifier).to receive(:classify).with(req.get_key_by_term())
            # expect(local_classifier).not_to receive(:classify).with(req.get_key_by_hash())

            # expect(online_classifer).to receive(:classify)

            # res = classifier.classify(req)

            # #allow(Time).to receive(:now).and_return(5555555)

            # expect(res).to be_nil

            # sleep 60

            # i = 20

            # while i < 0 do

            #     result = classifier.classify(req)
            #     p "i: #{i} result: #{result}"

            #     sleep 5
            #     i = i - 1
            # end

            # classifier.close
        end
    end
end