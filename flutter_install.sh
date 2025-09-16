#!/bin/bash
# Self-contained script to install the Flutter SDK for the current session.

echo "🚀 Starting Flutter SDK setup..."

# 1. Define configuration
# We'll use a temporary directory for the installation.
FLUTTER_VERSION="3.22.2" # Using a recent, stable version.
INSTALL_DIR="/tmp/flutter_sdk"
FLUTTER_ARCHIVE="flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
FLUTTER_URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/${FLUTTER_ARCHIVE}"

# 2. Clean up previous attempts and create directory
echo "🔧 Preparing installation directory at ${INSTALL_DIR}..."
rm -rf "${INSTALL_DIR}"
mkdir -p "${INSTALL_DIR}"
cd "${INSTALL_DIR}"

# 3. Download the Flutter SDK
echo "🌐 Downloading Flutter SDK version ${FLUTTER_VERSION}..."
# Use curl to download the file, -L follows redirects, -O saves with original filename.
curl -L -O "${FLUTTER_URL}"

if [ ! -f "$FLUTTER_ARCHIVE" ]; then
    echo "❌ ERROR: Failed to download Flutter SDK. Aborting."
    exit 1
fi

# 4. Extract the SDK
echo "📦 Extracting the Flutter SDK archive..."
tar xf "${FLUTTER_ARCHIVE}"

# 5. Update the PATH environment variable for this session
echo "🛠️ Adding Flutter to the PATH for this session..."
# This is the most critical step. It tells the terminal where to find the 'flutter' command.
export PATH="$INSTALL_DIR/flutter/bin:$PATH"
echo "PATH has been updated."

# 6. Verify the installation
echo "🩺 Verifying the installation and running flutter doctor..."
flutter --version

echo "---"

# Run flutter doctor to check for dependencies.
# The output will show the status of the Flutter toolchain.
flutter doctor

echo "✅ Flutter SDK setup is complete. The 'flutter' command is now available in this session."