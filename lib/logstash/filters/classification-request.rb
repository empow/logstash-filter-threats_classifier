module LogStash; module Filters; module Empow;
  class LogStash::Filters::Empow::ClassificationRequest < Struct.new(:product_type, :product, :term, :is_src_internal, :is_dst_internal)
    def initialize(product_type, product, term, is_src_internal, is_dst_internal)
      if product_type.nil?
      	raise ArgumentError, 'product type cannot be empty' 
      end

      product_type = product_type.upcase.strip

      unless product.nil?
        product = product.downcase.strip
      end

      super(product_type, product, term, is_src_internal, is_dst_internal)
    end
  end
end; end; end;