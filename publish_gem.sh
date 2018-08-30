#!/bin/sh

set -e

mkdir -p ~/.gem
curl -u emarketing:$RUBYGEMS_PASSWORD https://rubygems.org/api/v1/api_key.yaml > ~/.gem/credentials
chmod 0600 ~/.gem/credentials

bundle exec rake package
gem push pkg/sidekiq_workflows-*.gem
