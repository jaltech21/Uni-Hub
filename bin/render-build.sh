#!/usr/bin/env bash
set -o errexit

echo "Installing Ruby dependencies..."
bundle install --deployment

echo "Installing Node dependencies..."
npm install

echo "Building Tailwind CSS..."
npm run build:css

echo "Running database migrations..."
bundle exec rails db:migrate

echo "Build completed successfully!"
