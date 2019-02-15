require 'elasticsearch'
require 'hashie'

module LogStash; module Filters; module Empow;
	class PersistentKeyValueDB
		#include LogStash::Util::Loggable

		def initialize(hosts, username, password, index)
			#@logger ||= self.logger

			#@logger.debug("opening the local classification db")

			@elastic ||= Elasticsearch::Client.new(:hosts => hosts)
			@index = index

			create_index index
		end

		def create_index(index)
			return if @elastic.indices.exists? index: index

			@elastic.indices.create index: index, body: {
				mappings: {
					_doc: {
						properties: {
							product_type: {
								type: 'keyword'
							},
							product: {
								type: 'keyword'
							},
							term_key: {
								type: 'keyword'
							},
							classification: {
								enabled: false
							}
						}
					}
				}
			}
		end

		def query(product_type, product, term)
			#@logger.debug("quering local classification db")

			# fix nil product
			if product.nil?
				product = 'nil_safe_product_key'
			end

			response = @elastic.search index: @index, type: '_doc', body: {
				query: {
					bool: {
						must: [
							{ term: { product_type: product_type } },
							{
								bool: {
									should: [
										{
											bool: {
												must: [
													{ term: { term_key: term } },
													{ term: { product: product } }
												]
											}
										},
										{
											bool: {
												must: {
													term: { term_key: term }
												},
												must_not: {
													exists: { field: 'product' }
												}
											}
										}
									]
								}
							}
						]
					}
				}
			}

			mash = Hashie::Mash.new response

			return nil if mash.hits.hits.first.nil?

			return mash.hits.hits.first._source.classification
		end

		def save(doc_id, product_type, product, term, classification)
			#@logger.debug("saving key to local classification db")

			@elastic.index index: @index, type: '_doc', id: doc_id, body: {
				product_type: product_type,
				product: product,
				term_key: term,
				classification: classification
			}
		end

		def close
			#@logger.debug("clsoing the local classification db")
		end
	end

end; end; end

=begin
db = LogStash::Filters::Empow::PersistentKeyValueDB.new('192.168.3.24:9200', 'user', 'pass', 'key-val-8')

db.save("am", "p3", "dummy signature", "v1")
db.save("am", "p3", "dummy signature 2", "v1")

db.save("am", "p1", "dummy", "v1")
db.save("am", nil, "dummy", "v1")
p db.query "am", "p1", "h1"
db.save("am", "p1", "h1", "v1")
p db.query "am", "p1", "h1"
p db.query "am", "p1", "h2"
p db.query "am", "no-such-product", "h1"
p db.query "am", nil, "h1"
p db.query "am", nil, "dummy"

p db.query "am", "p3", "dummy signature 2"
=end