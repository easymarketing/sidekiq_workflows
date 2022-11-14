FROM ruby:2.7-alpine

RUN apk add curl
RUN apk add build-base

ARG CONTRIBSYS_CREDENTIALS
ENV BUNDLE_GEMS__CONTRIBSYS__COM=${CONTRIBSYS_CREDENTIALS}

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock sidekiq_workflows.gemspec ./
RUN bundle install

COPY . .

CMD bundle exec rake test
