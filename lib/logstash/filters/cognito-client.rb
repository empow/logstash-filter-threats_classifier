require 'aws-sdk'
 
module LogStash
	module Filters
		module Empow
			class CognitoClient
				include LogStash::Util::Loggable

				def initialize(username, password, aws_region_name, aws_client_id)
					@logger = self.logger

					@logger.debug("aws region: #{aws_region_name}")
					@logger.debug("aws aws_client_id: #{aws_client_id}")
					@logger.debug("cognito username: #{username}")

					@username = username
					@password = password
					@aws_region_name = aws_region_name
					@aws_client_id = aws_client_id

					Aws.config.update({
						region: @aws_region_name,
						credentials: Aws::Credentials.new('aaaa', 'aaaa')
					})

					@client = Aws::CognitoIdentityProvider::Client.new
				end

				def authenticate
					resp = @client.initiate_auth({
						auth_flow: "USER_PASSWORD_AUTH",
						auth_parameters: {
							'USERNAME': @username,
							'PASSWORD': @password,
						},
						client_id: @aws_client_id,
					})

					id_token = resp.authentication_result.id_token
					token_type = resp.authentication_result.token_type

					token = token_type + " " + id_token
					return id_token
				end
			end
		end
	end
end