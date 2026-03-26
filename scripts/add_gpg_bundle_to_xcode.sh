#!/bin/bash

#
# add_gpg_bundle_to_xcode.sh
# Moaiy
#
# Adds gpg.bundle to Xcode project
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

PROJECT_ROOT="$( cd "$( dirname "${BASH_SOURCE[0]}" )/.." && pwd )"
XCODE_PROJECT="$PROJECT_ROOT/Moaiy/Moaiy.xcodeproj"
BUNDLE_PATH="$PROJECT_ROOT/Moaiy/Resources/gpg.bundle"

info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
    exit 1
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Adding GPG Bundle to Xcode Project"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if bundle exists
if [ ! -d "$BUNDLE_PATH" ]; then
    error "GPG bundle not found at: $BUNDLE_PATH"
fi

success "Bundle found at: $BUNDLE_PATH"

# Check if bundle is already in project
if grep -q "gpg.bundle" "$XCODE_PROJECT/project.pbxproj"; then
    info "Bundle already in project"
    exit 0
fi

info "Bundle not in project, adding manually..."
echo ""
info "Please add the bundle to Xcode manually:"
echo ""
echo "1. Open Moaiy.xcodeproj in Xcode"
echo "2. Right-click on 'Resources' group in the project navigator"
echo "3. Select 'Add Files to \"Moaiy\"...'"
echo "4. Navigate to and select: Moaiy/Resources/gpg.bundle"
echo "5. Make sure 'Copy items if needed' is UNCHECKED"
echo "6. Make sure 'Create groups' is selected"
echo "7. Click 'Add'"
echo ""
info "After adding:"
echo "- Verify bundle appears in 'Copy Bundle Resources' build phase"
echo "- Clean and rebuild the project"
echo ""
info "Alternatively, use Xcode's command line tools:"
echo ""
echo "  # Open Xcode"
echo "  open Moaiy/Moaiy.xcodeproj"
echo ""
echo "Then follow the manual steps above."

