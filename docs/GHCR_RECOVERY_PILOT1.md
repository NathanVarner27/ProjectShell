# GHCR pilot1 recovery — read-only acceptance

## Incident

GitHub Actions run 45581895436 (main source commit
a58c9bef2e9a29dc481dc6dad4553923ec4fc811) authenticated,
verified source-pinned ZIP and EXE attestations, staged the test-only
ZIP/EXE/MSIX distribution, and uploaded all six layers successfully.

ORAS reported:
- Reference: ghcr.io/nathanvarner27/projectshell-distribution-pilot:dbp-a58c9bef-pilot1
- Digest: sha256:d8d34fe4dafb4663c539505763d81fbd83b3048d2bb743d0edca0e3bf6924b43
- Failure: immediate ORAS pull reported `not found`.

The GitHub Action upload and OCI manifest push reported success, but the
registry round trip did not complete. Do not treat the package as verified,
and **do not rerun the original publish attempt with the same tag**.

## Read-only recovery

After merging the audit workflow, dispatch **DBP ProjectShell GHCR
existing artifact readback (READ ONLY)** from `main` with:

- `source_sha`: `a58c9bef2e9a29dc481dc6dad4553923ec4fc811`
- `installer_run_id`: `45568162567`
- `msix_run_id`: `45568162742`
- `package_tag`: `dbp-a58c9bef-pilot1`
- `expected_digest`: `sha256:d8d34fe4dafb4663c539505763d81fbd83b3048d2bb743d0edca0e3bf6924b43`

The workflow has only `packages: read`; it cannot upload, overwrite,
retag, delete or change package visibility. It checks CI source, attestations,
ZIP and EXE checksums, MSIX structural receipts, original tag digest,
and byte identity of all six files after retrieval.

If the tag still cannot resolve, investigate the GHCR package's visibility,
repository linkage, Actions access permissions, and package version status.
A one-time manifest upload success does not guarantee the version remains
readable. Do not manufacture a PASS based on the original push log.

No release, Windows installation or Microsoft Store submission is performed.
