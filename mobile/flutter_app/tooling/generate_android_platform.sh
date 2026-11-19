#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

if [[ ! -f pubspec.yaml ]]; then
  echo "pubspec.yaml not found; run this script from the mobile Flutter project."
  exit 1
fi

flutter create --platforms=android --org com.m5ham3ds --project-name cutawan_mobile .
flutter pub get
