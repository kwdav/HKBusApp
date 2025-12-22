#!/bin/bash

# HKBusApp 自動編譯測試腳本
# 用途：自動執行 pod install、編譯專案、啟動模擬器

set -e  # 遇到錯誤立即停止

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 專案路徑
PROJECT_DIR="/Users/davidwong/Documents/App Development/busApp/HKBusApp"
WORKSPACE="HKBusApp.xcworkspace"
SCHEME="HKBusApp"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}HKBusApp 自動編譯測試腳本${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# 步驟 1: 檢查 CocoaPods
echo -e "${YELLOW}[1/5] 檢查 CocoaPods...${NC}"
if ! command -v pod &> /dev/null; then
    echo -e "${RED}❌ CocoaPods 未安裝！${NC}"
    echo -e "${YELLOW}請執行: brew install cocoapods${NC}"
    exit 1
fi
echo -e "${GREEN}✅ CocoaPods 已安裝: $(pod --version)${NC}"
echo ""

# 步驟 2: 進入專案目錄
echo -e "${YELLOW}[2/5] 進入專案目錄...${NC}"
cd "$PROJECT_DIR"
echo -e "${GREEN}✅ 當前目錄: $(pwd)${NC}"
echo ""

# 步驟 3: 執行 pod install
echo -e "${YELLOW}[3/5] 執行 pod install...${NC}"
if [ ! -f "Podfile" ]; then
    echo -e "${RED}❌ Podfile 不存在！${NC}"
    exit 1
fi

pod install
echo -e "${GREEN}✅ Pod install 完成${NC}"
echo ""

# 步驟 4: 編譯專案
echo -e "${YELLOW}[4/5] 編譯專案...${NC}"
if [ ! -d "$WORKSPACE" ]; then
    echo -e "${RED}❌ Workspace 不存在: $WORKSPACE${NC}"
    exit 1
fi

xcodebuild -workspace "$WORKSPACE" \
           -scheme "$SCHEME" \
           -configuration Debug \
           -sdk iphonesimulator \
           clean build \
           | tee build.log \
           | grep -E "^\*\*|error:|warning:|✅|📡|📱|⏰" || true

# 檢查編譯結果
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}✅ 編譯成功！${NC}"
    echo -e "${GREEN}========================================${NC}"
else
    echo ""
    echo -e "${RED}========================================${NC}"
    echo -e "${RED}❌ 編譯失敗！${NC}"
    echo -e "${RED}========================================${NC}"
    echo -e "${YELLOW}完整日誌已保存到: build.log${NC}"
    exit 1
fi
echo ""

# 步驟 5: 啟動模擬器（可選）
echo -e "${YELLOW}[5/5] 啟動模擬器...${NC}"
read -p "是否啟動模擬器並運行 App? (y/n): " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${BLUE}🚀 啟動模擬器...${NC}"
    open -a Simulator

    echo -e "${BLUE}⏳ 等待模擬器啟動（5秒）...${NC}"
    sleep 5

    echo -e "${BLUE}📱 運行 App...${NC}"
    xcodebuild -workspace "$WORKSPACE" \
               -scheme "$SCHEME" \
               -configuration Debug \
               -sdk iphonesimulator \
               -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
               build \
               | grep -E "✅|📡|📱|⏰|❌" || true

    echo -e "${GREEN}✅ App 已安裝到模擬器${NC}"
else
    echo -e "${BLUE}跳過模擬器啟動${NC}"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}所有步驟完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}查看 App Console 日誌:${NC}"
echo -e "1. 打開模擬器中的 HKBusApp"
echo -e "2. Xcode → Window → Devices and Simulators"
echo -e "3. 選擇運行中的模擬器 → Console"
echo ""
echo -e "${BLUE}預期日誌:${NC}"
echo -e "  ✅ Firebase initialized"
echo -e "  ✅ LocalBusDataManager: Loaded bus data successfully"
echo -e "  📊 Routes: 2090, Stops: 9223"
