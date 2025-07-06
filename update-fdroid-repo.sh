#!/bin/bash
set -e

echo "[1/6] Running fdroid update..."
fdroid update --create-metadata

echo "[2/6] Copying updated files to public repo directory..."
cp -r repo/* fdroid/repo/

echo "[3/6] Adding changes in repo/ and metadata/..."
git add repo/ metadata/

echo "[4/6] Adding changes in public repo directory..."
git add fdroid/repo/

echo "[5/6] Committing changes..."
git commit -m "Update F-Droid repo index and metadata [automated]" || echo "No changes to commit."

echo "[6/6] Pushing to remote..."
git push

echo "Done! F-Droid repo index and metadata updated and pushed." 