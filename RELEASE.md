# Bhasha Keyboard release checklist

## What CI produces

Every push to `main` runs analysis, tests, and produces a debug APK as a GitHub Actions artifact. A manual run or a version tag such as `v1.2.0` runs the signed release job and produces `app-release.apk` and `app-release.aab`. A version tag also creates a GitHub Release with both files attached.

## Required GitHub secrets for release builds

Configure these repository secrets before running the signed-release job:

- `ANDROID_KEYSTORE_BASE64`: base64-encoded upload keystore.
- `ANDROID_KEY_PROPERTIES`: complete `android/key.properties` content. The `storeFile` value must be `upload-keystore.jks`.

The repository must never contain the keystore, `key.properties`, provider API keys, or passwords. If network-backed providers are enabled through CI, keep their values in GitHub Secrets and inject them only through the approved build configuration.

## Creating a version release

After testing the debug APK, update the version in `pubspec.yaml`, commit the change, and create a tag:

```bash
git tag -a v1.2.0 -m "Bhasha Keyboard 1.2.0"
git push origin main v1.2.0
```

Download the signed AAB from the GitHub Release and upload that AAB to Google Play Console. Use the APK only for local/device testing; Google Play normally expects an AAB for a new production release.

## Play Console requirements

Before publishing, host `docs/privacy.md` at a public HTTPS URL and use that exact URL in Play Console. Complete the Data Safety form, content rating, target audience, app access, support contact, and permission declarations consistently with the shipped build. Microphone use and network speech processing must be disclosed. Play approval cannot be guaranteed by CI; Google reviews the final binary, store listing, declarations, privacy policy, and signing configuration.
