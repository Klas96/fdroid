#!/bin/bash
set -e

echo "[1/5] Running fdroid update..."
fdroid update --create-metadata

echo "[2/5] Adding changes in repo/ and metadata/..."
git add repo/ metadata/

echo "[3/5] Committing changes..."
git commit -m "Update F-Droid repo index and metadata [automated]" || echo "No changes to commit."

echo "[4/5] Pushing to remote..."
git push

echo "[5/5] Done! F-Droid repo index and metadata updated and pushed." 