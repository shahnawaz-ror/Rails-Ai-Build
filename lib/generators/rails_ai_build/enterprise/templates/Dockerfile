FROM ruby:3.3-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential git ripgrep && rm -rf /var/lib/apt/lists/*

WORKDIR /app
COPY server/Gemfile server/Gemfile.lock* ./
RUN bundle install

COPY . .
WORKDIR /app/server

EXPOSE 9292
CMD ["bundle", "exec", "rackup", "-o", "0.0.0.0", "-p", "9292"]
