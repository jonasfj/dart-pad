#!/bin/bash
set -e

PKG_SOURCE_DIR="/workspace/dart-sdk2/sdk/pkg/dartpad"
PKG_DEST_DIR="third_party/dart-sdk/pkg/dartpad"

WORKER_SOURCE_DIR="/workspace/dart-sdk2/sdk/out/ReleaseX64/dartpad/"
WORKER_DEST_DIR="web/asset/worker/"

echo "Copying DartPad package from $PKG_SOURCE_DIR to $PKG_DEST_DIR..."
# Ensure the destination directory exists and clear old contents
mkdir -p "$PKG_DEST_DIR"
rm -rf "${PKG_DEST_DIR:?}/"*
# Copy all files and folders
cp -a "$PKG_SOURCE_DIR/." "$PKG_DEST_DIR/"
# Remove build artifacts that shouldn't be committed
rm -rf "$PKG_DEST_DIR/.dart_tool" "$PKG_DEST_DIR/build" "$PKG_DEST_DIR/.packages"

echo "Copying DartPad worker from $WORKER_SOURCE_DIR to $WORKER_DEST_DIR..."
# Ensure the destination directory exists and clear old contents
mkdir -p "$WORKER_DEST_DIR"
rm -rf "${WORKER_DEST_DIR:?}/"*
# Copy all files and folders
cp -a "$WORKER_SOURCE_DIR/." "$WORKER_DEST_DIR/"

echo "DartPad assets and package copied successfully!"
