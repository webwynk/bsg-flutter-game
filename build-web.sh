#!/bin/bash
set -e

# Flutter SDK installation directory on Vercel build environment
FLUTTER_DIR="./.flutter-sdk"

if [ ! -d "$FLUTTER_DIR" ]; then
  echo "==> Cloning Flutter SDK (stable branch)..."
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
else
  echo "==> Flutter SDK cached."
fi

# Add Flutter to PATH
export PATH="$PATH:$(pwd)/$FLUTTER_DIR/bin"

echo "==> Checking Flutter version..."
flutter --version

echo "==> Enabling Flutter Web..."
flutter config --enable-web

echo "==> Installing Pub dependencies..."
flutter pub get

echo "==> Building Flutter Web Release..."
flutter build web --release

echo "==> Flutter Web build finished successfully!"
