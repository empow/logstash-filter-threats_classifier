module LogStash
	module Filters
		module Empow
			class AbstractResponse
		  		attr_reader :response, :is_successful, :is_final

			  	def initialize(response, is_successful, is_final)
			  		@response = response
			  		@is_successful = is_successful
			  		@is_final = is_final
			  	end
			end

			class FailureResponse < AbstractResponse
			  	def initialize(response)
			  		super(response, false, true)
			  	end
  			end

  			class UnauthorizedReponse < FailureResponse
  			end

  			class SuccessfulResponse < AbstractResponse
  				def initialize(response)
  					super(response, true, true)
  				end
  			end

  			class InProgressResponse < AbstractResponse
  				def initialize(response)
  					super(response, true, false)
  				end
  			end
		end
	end
end