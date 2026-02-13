#!/usr/bin/env bash
set -o errexit

echo "Setting up directories..."
mkdir -p tmp/pids
mkdir -p tmp/cache
mkdir -p log

# Clear ALL bundler artifacts to remove cached binstubs
echo "Cleaning all bundler cache and artifacts..."
rm -rf .bundle vendor/bundle .gems
export BUNDLE_PATH=""
export BUNDLE_BIN=""

echo "Installing Ruby dependencies..."
bundle install --path vendor/bundle

# CRITICAL: Destroy ALL binstubs before npm runs
echo "Removing bundler binstubs..."
rm -rf vendor/bundle/bin
find . -path "*/.gems/bin" -type d -exec rm -rf {} + 2>/dev/null || true

echo "Installing Node dependencies..."
npm install

echo "Building Tailwind CSS..."
npm run build:css

echo "Running database migrations..."
bundle exec rails db:migrate

echo "Build completed successfully!"
