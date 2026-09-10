# Project instructions

Read and follow `/Users/adt/.codex/RTK.md` when available. Prefix shell commands with `rtk`.

## Completion and releases

The user explicitly requests that completed work in this project includes a push
and a release, without asking for confirmation again. Unless the user overrides
this for a particular task:

1. Complete the implementation and relevant checks.
2. Update the Flutter app version and its `APP_VERSION` fallback consistently;
   choose the next unused release version after checking remote tags/releases.
3. Commit the changes, push to the project remote, and push an annotated `v*`
   tag to trigger `.github/workflows/release-packages.yml`.
4. Monitor CI and verify the GitHub release contains the macOS DMG, Windows EXE,
   Linux DEB, and AppImage before reporting the release complete.
5. If publication is blocked or fails, report the actual state and resolve it
   when possible; do not describe a pushed tag as a finished release.

Do not overwrite existing release tags or include unrelated user changes.
