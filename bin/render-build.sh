#!/usr/bin/env bash
set -o errexit

echo "Setting up directories..."
mkdir -p tmp/pids
mkdir -p tmp/cache
mkdir -p log
# Clean up old tailwindcss binstub
rm -f .gems/bin/tailwindcss

echo "Installing Ruby dependencies..."
export BUNDLE_SKIP_DEFAULT_INSTALL=true
bundle config set without 'development test'
# Don't create binstubs to avoid conflicts with npm executables
bundle install --no-binstubs

echo "Installing Node dependencies..."
npm install

echo "Building Tailwind CSS..."
# Remove .gems/bin from PATH to prevent bundler from hijacking tailwindcss command
export PATH=$(echo $PATH | tr ':' '\n' | grep -v '.gems/bin' | paste -sd: -)
# Use npm script which correctly resolves to node_modules
npm run build:css

echo "Running database migrations..."
bundle exec rails db:migrate

echo "Build completed successfully!"
