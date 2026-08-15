#!/bin/sh
#
# Xcode Cloud runs this right before it builds. Without it, Xcode Cloud stamps
# the archive with its own CI_BUILD_NUMBER (which started at 1), so builds came
# out numbered below the App Store's existing build 19 and would eventually
# collide with it.
#
# Here we set CFBundleVersion ourselves to CI_BUILD_NUMBER + 20. That is always
# above the old builds and always climbs with each Xcode Cloud run, so uploads
# never clash and never go backwards.
#
set -e

OFFSET=20
BUILD=$(( ${CI_BUILD_NUMBER:-1} + OFFSET ))
PLIST="$CI_PRIMARY_REPOSITORY_PATH/purenote/Info.plist"

/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $BUILD" "$PLIST"
echo "Set CFBundleVersion to $BUILD (CI_BUILD_NUMBER=${CI_BUILD_NUMBER:-unset} + $OFFSET)"
