#!/usr/bin/env bash
set -o errexit

echo "Installing Ruby dependencies..."
bundle install

echo "Installing Node dependencies..."
npm install

echo "Building Tailwind CSS..."
npm run build:css

echo "Build completed successfully!"
