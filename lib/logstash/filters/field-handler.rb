require_relative "classification-request"
require_relative "utils"

class LogStash::Filters::Empow::FieldHandler

  IDS = "IDS"
  AM = "AM"
  CUSTOM = "CUSTOM"

  public
  def initialize(product_type_field, product_name_field, threat_field, src_internal_field, dst_internal_field)
    @product_type_field = product_type_field
    @product_name_field = product_name_field

    if threat_field.nil? || threat_field.strip.length == 0
      raise ArgumentError, 'threat field cannot be empty'
    end

    @threat_field = '[' + threat_field + ']'

    @ids_signature_field = @threat_field + '[signature]'
    @malware_name_field = @threat_field + '[malware_name]'

    @src_internal_field = @threat_field + '[' + src_internal_field + ']'
    @dst_internal_field = @threat_field + '[' + dst_internal_field + ']'

    @blacklisted_fields = [src_internal_field, dst_internal_field]

    @hash_field = @threat_field + '[hash]'
  end

  public
  def event_to_classification_request(event)
    product_type = event.get(@product_type_field)
    product = event.get(@product_name_field)
    is_src_internal = event.get(@src_internal_field)
    is_dst_internal = event.get(@dst_internal_field)

    if product_type.nil?
      LogStash::Filters::Empow::Utils.add_error(event, "missing_product_type")
      return nil
    end

    is_src_internal = LogStash::Filters::Empow::Utils.convert_to_boolean(is_src_internal)

    if is_src_internal.nil?
      is_src_internal = true
      LogStash::Filters::Empow::Utils.add_warn(event, 'src_internal_wrong_value')
    end

    is_dst_internal = LogStash::Filters::Empow::Utils.convert_to_boolean(is_dst_internal)

    if is_dst_internal.nil?
      is_dst_internal = true
      LogStash::Filters::Empow::Utils.add_warn(event, 'dst_internal_wrong_value')
    end

    case product_type
    when IDS
      return nil if !is_valid_ids_request(product, event)
    when AM
      return nil if !is_valid_antimalware_request(product, event)
    else # others are resolved in the cloud
      return nil if !is_valid_product(product, event)
    end

    original_threat = event.get(@threat_field)

    threat = copy_threat(original_threat)

    if (threat.nil?)
      LogStash::Filters::Empow::Utils.add_error(event, "missing_threat_field")
      return nil
    end

    return LogStash::Filters::Empow::ClassificationRequest.new(product_type, product, threat, is_src_internal, is_dst_internal)
  end

  private
  def copy_threat(threat)
    return nil if (threat.nil? or threat.size == 0)

    res = Hash.new

    threat.each do |k, v|
      next if @blacklisted_fields.include?(k)
      res[k] = v
    end

    return res
  end

  private
  def is_valid_ids_request(product, event)
    sid = event.get(@ids_signature_field)

    if sid.nil? || sid.strip.length == 0
      LogStash::Filters::Empow::Utils.add_error(event, "missing_ids_signature")
      return false
    end

    return is_valid_product(product, event)
  end

  private
  def is_valid_product(product, event)
    if (product.nil? or product.strip.length == 0)
      LogStash::Filters::Empow::Utils.add_error(event, "missing_product_name")
      return false
    end

    return true
  end

  private
  def is_valid_antimalware_request(product, event)
    malware_name = event.get(@malware_name_field)
    malware_hash = event.get(@hash_field)

    if malware_hash.nil? and (malware_name.nil? or product.nil?)
      LogStash::Filters::Empow::Utils.add_error(event, "anti_malware_missing_hash_or_name")
      return false
    end

    return true
  end
end