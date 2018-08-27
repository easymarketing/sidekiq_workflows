Gem::Specification.new 'sidekiq_workflows', '0.1' do |s|
  s.licenses = %w[MIT]
  s.summary = "Sidekiq extension providing a workflow API on top of Sidekiq Pro's batches"
  s.description = "Sidekiq extension providing a workflow API on top of Sidekiq Pro's batches"
  s.authors = ['Christian Semmler']
  s.email = 'mail@csemmler.com'
  s.homepage = 'https://github.com/easymarketing/sidekiq_workflows'
  s.files = %w[
    Rakefile
  ] + Dir['lib/**/*']
  s.add_dependency 'sidekiq-pro', '~> 4.0', '>= 4.0.2'
  s.add_dependency 'activesupport', '~> 5.0'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'mocha', '~> 1.3'
  s.add_development_dependency 'minitest', '~> 5.0'
  s.add_development_dependency 'fakeredis', '~> 0'
end
