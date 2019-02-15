require 'aws-sdk'
require_relative '../spec_helper'
require "logstash/filters/cognito-client"

describe LogStash::Filters::Empow::CognitoClient do

  describe "cognito test" do
    skip "test authenticate" do

      aws_region = 'us-east-2'
      aws_client_id = '8dljcvt4jfif762le0ald6j'
      username = 'bad'
      password = 'request'

      client = described_class.new(username, password, aws_region, aws_client_id)

      expect{ client.authenticate }.to raise_error(Aws::CognitoIdentityProvider::Errors::UserNotFoundException)
    end
  end
end