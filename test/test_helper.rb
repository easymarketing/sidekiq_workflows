require 'minitest/autorun'
require 'mocha/minitest'

require 'sidekiq/testing'
require 'fakeredis'

require 'pry'

Sidekiq.configure_client do |config|
  config.redis = {driver: Redis::Connection::Memory}
end

Sidekiq.configure_server do |config|
  config.redis = {driver: Redis::Connection::Memory}
end

require 'sidekiq_workflows'
