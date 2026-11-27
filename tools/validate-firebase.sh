#!/bin/sh
set -eu
[ "$CONFIGURATION" = Release ] || exit 0
plist="$SRCROOT/Tokipin/GoogleService-Info.plist"
if [ ! -f "$plist" ] ||
   [ "$(/usr/bin/plutil -extract PROJECT_ID raw -o - "$plist")" != "tokipin-app" ] ||
   [ "$(/usr/bin/plutil -extract BUNDLE_ID raw -o - "$plist")" != "$PRODUCT_BUNDLE_IDENTIFIER" ]; then
    echo "error: Place the tokipin-app iOS GoogleService-Info.plist for $PRODUCT_BUNDLE_IDENTIFIER in Tokipin/ before building Release."
    exit 1
fi
