FROM ruby:2.5-alpine

ARG CONTRIBSYS_CREDENTIALS
ENV BUNDLE_GEMS__CONTRIBSYS__COM=${CONTRIBSYS_CREDENTIALS}

WORKDIR /usr/src/app

COPY Gemfile Gemfile.lock sidekiq_workflows.gemspec ./
RUN bundle install

COPY . .

CMD bundle exec rake test
