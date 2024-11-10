#!/bin/bash
set -e

LATEST_VERSION=$LATEST_VERSION

# Update .ruby-version
echo "$LATEST_VERSION" > .ruby-version
echo "Updated .ruby-version to $LATEST_VERSION"

# Update Gemfile
if grep -q '^ruby ' Gemfile; then
  sed -i "s/^ruby .*/ruby '$LATEST_VERSION'/" Gemfile
  echo "Updated Gemfile Ruby version to $LATEST_VERSION"
fi

# Update Dockerfile
if grep -q '^FROM ruby:' Dockerfile; then
  sed -i "s/^FROM ruby:.*/FROM ruby:$LATEST_VERSION-alpine/" Dockerfile
  echo "Updated Dockerfile Ruby version to $LATEST_VERSION"
fi

# Update GitHub Actions workflows
for workflow in .github/workflows/*.yml; do
  if grep -q 'ruby-version:' "$workflow"; then
    sed -i "s/ruby-version: .*/ruby-version: '$LATEST_VERSION'/" "$workflow"
    echo "Updated $workflow Ruby version to $LATEST_VERSION"
  fi
done
