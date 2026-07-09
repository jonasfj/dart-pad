#!/bin/bash
# Exit on error
set -e

# Ensure we're in the project root
cd "$(dirname "$0")/.."

echo "Installing NPM dependencies..."
npm install

echo "Bundling JavaScript..."
npm run build:js

echo "Copying DartPad worker assets..."
dart run tool/copy_worker.dart

echo "Done! Generated web/bundle.js"
