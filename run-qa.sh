#!/bin/bash
# QA: analyze + test + release APK (split per ABI)
set -u
source ~/workspace/bin/flutter-env.sh
cd ~/workspace/thermal-print
echo "===== flutter analyze ====="
flutter analyze 2>&1 | tail -5
echo "===== flutter test ====="
flutter test 2>&1 | tail -5
echo "===== flutter build apk --split-per-abi (release) ====="
flutter build apk --split-per-abi --release 2>&1 | tail -8
echo "===== APKs ====="
ls -la build/app/outputs/flutter-apk/*.apk
