#!/usr/bin/env bash
set -o errexit

echo "Setting up directories..."
mkdir -p tmp/pids
mkdir -p tmp/cache
mkdir -p log

echo "Installing Ruby dependencies..."
bundle config set without 'development test'
bundle install

echo "Installing Node dependencies..."
npm install
# Remove bundler's tailwindcss wrapper to let npm use its own
rm -f .gems/bin/tailwindcss

echo "Building Tailwind CSS..."
npm run build:css

echo "Running database migrations..."
bundle exec rails db:migrate

echo "Build completed successfully!"
