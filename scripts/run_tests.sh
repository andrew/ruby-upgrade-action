#!/bin/bash
set -e

# Install dependencies
if [ -f Dockerfile ]; then
  docker build -t ruby-app:latest .
  docker run ruby-app:latest bundle install
  docker run ruby-app:latest bundle exec rake test
else
  bundle install
  bundle exec rake test
fi

echo "Tests completed successfully"
