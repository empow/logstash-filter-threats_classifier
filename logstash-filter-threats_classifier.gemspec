Gem::Specification.new do |s|
  s.name          = 'logstash-filter-threats_classifier'
  s.version       = '1.0.2'
  s.licenses      = ['Apache-2.0']
  s.summary       = 'Returns classification information for attacks from the empow classification center, based on information in log strings'
  #s.description   = 'Write a longer description or delete this line.'
  s.homepage      = 'http://www.empow.co'
  s.authors       = ['empow', 'Assaf Abulafia', 'Rami Cohen']
  s.email         = ''
  s.require_paths = ['lib']

  # Files
  s.files = Dir['lib/**/*','spec/**/*','vendor/**/*','*.gemspec','*.md','CONTRIBUTORS','Gemfile','LICENSE','NOTICE.TXT']
   # Tests

  s.test_files = s.files.grep(%r{^(test|spec|features)/})

  # Special flag to let us know this is actually a logstash plugin
  s.metadata = { "logstash_plugin" => "true", "logstash_group" => "filter" }

  # Gem dependencies
  s.add_runtime_dependency "logstash-core-plugin-api", ">= 1.60", "<= 2.99"
  s.add_runtime_dependency 'rest-client', '~> 1.8', '>= 1.8.0'
  s.add_runtime_dependency 'lru_redux', '~> 1.1', '>= 1.1.0'
  s.add_runtime_dependency 'json', '~> 1.8', '>= 1.8'
  #s.add_runtime_dependency 'rufus-scheduler'
  s.add_runtime_dependency 'hashie'
  #s.add_runtime_dependency "murmurhash3"
  
  s.add_development_dependency 'aws-sdk', '~> 3'

  s.add_development_dependency 'logstash-devutils'
#  s.add_runtime_dependency 'jwt', '~> 2.1', '>= 2.1.0'
  s.add_development_dependency "timecop", "~> 0.7"
  s.add_development_dependency "webmock", "~> 1.22", ">= 1.21.0"

  s.add_development_dependency 'elasticsearch'
end
