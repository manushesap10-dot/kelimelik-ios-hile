#!/usr/bin/env bash
# Mac'te çalıştır: IPA üretimi
set -euo pipefail
cd "$(dirname "$0")"

echo "[1/5] flutter create platforms (gerekirse)"
flutter create --platforms=ios .

echo "[2/5] pub get"
flutter pub get

echo "[3/5] pods"
cd ios
pod install
cd ..

echo "[4/5] analyze"
flutter analyze || true

echo "[5/5] build ipa"
flutter build ipa --release

echo "Bitti. IPA: build/ios/ipa/"
ls -la build/ios/ipa/ || true
