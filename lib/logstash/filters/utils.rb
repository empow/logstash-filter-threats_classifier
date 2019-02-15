module LogStash; module Filters; module Empow

  class Utils
    TRUTHY_VALUES = [true, 1, '1']
    FALSEY_VALUES = [false, 0, '0']

  	def self.is_blank_string(txt)
  	  return (txt.nil? or txt.strip.length == 0)
  	end

    def self.convert_to_boolean(val)
      return nil if val.nil?

      return true if TRUTHY_VALUES.include?(val)

      return false if FALSEY_VALUES.include?(val)

      return true if (val.is_a?(String) and val.downcase.strip == 'true')

      return false if (val.is_a?(String) and val.downcase.strip == 'false')

      return nil
    end

  	def self.add_error(event, msg)
  		tag_empow_messages(event, msg, 'empow_errors')
  	end

  	def self.add_warn(event, msg)
  		tag_empow_messages(event, msg, 'empow_warnings')
  	end

  	private
  	def self.tag_empow_messages(event, msg, block)
  		messages = event.get(block)

  		# using arrayinstead of set, as set raises a logstash exception:
      # No enum constant org.logstash.bivalues.BiValues.ORG_JRUBY_RUBYOBJECTVAR0
      messages ||= Array.new
      messages << msg

      event.set(block, messages.uniq)
  	end
  end

end; end; end