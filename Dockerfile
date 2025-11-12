# syntax=docker/dockerfile:1

FROM ruby:3.4-slim

# Install minimal required packages
RUN apt-get update -qq && \
    apt-get install -y build-essential git && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Copy Gemfile and run bundle install
COPY Gemfile Gemfile.lock valkey.gemspec ./
COPY lib/valkey/version.rb ./lib/valkey/

RUN bundle install

# Copy application code (including committed libglide_ffi.so)
COPY . .

CMD ["sleep", "infinity"]
