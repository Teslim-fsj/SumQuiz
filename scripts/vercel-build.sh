#!/bin/bash

# Exit on error
set -e

# Define Flutter version
FLUTTER_VERSION="3.24.3" # Matching the version in existing vercel.json for consistency
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

echo "Checking for Flutter SDK..."
if [ ! -d "flutter" ]; then
  echo "Downloading Flutter SDK (${FLUTTER_VERSION})..."
  curl -o flutter.tar.xz $FLUTTER_URL
  tar xf flutter.tar.xz
  rm flutter.tar.xz
fi

# Add flutter to PATH
export PATH="$PATH:`pwd`/flutter/bin"

echo "Flutter version:"
flutter --version

echo "Getting dependencies..."
flutter pub get

echo "Building web version..."
flutter build web --release --base-href /

echo "Build complete."
