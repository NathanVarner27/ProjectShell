# ProjectShell distribution acceptance fixture for Distribution Builder Pilot (DBP)

## Purpose and channels

This fixture gives DBP a source-pinned published-then-pulled reference for
Windows distribution files. A successful GitHub Packages round trip verifies
registry transport, not Windows installation, MSIX signing, Store approval,
or DBP's own builder implementation.

| Channel | File or reference | Current confidence |
| --- | --- | --- |
| GitHub Actions | ProjectShell v1.2.0 Windows x64 ZIP | CI-built and Windows-isolated-install verified |
| GitHub Actions | ProjectShell v1.2.0 standalone Setup EXE | CI-built; bootstrap clean-exit regression fix requires live runtime retest |
| GitHub Actions | ProjectShell v1.2.0 unsigned CI MSIX | Structural only, not install-tested or Store-ready |
| GitHub Packages (GHCR) | OCI file artifact plus checksums and metadata | Manual, opt-in test publication only |
| GitHub Releases | v1.2.0 | Remains a draft until separately approved |
| Microsoft Store | MSIX package submission | Not attempted; identity, runtime and certification not verified |

A GHCR OCI file artifact is not a runnable Docker image, although GitHub
lists it under container packages. Pull with ORAS, not Docker run.

## GitHub Actions publishing sequence

1. Merge the reviewed GHCR fixture workflow and source test PR only after
   checking tests. Do not alter existing v1.2.0 draft assets during this pilot.
2. On the new main commit, wait for all three existing workflows:
   PowerShell source validation, Windows installer launcher build, and
   ProjectShell Manager MSIX structural preview (NONPUBLISHING).
3. Record the successful push-event installer and MSIX workflow run IDs.
   The GHCR fixture checks their head_sha equals the commit of the manually
   dispatched GHCR workflow. Prior-run assets from an older commit are rejected.
4. Go to Actions -> DBP ProjectShell GHCR distribution pilot (MANUAL) ->
   Run workflow on main, and supply installer_run_id, msix_run_id, a unique
   package_tag such as review-1.2.0-rc1, and publish=false for the first review.
5. The dry run checks exact commit identity, CI success, GitHub artifact
   attestations for ZIP/EXE, checksum-file integrity, x64 PE structure,
   ZIP CRC and unsigned MSIX structural receipt. It retains the verified
   file set as ProjectShell-DBP-GHCR-PILOT-REVIEW-ONLY.
6. Only after reviewing the dry run, repeat with a fresh unused tag and
   publish=true. The workflow authenticates through GITHUB_TOKEN, pushes to
   ghcr.io/nathanvarner27/projectshell-distribution-pilot:<tag> and pulls
   the files back. All six files must compare byte-for-byte.
   packages:write permission is limited to the manual pilot job.
7. Verify the new package appears on the GitHub account's Packages page.
   GHCR package visibility may default to private; review access manually.
   A successful push does not publish a GitHub Release or MSIX to Store.

If a package tag already exists, stop; do not overwrite verified versions.

## DBP end-to-end product acceptance (separate from reference publication)

After reference GHCR succeeds:

- Have DBP build a Windows distribution ZIP from approved ProjectShell source;
  verify inventory, manifest, checksum, extraction and code equivalence.
- Have DBP copy a reviewed prebuilt standalone Setup EXE; do not claim DBP
  compiled it. Check PE x64, digest and Authenticode unsigned status.
- Have DBP produce/process unsigned MSIX structural preview using the
  ProjectShell Manager launcher, not the installer EXE. Verify manifest,
  identity and included assets, but record signed=false, installed=false,
  runtime_msix_verified=false, store_ready=false.
- Exercise DBP guided GitHub Actions, draft Release and publication confirmation.
  Distinguish prepared, uploaded, published, and roundtrip_verified.
- Test cancellations, authentication/permissions failure, bad archives,
  mismatched source SHA, duplicate tags and unsuccessful CI runs.
- DBP must not automatically publish, delete, replace, sign or install
  anything without explicit user approval.

Passing the reference GHCR workflow does not automatically pass DBP.
DBP's own output and user-facing publishing controls still need observed
end-to-end acceptance.

## Release and privacy boundaries

- Never upload real local ProjectShell profiles, settings, saved shortcuts,
  user backups or private workstation paths to GHCR or CI artifacts.
- The real v1.2.0 standalone EXE previously printed an error after reporting
  successful installation. The development branch removes the trailing NUL
  in the generated bootstrap, but a clean exit must be retested on Windows.
- Preserve public v1.1.0 and keep v1.2.0 in draft pending separate approval.
- CI MSIX is not a signed, user-installable or Store-approved artifact.
  Partner Center identity, full-trust runtime, branded assets, signing/trust
  where required, install/update/uninstall tests and Store certification
  remain separate.
