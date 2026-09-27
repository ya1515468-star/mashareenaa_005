# MASHAREENA — Production & Security Audit Report

Date: 2026-09-27
Source archive inspected: `MASHAREEN__FINAL.zip`

## Scope

Static review of the supplied Flutter + Supabase project, including Dart/Flutter
source, Android configuration, Supabase SQL migrations, Edge Functions, assets,
CI workflow, and filename/content-based secret detection.

This audit does **not** replace a live penetration test, a live Supabase RLS
permission test against the production database, or a dependency advisory scan
against a current vulnerability database. The build environment in this session
cannot reach external build/package servers, so a local APK build was not possible.

## Inventory

- Files in sanitized source tree: 1399
- Dart files: 448
- SQL files: 82
- TypeScript Edge Function files: 4
- Assets/images files: 815
- Source size before Git compression: 24.22 MiB

## Security findings

### High / release-blocking items fixed

1. **Local machine configuration exposure** — `android/local.properties` was
   present in the supplied archive and contained Windows SDK paths. It is removed
   from the sanitized source and is now ignored by Git.
2. **Release signing configuration** — the supplied Android tree contained
   competing Gradle DSL files and an older release configuration that was not
   suitable for a controlled production signing flow. The sanitized tree keeps
   the canonical Groovy Gradle configuration and reads release signing values
   from `android/key.properties`, which is generated only in CI from GitHub Secrets.
3. **Cleartext traffic** — `AndroidManifest.xml` explicitly allowed cleartext
   traffic even though the network security config denied it. The manifest is now
   `usesCleartextTraffic="false"`.
4. **CI release gate** — the old workflow only ran the `test/chat/` subset. The
   sanitized workflow runs the full `flutter test` suite, static security scan,
   analyzer, then the ARM64 release build. (`test/chat/` does exist; the change is
   to make the release gate cover the whole test suite.)

### Medium / residual risks

1. **WebView JavaScript** — YouTube/TikTok embeds intentionally use unrestricted
   JavaScript because those providers require it. This remains a residual attack
   surface and should be kept behind strict URL/domain validation. The TikTok host
   check was tightened to exact `tiktok.com` / subdomains, and the plain video
   preview no longer enables JavaScript.
2. **Client-visible Supabase key** — `lib/core/config/supabase_config.dart` contains
   a `sb_publishable_...` key. This is a publishable/client key and is not equivalent
   to a Supabase service-role key. Privileged operations must continue to be enforced
   by RLS and authenticated server functions.
3. **Upload surface** — the client upload gateway applies extension, size, magic-byte,
   and path checks; server-side Storage policies remain the security boundary.
   Because the audit was static, the live Storage policies were not executed here.

### Secret scan result

- Private keys: **not detected**
- JKS/keystore files: **not detected**
- `.env` files: **not detected**
- Service-account JSON: **not detected**
- GitHub tokens / AWS access keys: **not detected**
- Supabase service-role secret: **not detected**
- High-confidence secret errors: **0**

## Supabase / server-side review

The project contains extensive server-authoritative controls. Static verification
scripts included with the project were executed successfully:

- `verify_execution_contract.py`: **27/27 passed**
- `verify_final_document_gate.py`: **passed**
- `verify_strict_document_completion.py`: **passed**
- `verify_strict_effect_engine.py`: **18/18 passed**

Reviewed SQL includes explicit hardening such as `SET search_path` on canonical
security-definer wrappers and revocation of anonymous execution for sensitive RPCs.
The supplied migration history also contains owner/authentication checks for
sensitive admin flows.

## Production ARM64 CI

The sanitized workflow builds:

`flutter build apk --release --target-platform android-arm64 --split-per-abi`

It then verifies that the generated APK contains `lib/arm64-v8a/` and validates
the APK signature with Android `apksigner`. The workflow requires these GitHub
Secrets before building:

- `ANDROID_KEYSTORE_BASE64`
- `ANDROID_KEYSTORE_PASSWORD`
- `ANDROID_KEY_ALIAS`
- `ANDROID_KEY_PASSWORD`

The keystore is created only inside the ephemeral runner and is not committed.

## Copyright / ownership

Added:

- `LICENSE` — proprietary/no-redistribution notice
- `COPYRIGHT.md` — Arabic ownership/copyright notice
- README copyright notice

The wording intentionally identifies **MASHAREENA** as the project rights holder
without inventing a legal person/company name that was not supplied. Third-party
packages remain subject to their own licenses.

## Repository upload status

The requested GitHub repository `ya1515468-star/mashareenaa_03` could not be
accessed through the connected GitHub account during this run (repository lookup
returned HTTP 404). The GitHub connector also did not expose a repository-creation
action. Therefore no claim of a successful push is made.

Once the repository exists and the connected GitHub account has push/admin access,
the included workflow is ready to run from **Actions → MASHAREENA Android ARM64
Release → Run workflow**, after the four signing secrets are configured.

## Integrity

Deterministic source manifest SHA-256: `bc302850a7665655f2e22c6011da6caabb33c1b2a3d30e32a2fe49210e446920`
