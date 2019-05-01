# encoding: utf-8
require_relative '../spec_helper'
require "logstash/filters/threats-classifier"
require "logstash/event"

describe LogStash::Filters::ThreatSClassifier do

  before(:each) do
    allow(LogStash::Filters::Empow::LocalClassifier).to receive(:new).and_return(nil)
    allow(LogStash::Filters::Empow::ClassificationCenterClient).to receive(:new).and_return(nil)
    allow(LogStash::Filters::Empow::Classifier).to receive(:new).and_return(nil)
  end

  describe "config w/o local db and with mocks for online classifier" do    

    it "test empty flush" do

      plugin_core = instance_double(LogStash::Filters::Empow::PluginLogic)
      allow(LogStash::Filters::Empow::PluginLogic).to receive(:new).and_return(plugin_core)
      allow(plugin_core).to receive(:classify).and_return(nil)
      allow(plugin_core).to receive(:flush).and_return([])

      empty_config = {}
      subject = described_class.new(empty_config)
      subject.register

      event = LogStash::Event.new({"data" => "empty"})

      res = subject.flush({})

      expect(res).to eq([])
    end


    it "2 events filtered w/o an answer on receive, correct event is flushed out" do

      event = LogStash::Event.new({"data" => 1})

      plugin_core = instance_double(LogStash::Filters::Empow::PluginLogic)
      allow(LogStash::Filters::Empow::PluginLogic).to receive(:new).and_return(plugin_core)
      allow(plugin_core).to receive(:classify).and_return(nil)
      allow(plugin_core).to receive(:flush).and_return([event])

      empty_config = {}
      subject = described_class.new(empty_config)
      subject.register

      expect(plugin_core).to receive(:classify)

      res = subject.filter(event)

      expect(res).to be_nil

      res = subject.flush({})

      expect(res.length).to eq(1)
      expect(res[0].get("data")).to eq(event.get("data"))
    end

    it "test answer on filter" do

      event = LogStash::Event.new({"data" => "empty"})

      plugin_core = instance_double(LogStash::Filters::Empow::PluginLogic)
      allow(plugin_core).to receive(:classify).and_return(event)
      allow(LogStash::Filters::Empow::PluginLogic).to receive(:new).and_return(plugin_core)

      empty_config = {}
      subject = described_class.new(empty_config)
      subject.register

      expect(plugin_core).to receive(:classify)
      expect(subject).to receive(:filter_matched)

      subject.filter(event)
    end

    it "test tag on error" do

      event = instance_double(LogStash::Event)
      allow(event).to receive(:cancel).and_raise("exception")
      allow(event).to receive(:tag)

      # event = .new({"data" => "empty"})

      plugin_core = instance_double(LogStash::Filters::Empow::PluginLogic)
      allow(plugin_core).to receive(:classify).and_return(nil)
      allow(LogStash::Filters::Empow::PluginLogic).to receive(:new).and_return(plugin_core)

      empty_config = {}
      subject = described_class.new(empty_config)
      subject.register

      expect(plugin_core).to receive(:classify)
      expect(event).to receive(:cancel)
      expect(event).to receive(:tag).with('_empow_classifer_error')

      res = subject.filter(event)

      expect(res).to be_nil
    end
  end
end
