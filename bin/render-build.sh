#!/usr/bin/env bash
set -o errexit

echo "Setting up directories..."
mkdir -p tmp/pids
mkdir -p tmp/cache
mkdir -p log

echo "Installing Ruby dependencies..."
bundle install

echo "Installing Node dependencies..."
npm install

echo "Building Tailwind CSS..."
npm run build:css

echo "Build completed successfully!"
