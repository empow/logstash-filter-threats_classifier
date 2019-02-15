require_relative '../spec_helper'
require "logstash/event"
require "logstash/filters/classifier"
require "logstash/filters/plugin-logic"

describe LogStash::Filters::Empow::PluginLogic do

    let(:intent_res1) { {"p1" => "s1"} }
    let(:response_body1) { {'response' => intent_res1 } }
    let(:sample_response) { LogStash::Filters::Empow::SuccessfulReponse.new(response_body1) }

    describe "test classification" do
    	
    	it "event with warm classification" do
    	   event = LogStash::Event.new("my_product_type" => "ids", "my_product" => "some_av", "my_term" => "name1", "my_hash" => "hash1")

            field_handler = instance_double(LogStash::Filters::Empow::FieldHandler)
            allow(field_handler).to receive(:event_to_classification_request).and_return("request")

            classifier = instance_double(LogStash::Filters::Empow::Classifier)
            allow(classifier).to receive(:classify).and_return(sample_response)

            plugin_logic = described_class.new(classifier, field_handler, 60, 1, ['_timeout'], ['_error'])

            expect(field_handler).to receive(:event_to_classification_request)
            expect(classifier).to receive(:classify)

            classified_event = plugin_logic.classify(event)

            expect(classified_event).to eq(event)
            expect(classified_event.get("empow_intent")).to eq(intent_res1)
    	end

    	it "event with cold classification is parked and then unparked only once" do
    		event = LogStash::Event.new("my_product_type" => "ids", "my_product" => "some_av", "my_term" => "name1", "my_hash" => "hash1")

            field_handler = instance_double(LogStash::Filters::Empow::FieldHandler)
            allow(field_handler).to receive(:event_to_classification_request).and_return("request")
		    allow(Time).to receive(:now).and_return(10)

            classifier = instance_double(LogStash::Filters::Empow::Classifier)
            allow(classifier).to receive(:classify).and_return(nil, nil, sample_response)

            plugin_logic = described_class.new(classifier, field_handler, 60, 1, ['_timeout'], ['_error'])

            expect(classifier).to receive(:classify)

            classified_event = plugin_logic.classify(event)
            expect(classified_event).to be_nil

            allow(Time).to receive(:now).and_return(20)

            expect(classifier).to receive(:classify)
            flushed_events = plugin_logic.flush
            expect(flushed_events).to be_empty

            allow(Time).to receive(:now).and_return(30)
            expect(classifier).to receive(:classify)

            flushed_events = plugin_logic.flush
            expect(flushed_events).not_to be_empty
    	end

    	it "event unparked after time expired" do
    		event = LogStash::Event.new("my_product_type" => "ids", "my_product" => "some_av", "my_term" => "name1", "my_hash" => "hash1")

            field_handler = instance_double(LogStash::Filters::Empow::FieldHandler)
            allow(field_handler).to receive(:event_to_classification_request).and_return("request")
            allow(Time).to receive(:now).and_return(10)

            classifier = instance_double(LogStash::Filters::Empow::Classifier)
            allow(classifier).to receive(:classify).and_return(nil)

            plugin_logic = described_class.new(classifier, field_handler, 60, 1, ['_timeout'], ['_error'])

            expect(classifier).to receive(:classify)

            classified_event = plugin_logic.classify(event)
            expect(classified_event).to be_nil

            allow(Time).to receive(:now).and_return(20)

            expect(classifier).to receive(:classify)
            flushed_events = plugin_logic.flush
            expect(flushed_events).to be_empty

            allow(Time).to receive(:now).and_return(100)
            expect(classifier).to receive(:classify)

            flushed_events = plugin_logic.flush
            expect(flushed_events).not_to be_empty

            insist { flushed_events[0].get("tags") }.include?("_timeout")
    	end

    	it "too many parked events" do
            event1 = LogStash::Event.new("my_product_type" => "ids", "my_product" => "some_av", "my_term" => "name1", "my_hash" => "hash1")
            event2 = LogStash::Event.new("my_product_type" => "ids", "my_product" => "some_av", "my_term" => "name2", "my_hash" => "hash2")

            field_handler = instance_double(LogStash::Filters::Empow::FieldHandler)
            allow(field_handler).to receive(:event_to_classification_request).and_return("request")
            allow(Time).to receive(:now).and_return(10)

            classifier = instance_double(LogStash::Filters::Empow::Classifier)
            allow(classifier).to receive(:classify).and_return(nil)

            plugin_logic = described_class.new(classifier, field_handler, 60, 1, ['_timeout'], ['_error'])

            expect(classifier).to receive(:classify)

            classified_event = plugin_logic.classify(event1)
            expect(classified_event).to be_nil

            classified_event = plugin_logic.classify(event2)
            expect(classified_event).to eq(event1)

            allow(Time).to receive(:now).and_return(20)
            flushed_events = plugin_logic.flush
            expect(flushed_events).to be_empty

            allow(Time).to receive(:now).and_return(100)
            flushed_events = plugin_logic.flush
            expect(flushed_events).not_to be_empty
            expect(flushed_events.length).to eq(1)
    	end
    end
end