# Android Update Installability and Signing Continuity — 2026-11-28

## Status

**Confirmed release-blocking defect. Remediation is required before distributing a new APK as an update.**

This report records a verified incompatibility between two APK artifacts produced by the repository's current GitHub Actions workflow. It is a release/installation gate, not a completed fix. Do not mark update installation as accepted until the signing and versioning requirements below have been implemented and an upgrade-over-install test passes.

## User impact

A new CUTAWAN APK is expected to update the app already installed on the phone. Requiring the user to uninstall the old app first is unacceptable: Android removes the app's private data on uninstall, which can destroy local projects, settings, credentials, and other app-owned state. Reinstallation is not a valid update procedure or workaround for release acceptance.

## Repository and build evidence

- Repository: `m5ham3ds/CUTAWAN`
- Branch: `main` only
- Current source commit: `c5d0d8729dc08a1333a9616818bbb5b700b28fa8`
- Current Android workflow: [run 490 / run ID 46089582143](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46089582143) — completed successfully.
- Current artifact: [`cutawan-mobile-arm64-debug`, artifact 15241001194](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46089582143/artifacts/15241001194).
- Previous comparison artifact: [`cutawan-mobile-arm64-debug`, artifact 15231197350](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622887/artifacts/15231197350), from source commit `716408d244b688f028bececf5f72b9e356cee8e0`.

Both artifacts were downloaded and the embedded `app-debug.apk` files were inspected. Their Android manifests report the same application identity and version:

| APK metadata | Previous artifact 15231197350 | Current artifact 15241001194 |
|---|---|---|
| Application ID | `com.m5ham3ds.cutawan_mobile` | `com.m5ham3ds.cutawan_mobile` |
| Version name | `0.2.0` | `0.2.0` |
| Version code | `2` | `2` |
| Build type | Debug (`debuggable=true`) | Debug (`debuggable=true`) |
| Signing certificate subject | `CN=Android Debug, O=Android, C=US` | `CN=Android Debug, O=Android, C=US` |
| Signing certificate SHA-256 | `b0ee238aec107aa86a33281dcbbf3339d0e4a843addd47352a3dd1813f9fa2d2` | `788da6f3c5b598e26f11637774d6d2b6e4a1067622f970e1c69909d88b4675a2` |

**The signing-certificate fingerprints do not match.** The two APKs therefore do not have the same Android signing identity. A package already installed with the previous certificate cannot be updated in place by the current APK under the same application ID; Android rejects an update signed by a different certificate (commonly reported as `INSTALL_FAILED_UPDATE_INCOMPATIBLE`). This is a concrete, artifact-level explanation for the reported need to uninstall before installing a newer build when the installed copy was signed by the earlier artifact's key.

The exact installation error shown by the user's handset was not captured in this investigation. The incompatibility between these two repository APKs is nevertheless directly verified from their signing certificates; a physical-device upgrade test is still required after remediation.

## Confirmed configuration gap

The current workflow at `.github/workflows/mobile-android.yml`:

1. Runs on a fresh `ubuntu-latest` hosted runner.
2. Generates the Android project during CI using `flutter create --platforms=android --org com.m5ham3ds --project-name cutawan_mobile .`.
3. Builds the distributable artifact using `flutter build apk --debug --target-platform android-arm64`.
4. Uploads that debug APK as `cutawan-mobile-arm64-debug`.

The Android project is generated instead of being retained as a checked-in, release-configured Android project. The generator `mobile/flutter_app/tooling/generate_android_platform.sh` contains no persistent release-keystore configuration or stable signing-certificate check. There is no repository-managed signing identity wired into this APK job. Consequently the default Android debug signing identity is not guaranteed to persist between clean hosted runners; the different certificate fingerprints above prove that it did not persist for the two compared artifacts.

The source `mobile/flutter_app/pubspec.yaml` currently declares `version: 0.2.0+2`. The built manifests confirm that both artifacts use version name `0.2.0` and version code `2`. This is a separate versioning defect/risk: the installed-version sequence is not advanced for new builds. A device with a higher installed version code may reject an older APK as a downgrade, and a release process must never ship a new update with an untracked or regressing version code. The equal version code is not the certificate mismatch demonstrated above; it must be fixed as an independent release requirement.

## Required remediation — mandatory acceptance criteria

All criteria below are required. A successful compile, unit-test suite, emulator smoke test, or APK upload alone does not satisfy this gate.

### 1. Preserve application identity

- Keep the production `applicationId` permanently set to `com.m5ham3ds.cutawan_mobile` for all update builds.
- Add a CI assertion that reads the built APK manifest and fails if the application ID changes unexpectedly.
- Do not create a separate `.debug` application ID for the artifact intended to update the installed production app.
- Preserve compatible minimum-SDK and ABI requirements; an ARM64-only build is acceptable for the stated ARM64 target, but ABI packaging is not a substitute for signing continuity.

### 2. Use one persistent production signing identity

- Stop distributing per-run debug-signed APKs as the normal user update.
- Create or select one durable Android upload/release keystore and use it for every production APK update.
- Store the keystore and passwords only in protected GitHub Actions secrets (for example, a base64-encoded keystore, store password, key alias, and key password). Reconstruct the keystore in the runner without printing secret values.
- Never commit the keystore, passwords, signing properties, or private key material to Git.
- Back up the keystore securely outside the repository. Losing it can permanently block ordinary updates signed with that identity.
- Add an explicit signing-certificate fingerprint verification step. CI must fail before artifact upload if the built APK certificate differs from the approved production fingerprint.
- Do not rotate the signing certificate casually. Any planned key rotation must use and verify Android's supported signing-key rotation/lineage process and be tested against the installed release.

### 3. Make version codes monotonically increase

- Replace the unchanged `0.2.0+2` release value with a controlled release-versioning policy.
- Every production update must have a version code strictly greater than the highest version code previously distributed to users.
- Keep the human-readable version name intentional and traceable to the release.
- Add a CI check that fails if the candidate version code is equal to or lower than the recorded latest production version code.
- Do not rely on an arbitrary CI run identifier unless it is proven to be a valid, bounded, monotonic Android version code for every release and rerun.

### 4. Prove update-over-install behavior

Add an automated Android emulator upgrade test to the release gate:

1. Install the last accepted production APK as the baseline.
2. Create and persist a non-sensitive app-owned test marker (and, where safe, a test project fixture).
3. Install the candidate APK over the existing package using update semantics (for example, `adb install -r candidate.apk`); do not uninstall, clear app data, or change the application ID.
4. Assert that installation succeeds, the package remains `com.m5ham3ds.cutawan_mobile`, the signing certificate is the approved certificate, and the candidate version code is higher.
5. Launch the updated app and verify that the persisted marker/project fixture remains present.
6. Retain the install output and test evidence as workflow artifacts. The test must fail the release if the old app must be removed first or app-owned data disappears.

The test must use a baseline artifact signed with the same production key as the candidate. Emulator success is an automated gate; final OEM/handset acceptance must still be recorded separately.

### 5. Separate CI validation APKs from user-distributable releases

- Debug APKs may remain available for internal diagnostics only when clearly labeled and never presented as the supported in-place update for the production app.
- The user-downloadable APK must be the consistently signed, version-incremented production artifact.
- Do not publish or upload a release artifact until package identity, signing identity, version monotonicity, ARM64 packaging, and upgrade-over-install checks all pass.

## Explicit non-causes / boundaries

- The ARM64-only packaging check does not explain a signature mismatch.
- The successful workflow conclusion only proves that the configured build and test steps completed; it does not prove that one APK can update another.
- The manifest's `android:allowBackup="false"` setting is not the cause of the APK signer mismatch. It is a separate app-data backup policy.
- Do not ask users to uninstall the previous app or clear its storage as a workaround.

## Current disposition

- **Artifact-level signing continuity: FAILED / confirmed.**
- **Application ID continuity between the two inspected APKs: PASSED.**
- **Version-code advancement: FAILED / not implemented (both inspected APKs are code 2).**
- **Automated update-over-install test: NOT IMPLEMENTED.**
- **Physical handset update acceptance: NOT RUN.**
- **Production update release gate: BLOCKED.**

This issue remains open until the mandatory remediation and tests above are implemented, reviewed, and evidenced. This documentation commit records and prioritizes the issue only; it does not modify the Android build configuration or claim the update problem is fixed.
