# Contributing

Thanks for considering a contribution. This project is small and personal in origin, so the bar for helpfulness is low — typo fixes and issue reports are just as welcome as features.

## Before you start

- Check open [Issues](../../issues) and [SESSION_PLAN.md](SESSION_PLAN.md) to see what's already planned or in progress, to avoid duplicate work.
- For anything beyond a small fix, open an issue first to discuss approach — especially for anything touching the [security model](ARCHITECTURE.md#security-model), since that's the area most likely to need careful review before merging.

## Development setup

**Plugin (Windows required — vPilot is Windows-only):**
1. Install [.NET SDK](https://dotnet.microsoft.com/download) matching the target framework in `plugin/VPilotRemoteControl.csproj`.
2. Install vPilot, locate `RossCarlson.Vatsim.Vpilot.Plugins.dll` in its install folder, and reference it from the `.csproj` (see comments in that file — it's not published to NuGet).
3. `dotnet build -c Debug` in `/plugin`, then copy the output DLL + XML into vPilot's `Plugins` folder to test live.
4. Use `_broker.PostDebugMessage(...)` liberally — vPilot's debug console is your primary debugging tool since there's no interactive debugger attached to vPilot's process by default (attaching Visual Studio to the vPilot process works if you need breakpoints).

**App (Mac required — Xcode):**
1. Open `apps/swift/VPilotRemote.xcodeproj`.
2. Run the plugin locally first so there's a `ws://localhost:9001` to connect to.
3. Both macOS and iOS targets share the `VPilotRemoteClient` WebSocket layer — keep protocol-handling code there rather than duplicating it per-platform.
4. The `.xcodeproj` is generated from `apps/swift/project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`). If you add/remove/move a source file or change a build setting, edit `project.yml` and run `xcodegen generate` from `apps/swift/` rather than editing the project in Xcode's file inspector — otherwise your change won't survive the next regeneration, and CI regenerates from `project.yml` on every build.

## Branch naming

`type/short-description`, e.g.:
- `feat/pairing-token-auth`
- `fix/reconnect-backoff`
- `docs/update-security-model`

## Commits & PRs

- Keep PRs focused — one concern per PR. A "fix reconnect + also restyle the message list" PR is harder to review and more likely to get stuck.
- Reference the issue number in the PR description if one exists.
- If your change touches the message protocol (`ARCHITECTURE.md` → Message protocol), update both the plugin and the Swift client in the same PR — they must stay in sync, and there's no versioning safety net yet.
- Update the relevant `.md` doc alongside code changes. Docs that drift from behavior are worse than no docs.

## Testing

There's no automated test suite yet (flagged in SESSION_PLAN.md as a gap). Until then:
- Manually verify plugin changes against a live vPilot session where possible — a VATSIM "observer" connection is enough to test message events without needing to actually fly.
- For app changes, test against a running local plugin instance, not just mocked data, before opening a PR — the WebSocket reconnect edge cases are the most common source of bugs.

## Security-sensitive changes

Anything touching authentication, credential handling, or network exposure (e.g. adding a WAN relay) should be flagged clearly in the PR title/description and will get slower, more careful review. Please don't be offended by extra scrutiny here — see the rationale in [ARCHITECTURE.md](ARCHITECTURE.md#security-model).

## Code of conduct

Be respectful, assume good faith, keep feedback specific and actionable. No formal CoC document yet for a project this size — if that changes as contributors join, this section will be replaced with a proper one.
