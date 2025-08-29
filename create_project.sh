#!/bin/bash

# 建立新的 iOS 專案目錄結構
PROJECT_NAME="HKBusApp"
PROJECT_DIR="/Users/davidwong/Documents/App Development/busApp"

cd "$PROJECT_DIR"

# 使用 Xcode 範本建立專案
/usr/bin/xcodebuild -createProject -projectName "$PROJECT_NAME" -template "iOS Application" -language "Swift" -useCore Data

echo "Project created at: $PROJECT_DIR/$PROJECT_NAME.xcodeproj"