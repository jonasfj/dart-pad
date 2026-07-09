#!/bin/bash
set -e

# Change to the dartpad_app directory
cd "$(dirname "$0")/.."

echo "Building editor JS bundle..."
/usr/local/google/home/jonasfj/.nvm/versions/node/v25.8.1/bin/npm install
/usr/local/google/home/jonasfj/.nvm/versions/node/v25.8.1/bin/npm run build:js

echo "Copying web worker assets from package:dartpad..."
dart run tool/copy_worker.dart

echo "Starting Flutter development server..."
# Using headers for WASM shared memory / Web Workers if needed by dartpad
/workspace/flutter/bin/flutter run -d chrome \
  --web-header="Cross-Origin-Embedder-Policy=require-corp" \
  --web-header="Cross-Origin-Opener-Policy=same-origin"
