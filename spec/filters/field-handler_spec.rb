require_relative '../spec_helper'
require "logstash/filters/field-handler"
require "logstash/event"

describe LogStash::Filters::Empow::FieldHandler do

	let(:handler) { described_class.new("product_type", "product", "term", "is_src_internal", "is_dst_internal") }

    describe "init" do
    	it "src internal field empty" do
            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1"})
            res = handler.event_to_classification_request(event)
            expect(res).not_to be_nil
            expect(res['is_src_internal']).to be true
            expect(event.get("empow_warnings")).to include("src_internal_wrong_value")
    	end

    	it "dst internal field empty" do
            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1"})
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_dst_internal']).to be true
            expect(event.get("empow_warnings")).to include("dst_internal_wrong_value")
    	end

    	it "src internal field numeric value" do
            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1", "is_src_internal" => 1})
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_src_internal']).to be true
            expect(event.get("empow_warnings")).not_to include("src_internal_wrong_value")
    	end

        it "src internal field wrong value" do
            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1"}, "is_src_internal" => 11)
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_src_internal']).to be true
            expect(event.get("empow_warnings")).to include("src_internal_wrong_value")
        end

    	it "dst internal field numeric value" do
            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1", "is_dst_internal" => 1})
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_dst_internal']).to be true
            expect(event.get("empow_warnings")).not_to include("dst_internal_wrong_value")
    	end

        it "dst internal field wrong numeric value" do
            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1"}, "is_dst_internal" => 11)
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_dst_internal']).to be true
            expect(event.get("empow_warnings")).to include("dst_internal_wrong_value")
        end

        it "dst internal field wrong value" do
            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1"}, "is_dst_internal" => [])
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_dst_internal']).to be true
            expect(event.get("empow_warnings")).to include("dst_internal_wrong_value")
        end

    	it "src internal field valid values" do
            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1", "is_src_internal" => true})
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_src_internal']).to be true
            expect(event.get("empow_warnings")).not_to include("src_internal_wrong_value")

            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1", "is_src_internal" => false})
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_src_internal']).to be false
            expect(event.get("empow_warnings")).not_to include("src_internal_wrong_value")
    	end

    	it "dst internal field valid values" do
            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1", "is_dst_internal" => true})
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_dst_internal']).to be true
            expect(event.get("empow_warnings")).not_to include("dst_internal_wrong_value")

            event = LogStash::Event.new("product_type" => "IDS", "product" => "some_av", "term" => {"signature" => "name1",  "is_dst_internal" => false})
            res = handler.event_to_classification_request(event)
            expect(res.nil?).to be false
            expect(res['is_dst_internal']).to be false
            expect(event.get("empow_warnings")).not_to include("dst_internal_wrong_value")
    	end

        it "test nested threat structure" do
            my_handler = described_class.new("product_type", "product", 'threat', "is_src_internal", "is_dst_internal")
            event = LogStash::Event.new("product_type" => "IDS", "product" => "snort", "threat" => {"signature" => "name1"})
            res = my_handler.event_to_classification_request(event)
            expect(res['term']['signature']).to eq('name1')
        end
    end
end