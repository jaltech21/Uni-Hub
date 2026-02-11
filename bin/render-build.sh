#!/usr/bin/env bash
set -o errexit

echo "Setting up directories..."
mkdir -p tmp/pids
mkdir -p tmp/cache
mkdir -p log

echo "Installing Ruby dependencies..."
bundle install --without development test

echo "Installing Node dependencies..."
npm ci

echo "Building Tailwind CSS..."
npx tailwindcss -i ./app/assets/tailwind/application.css -o ./app/assets/builds/application.css --minify

echo "Running database migrations..."
bundle exec rails db:migrate

echo "Build completed successfully!"
