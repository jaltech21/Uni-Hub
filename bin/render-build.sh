#!/usr/bin/env bash
set -o errexit

echo "Installing dependencies..."
bundle install --deployment

echo "Precompiling assets..."
bundle exec rails assets:precompile

echo "Running database migrations..."
bundle exec rails db:migrate

echo "Build completed successfully!"
