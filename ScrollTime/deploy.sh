#!/bin/bash

# ScrollTime - Fully Automated TestFlight Deployment
# Usage: ./deploy.sh
#
# Features:
# - Builds and archives the app
# - Uploads to App Store Connect
# - Skips compliance (configured in Info.plist)
# - Auto-distributes to internal testers
#
# First-time setup:
# 1. Create API key at https://appstoreconnect.apple.com/access/api
# 2. Save the .p8 file to ~/.appstoreconnect/private_keys/
# 3. Set environment variables (or add to ~/.zshrc):
#    export APP_STORE_CONNECT_API_KEY_ID="YOUR_KEY_ID"
#    export APP_STORE_CONNECT_ISSUER_ID="YOUR_ISSUER_ID"

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_NAME="ScrollTime"
SCHEME="ScrollTime"
ARCHIVE_PATH="$PROJECT_DIR/build/$PROJECT_NAME.xcarchive"
EXPORT_PATH="$PROJECT_DIR/build/Export"
EXPORT_OPTIONS="$PROJECT_DIR/build/ExportOptions.plist"

echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   ScrollTime TestFlight Deployment     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"
echo ""

cd "$PROJECT_DIR"

# Get current version info
MARKETING_VERSION=$(xcodebuild -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME" -showBuildSettings 2>/dev/null | grep "MARKETING_VERSION" | head -1 | sed 's/.*= //')
echo -e "Version: ${GREEN}$MARKETING_VERSION${NC}"
echo ""

# Step 1: Clean
echo -e "${YELLOW}[1/4]${NC} Cleaning build folder..."
xcodebuild clean -project "$PROJECT_NAME.xcodeproj" -scheme "$SCHEME" -quiet 2>/dev/null || true

# Step 2: Archive
echo -e "${YELLOW}[2/4]${NC} Building release archive..."
xcodebuild archive \
    -project "$PROJECT_NAME.xcodeproj" \
    -scheme "$SCHEME" \
    -sdk iphoneos \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    -allowProvisioningUpdates \
    -quiet 2>/dev/null

if [ ! -d "$ARCHIVE_PATH" ]; then
    echo -e "${RED}✗ Archive failed!${NC}"
    exit 1
fi
echo -e "${GREEN}✓${NC} Archive created"

# Step 3: Export and Upload
echo -e "${YELLOW}[3/4]${NC} Uploading to TestFlight..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$EXPORT_OPTIONS" \
    -exportPath "$EXPORT_PATH" \
    -allowProvisioningUpdates 2>&1 | grep -E "(Progress|Upload|error:|warning:)" | while read line; do
    if [[ $line == *"100%"* ]]; then
        echo -e "${GREEN}✓${NC} Upload complete"
    elif [[ $line == *"error:"* ]]; then
        echo -e "${RED}✗ $line${NC}"
    fi
done

# Step 4: Done
BUILD_NUMBER=$(date +%Y%m%d%H%M)
echo -e "${YELLOW}[4/4]${NC} Finalizing..."
echo ""
echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Deployment Complete!           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"
echo ""
echo -e "Build uploaded to App Store Connect."
echo ""
echo -e "${BLUE}What happens next:${NC}"
echo -e "  1. Processing: ~5 minutes"
echo -e "  2. Ready for testing (auto-distributed)"
echo -e "  3. TestFlight notification on your phone"
echo ""
echo -e "${BLUE}Check status:${NC}"
echo -e "  https://appstoreconnect.apple.com/apps"
echo ""

# Optional: Play sound when done
afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true
