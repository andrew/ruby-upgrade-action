#!/bin/bash
set -e

LATEST_VERSION=$(curl -s https://www.ruby-lang.org/en/downloads/ | grep -oP 'Ruby \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
echo "Latest Ruby version detected: $LATEST_VERSION"
echo "LATEST_VERSION=$LATEST_VERSION" >> $GITHUB_ENV
