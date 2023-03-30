require 'sidekiq-pro'
require_relative './worker'
require_relative '../../lib/sidekiq_workflows'

Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379') }
end

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://redis:6379') }
end
