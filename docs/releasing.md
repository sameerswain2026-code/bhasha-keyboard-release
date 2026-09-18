# Release runbook

## One-time GitHub setup

Create an Android upload keystore and store the base64-encoded keystore in the `ANDROID_KEYSTORE_BASE64` Actions secret. Store the complete `key.properties` contents in `ANDROID_KEY_PROPERTIES`, and the keystore password in `ANDROID_KEYSTORE_PASSWORD`. Add provider values as `GEMINI_API_KEYS`, `SARVAM_API_KEYS`, and `TAVILY_API_KEYS` only if the release is intentionally configured to use them.

## Versioning

Update `version:` in `pubspec.yaml` using semantic versioning and commit the change. Create and push an annotated tag:

```bash
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0
```

The tag workflow validates the project, builds a signed `app-release.aab`, and attaches it to a GitHub Release. A failed signing or quality check blocks publication.

## Rollback

GitHub Releases are immutable artifacts. If a release is defective, mark it as a pre-release or draft and publish a corrected patch version. Do not delete tags or rewrite the `main` branch history.
