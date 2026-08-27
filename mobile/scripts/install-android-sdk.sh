#!/usr/bin/env bash
set -euo pipefail

# install-android-sdk.sh
# Usage: sudo bash install-android-sdk.sh
# This script installs OpenJDK, the Android command-line tools, platform-tools,
# the Android 34 platform, build-tools 34.0.0 and the specified NDK into
# $HOME/Android/Sdk. It attempts to download the command-line tools automatically
# but will instruct the user to download them manually if the automatic download fails.

USER_HOME="/home/$(logname)"
ANDROID_SDK_ROOT="$USER_HOME/Android/Sdk"

echo "Installing OpenJDK and required utilities (apt)..."
apt-get update -y
apt-get install -y openjdk-11-jdk wget unzip

mkdir -p "$ANDROID_SDK_ROOT"
cd /tmp

CMDLINE_URL="https://dl.google.com/android/repository/commandlinetools-linux-latest.zip"
OUT_ZIP="/tmp/commandlinetools.zip"

if [ -f "$OUT_ZIP" ]; then
  echo "Found existing Android command-line tools zip at $OUT_ZIP. Using it instead of downloading again."
else
  echo "Attempting to download Android command-line tools from: $CMDLINE_URL"
  if ! wget -O "$OUT_ZIP" "$CMDLINE_URL"; then
    echo "Failed to download command-line tools automatically."
    echo "Please download the latest Command line tools (Linux) from:"
    echo "  https://developer.android.com/studio#command-tools"
    echo "Then place the downloaded zip at /tmp/commandlinetools.zip and re-run this script."
    exit 1
  fi
fi

rm -rf "$ANDROID_SDK_ROOT/cmdline-tools"
mkdir -p "$ANDROID_SDK_ROOT/cmdline-tools/latest"
unzip -q "$OUT_ZIP" -d "$ANDROID_SDK_ROOT/cmdline-tools/latest"

# If the zip created an inner cmdline-tools folder, move its contents up
if [ -d "$ANDROID_SDK_ROOT/cmdline-tools/latest/cmdline-tools" ]; then
  mv "$ANDROID_SDK_ROOT/cmdline-tools/latest/cmdline-tools"/* "$ANDROID_SDK_ROOT/cmdline-tools/latest/"
fi

# Make sdkmanager executable
chmod +x "$ANDROID_SDK_ROOT/cmdline-tools/latest/bin/sdkmanager"

export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:$PATH"

# Install required packages
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" "platform-tools" "platforms;android-34" "build-tools;34.0.0" "ndk;25.1.8937393"

# Accept licenses
yes | sdkmanager --sdk_root="$ANDROID_SDK_ROOT" --licenses || true

# Print next steps
cat <<EOF
Android SDK and required packages should be installed in: $ANDROID_SDK_ROOT

Add the following lines to your shell profile (~/.bashrc or ~/.profile):

export ANDROID_SDK_ROOT="$ANDROID_SDK_ROOT"
export ANDROID_HOME="$ANDROID_SDK_ROOT"
export PATH="$ANDROID_SDK_ROOT/cmdline-tools/latest/bin:$ANDROID_SDK_ROOT/platform-tools:\$PATH"

Then either re-open your shell or run:

source ~/.bashrc

To verify, run:

adb --version
sdkmanager --list --sdk_root="$ANDROID_SDK_ROOT"

After that, return to the project and run the Android build:

cd /home/$(logname)/workspace/Uni-Hub/mobile/android
./gradlew assembleDebug --no-daemon --stacktrace

EOF

exit 0
