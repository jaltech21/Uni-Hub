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

# CRITICAL: Destroy ALL binstubs before npm runs - use multiple strategies
echo "Nuclear option: destroying ALL bundler binstubs..."
find . -path "*/bin/tailwindcss" -type f -delete 2>/dev/null || true
find . -name ".gems" -type d -exec rm -rf {} + 2>/dev/null || true
rm -f ~/.bundle/config 2>/dev/null || true
rm -f ./bin/bundle ./bin/bundle.bak 2>/dev/null || true

echo "Installing Node dependencies..."
npm install --no-optional

# Run npm with completely isolated environment - remove project bin directory from PATH
echo "Building Tailwind CSS with isolated environment..."
PATH=/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin BUNDLE_IGNORE_CONFIG=1 npm run build:css

echo "Running database migrations..."
bundle exec rails db:migrate

echo "Build completed successfully!"
