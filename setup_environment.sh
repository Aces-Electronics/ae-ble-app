#!/bin/bash

# Exit on error
set -e

echo "🚀 Starting Environment Setup..."

# --- Flutter SDK Setup ---
echo "🔧 Setting up Flutter SDK..."
if [ ! -d "/tmp/flutter_sdk/flutter" ]; then
  mkdir -p /tmp/flutter_sdk
  wget https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.22.2-stable.tar.xz -O /tmp/flutter_sdk/flutter.tar.xz
  tar -xf /tmp/flutter_sdk/flutter.tar.xz -C /tmp/flutter_sdk
  rm /tmp/flutter_sdk/flutter.tar.xz
else
  echo "Flutter SDK already downloaded."
fi

export PATH="$PATH:/tmp/flutter_sdk/flutter/bin"
echo "Upgrading Flutter to the required version..."
flutter upgrade

# --- Android SDK Setup ---
echo "🔧 Setting up Android SDK..."
if [ ! -d "/tmp/android_sdk" ]; then
  mkdir -p /tmp/android_sdk
  wget https://dl.google.com/android/repository/commandlinetools-linux-9477386_latest.zip -O /tmp/android_sdk/cmdline-tools.zip
  unzip /tmp/android_sdk/cmdline-tools.zip -d /tmp/android_sdk
  rm /tmp/android_sdk/cmdline-tools.zip

  mkdir -p /tmp/android_sdk/cmdline-tools/latest
  mv /tmp/android_sdk/cmdline-tools/* /tmp/android_sdk/cmdline-tools/latest
else
    echo "Android command-line tools already downloaded."
fi

export ANDROID_HOME=/tmp/android_sdk
export ANDROID_SDK_ROOT=/tmp/android_sdk
export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"

echo "Installing Android SDK components..."
yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT "platform-tools" "platforms;android-33" "build-tools;34.0.0" "cmake;3.22.1"
yes | sdkmanager --sdk_root=$ANDROID_SDK_ROOT --licenses

echo "✅ Environment setup is complete."
echo "You can now build the project."
echo "Remember to source this script or export the environment variables in your current session:"
echo 'export ANDROID_HOME=/tmp/android_sdk'
echo 'export ANDROID_SDK_ROOT=/tmp/android_sdk'
echo 'export PATH="$PATH:/tmp/flutter_sdk/flutter/bin:/tmp/android_sdk/cmdline-tools/latest/bin:/tmp/android_sdk/platform-tools"'
