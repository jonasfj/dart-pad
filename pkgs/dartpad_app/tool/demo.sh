#!/bin/bash
set -e

# Change to the dartpad_app directory
cd "$(dirname "$0")/.."

echo "Building editor JS bundle..."
/usr/local/google/home/jonasfj/.nvm/versions/node/v25.8.1/bin/npm install
/usr/local/google/home/jonasfj/.nvm/versions/node/v25.8.1/bin/npm run build:js

echo "Copying web worker assets from package:dartpad..."
/workspace/flutter/bin/dart run tool/copy_worker.dart

echo "Building Flutter Web release..."
/workspace/flutter/bin/flutter build web --release

echo "Starting optimized production server at http://localhost:8080 ..."
cat << 'EOF' > build/serve_with_headers.py
import http.server
import socketserver
import os

os.chdir("web")

class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        super().end_headers()

# Prevent Address already in use error
socketserver.TCPServer.allow_reuse_address = True

with socketserver.TCPServer(("", 8080), Handler) as httpd:
    print("Serving at http://localhost:8080")
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        pass
EOF

python3 build/serve_with_headers.py
