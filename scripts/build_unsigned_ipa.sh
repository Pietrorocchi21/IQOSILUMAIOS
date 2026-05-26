#!/usr/bin/env bash
set -euo pipefail

APP_NAME="IQOSIlumaIOS"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_DIR="${ROOT_DIR}/build/DerivedData"
PAYLOAD_DIR="${ROOT_DIR}/build/Payload"
IPA_PATH="${ROOT_DIR}/build/${APP_NAME}.ipa"

echo "==> Building ${APP_NAME} for iOS device (unsigned)"
rm -rf "${ROOT_DIR}/build"
mkdir -p "${PAYLOAD_DIR}"

echo "==> Running xcodebuild..."
xcodebuild \
  -project "${ROOT_DIR}/${APP_NAME}.xcodeproj" \
  -scheme "${APP_NAME}" \
  -configuration Release \
  -sdk iphoneos \
  -derivedDataPath "${DERIVED_DATA_DIR}" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  build

APP_BUNDLE_PATH="${DERIVED_DATA_DIR}/Build/Products/Release-iphoneos/${APP_NAME}.app"
echo "==> Looking for app bundle at: ${APP_BUNDLE_PATH}"

if [[ ! -d "${APP_BUNDLE_PATH}" ]]; then
  echo "❌ App bundle not found at: ${APP_BUNDLE_PATH}" >&2
  echo "Available directories:" >&2
  find "${DERIVED_DATA_DIR}" -type d -name "*.app" 2>/dev/null || echo "No .app found" >&2
  exit 1
fi

echo "==> Copying app bundle to Payload..."
cp -R "${APP_BUNDLE_PATH}" "${PAYLOAD_DIR}/"

echo "==> Creating IPA..."
(
  cd "${ROOT_DIR}/build"
  /usr/bin/zip -qry "${IPA_PATH}" Payload
)
rm -rf "${PAYLOAD_DIR}"

echo "✅ IPA created at: ${IPA_PATH}"
ls -lh "${IPA_PATH}"
