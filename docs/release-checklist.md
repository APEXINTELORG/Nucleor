# Release Checklist

This checklist is for the public `APEXINTELORG/Nucleor` release path.

## Before Tagging

- `main` points at the intended release commit.
- `bin/nucleor.exe --version` and `nuc.bat --version` report the release
  version.
- Windows verifier is green.
- Linux bootstrap, self-host fixed point, full verifier, and rust bridge
  harness are green on the chosen Linux runner.
- Performance evidence is recorded on the pinned performance host.
- Secret inventory has no unresolved real credentials.
- Public docs do not contain private paths, personal data, internal
  coordination notes, or unexplained development-only labels.
- `SAFETY.md` is present, linked from the README, and still matches the current
  robotics, control, real-time, and release-signing boundaries.

## Package

- Create the release tag from the verified commit when signing is ready.
- Before signing is ready, run `Build Release Candidate Artifacts` in GitHub
  Actions or run `tools\make_release_candidate.ps1` locally. This produces the
  unsigned candidate package, source archives, checksums, and release-notes
  draft.
- After SSL.com or Azure signing verification completes, run
  `Sign Windows Release Artifacts` in GitHub Actions.
- Attach these assets to the GitHub release:

```text
nucleor-v<version>-windows-x86_64.zip
nucleor-v<version>-windows-x86_64.zip.sha256
nucleor-v<version>-source.zip
nucleor-v<version>-source.tar.gz
windows-artifacts.sha256
windows-authenticode.json
windows-release-summary.md
SHA256SUMS.txt
RELEASE_NOTES_DRAFT.md
```

## Verify Before Publishing

- Download the release assets from GitHub.
- Verify SHA256 checksums.
- Verify Authenticode status for each Windows binary.
- Build and run `examples/01_hello.nr` from the release package.
- Confirm release notes name the version, commit, verifier result, Linux
  status, Windows signing status, and known limitations.
- Confirm release notes or README still point users to `SAFETY.md` for robotics,
  hardware-control, real-time, and untrusted-code boundaries.
- If the package is unsigned, the release notes must say: "Windows
  Authenticode signing is awaiting certificate/vendor verification completion."

## Notes

- User-mode Authenticode signing is enough for the current Windows artifacts.
  Kernel-mode signing is only needed for Windows drivers or kernel-loaded
  components.
- Hosted GitHub runners are useful correctness gates. They are not a stable
  performance baseline unless the runner class is pinned and repeatable.
- Do not publish the final signed release until the manual signing workflow
  reports `Valid` Authenticode status for every Windows binary.
