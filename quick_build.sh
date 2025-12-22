#!/bin/bash

# HKBusApp 快速編譯腳本（無互動）

cd "/Users/davidwong/Documents/App Development/busApp/HKBusApp"

echo "🔨 執行 pod install..."
pod install

echo "🔨 編譯專案..."
xcodebuild -workspace HKBusApp.xcworkspace \
           -scheme HKBusApp \
           -configuration Debug \
           -sdk iphonesimulator \
           clean build \
           2>&1 | grep -E "BUILD|error:|warning:|✅|📡" || true

if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo "✅ 編譯成功！"
else
    echo "❌ 編譯失敗"
    exit 1
fi
