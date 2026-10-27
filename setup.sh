#!/usr/bin/env bash
# Montagy setup — run this ONCE inside the project folder.
# 1) Generates android/ios platform folders (flutter create)
# 2) Applies Montagy patches (permissions, minSdk, FileProvider)
# 3) Pub get
set -e

FLUTTER_CMD=${FLUTTER_CMD:-flutter}

echo "== 1/3 flutter create =="
$FLUTTER_CMD create . --org com.montagy --project-name montagy --platforms android,ios

echo "== 2/3 applying Montagy android patch =="
cp android_patch/AndroidManifest.xml android/app/src/main/AndroidManifest.xml
cp android_patch/app_build.gradle android/app/build.gradle
mkdir -p android/app/src/main/res/xml
cp android_patch/file_paths.xml android/app/src/main/res/xml/file_paths.xml
cp -r android_patch/res/. android/app/src/main/res/
mkdir -p android/app/src/main/kotlin/com/montagy/app
cat > android/app/src/main/kotlin/com/montagy/app/MainActivity.kt <<'EOF'
package com.montagy.app

import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity()
EOF

echo "== 3/3 pub get =="
$FLUTTER_CMD pub get

echo ""
echo "✅ Setup complete!"
echo "   Run the app:  flutter run"
echo "   Build APK:    flutter build apk --release"
