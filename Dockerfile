# syntax=docker/dockerfile:1

# Stage 2: Ruby development environment
FROM ruby:3.4

# Install system dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends \
    build-essential \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile, Gemfile.lock, and gemspec
COPY Gemfile* *.gemspec ./
COPY lib/valkey/version.rb ./lib/valkey/

# Install bundler and gems
RUN gem install bundler && \
    bundle install

# Copy the rest of the application (including native libraries)
COPY . .

# Keep container running for development
CMD ["sleep", "infinity"]

