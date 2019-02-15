require_relative '../spec_helper'
require "logstash/event"
require "logstash/filters/utils"

describe LogStash::Filters::Empow::Utils do

    describe "test internal tagging" do
    	it "test error" do
    		event = LogStash::Event.new("data" => "a b c")

    		LogStash::Filters::Empow::Utils.add_error(event, "my_msg")

            expect(event.get("empow_errors")).to contain_exactly("my_msg")
    	end

    	it "test warn" do
    		event = LogStash::Event.new("data" => "a b c")

    		LogStash::Filters::Empow::Utils.add_warn(event, "my_msg")

            expect(event.get("empow_warnings")).to contain_exactly("my_msg")
    	end
    end
#json = '{ "a": "True", "b": "true", "c": "1", "d": 1, "e": "False", "f": "0", "g": "TRUE" }'
    describe "test is truthy" do
        it "string TRUE" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean("TRUE")).to eq(true)
        end

        it "string true" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean("true")).to eq(true)
        end

        it "string 1" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean("1")).to eq(true)
        end

        it "string 11" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean("11")).to be_nil
        end

        it "string 0" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean('0')).to eq(false)
        end

        it "int 0" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean(0)).to eq(false)
        end

        it "int 1" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean(1)).to eq(true)
        end

        it "int 11" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean(11)).to be_nil
        end

        it "boolean true" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean(true)).to eq(true)
        end

        it "boolean false" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean(false)).to eq(false)
        end

        it "nil" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean(nil)).to be_nil
        end

        it "empty string" do
            expect(LogStash::Filters::Empow::Utils.convert_to_boolean('')).to be_nil
        end
    end
end