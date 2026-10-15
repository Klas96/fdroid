# F-Droid release guide

Apps are published into this repository from each app’s own GitHub Actions
release workflow (same pattern as Echoes of Elysium and mooves):

1. Build a signed APK in the app repo.
2. Check out `Klas96/fdroid` with the deploy key.
3. Copy the APK into `repo/<packageId>_<versionCode>.apk`.
4. Ensure `metadata/<packageId>.yml` exists (copied from the app’s
   `fdroid/metadata.yml` on first publish).
5. Run `fdroid update` with the repo keystore secrets.
6. Commit and push `repo/` and `metadata/`.

## Legacy scripts

The old ContentCreator-oriented scripts (`release-to-fdroid.sh`,
`build-and-upload-apk.sh`, `simple-build-upload.sh`) were removed when
ContentCreator (`com.contentcreator.app`) was retired from this repo.

`release-helper.sh` remains as a KeyMatch troubleshooting helper for local
monorepo layouts; prefer the CI workflows above for production publishes.
