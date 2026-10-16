#!/bin/bash
set -e

# The keystore password is no longer stored in config.yml; fdroidserver reads it
# from the FDROID_KEYSTORE_PASS environment variable (config.yml uses
# `keystorepass: {env: FDROID_KEYSTORE_PASS}`). Provide it via a gitignored .env
# file next to this script (FDROID_KEYSTORE_PASS=...), an exported variable, or
# type it when prompted.
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"
if [ -z "$FDROID_KEYSTORE_PASS" ] && [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
fi
if [ -z "$FDROID_KEYSTORE_PASS" ]; then
  read -r -s -p "F-Droid keystore password: " FDROID_KEYSTORE_PASS
  echo
fi
export FDROID_KEYSTORE_PASS

echo "[1/6] Pulling latest changes (CI may have published releases)..."
git pull --rebase

echo "[2/6] Running fdroid update..."
fdroid update --create-metadata

echo "[3/6] Copying updated files to public repo directory (if present)..."
if [ -d fdroid/repo ]; then
  cp -r repo/* fdroid/repo/
  git add fdroid/repo/
fi

echo "[4/6] Adding changes in repo/ and metadata/..."
git add repo/ metadata/

echo "[5/6] Committing changes..."
git commit -m "Update F-Droid repo index and metadata [automated]" || echo "No changes to commit."

echo "[6/6] Pushing to remote..."
git push

echo "Done! F-Droid repo index and metadata updated and pushed."
