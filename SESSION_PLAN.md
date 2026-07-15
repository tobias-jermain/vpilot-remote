# Session Plan

Three build sessions. Session 1 ends with a working end-to-end MVP — plugin loaded in vPilot, broadcasting real events, received live by a client. Sessions 2 and 3 add the airspace intelligence, control, packaging, and polish that make it a real tool rather than a proof of concept.

Each session assumes ~3–4 hours of focused work. Adjust down and split further if needed.

---

## Session 1 — MVP: plugin talks to a client, live

**Goal:** Prove the core loop works before investing in installers or a native app. By the end of this session you should be able to send a private message to your callsign on VATSIM (or trigger a radio message via observer mode) and see it appear, in real time, in a plain WebSocket test client — no Xcode required yet.

### Tasks
1. **Scaffold the plugin project** (~30 min)
   - `dotnet new classlib` targeting the framework vPilot's plugin API requires.
   - Reference `RossCarlson.Vatsim.Vpilot.Plugins.dll` from your vPilot install folder.
   - Implement the empty `IPlugin` shell (`Name`, `Initialize`) and confirm vPilot loads it — check the debug console for your plugin's name on startup. **Do this first and confirm it works before writing anything else** — a plugin that fails to load silently is the most time-costly failure mode here.

2. **Wire up IBroker events** (~45 min)
   - Subscribe to `NetworkConnected`, `NetworkDisconnected`, `RadioMessageReceived`, `PrivateMessageReceived`.
   - For each, just `PostDebugMessage` the event contents to confirm they fire correctly before adding networking.

3. **Local WebSocket server** (~1.5 hrs)
   - `HttpListener` + `AcceptWebSocketAsync` on `localhost:9001`.
   - On each `IBroker` event, serialize to the JSON shapes defined in `ARCHITECTURE.md` and broadcast to connected clients.
   - Keep the client list and broadcast logic simple — no reconnect handling, no auth yet. That's deliberately deferred.

4. **Prove it end-to-end** (~30–45 min)
   - Use a throwaway test client — either a browser console (`new WebSocket('ws://localhost:9001')`) or `websocat`/`wscat` from the terminal. Do **not** build the Swift app yet.
   - Connect vPilot to VATSIM in observer mode (no live traffic risk), send yourself a private message from another client or the VATSIM web-based text client, and confirm it arrives in your test WebSocket client within ~1 second.

### Session 1 deliverable (MVP definition)
- [ ] Plugin loads in vPilot without errors.
- [ ] `RadioMessageReceived` and `PrivateMessageReceived` events reach a locally connected WebSocket client as JSON.
- [ ] Connection state changes (`state_change`) are broadcast on connect/disconnect.
- [ ] Verified with a real (even if trivial, observer-mode) VATSIM session — not just simulated events.

If you're short on time, cut the `NetworkConnected`/`Disconnected` wiring before cutting the message events — messages are the actual point of the notification use case; connection state is secondary.

---

## Session 2 — Airspace intelligence, remote control, and installer

**Goal:** Turn the MVP into the actual product: airspace alerts, remote connect/disconnect, and a real one-click installer. Native app work is deliberately still deferred — keep testing against the plain WebSocket client from Session 1 so you can iterate on the plugin without Xcode build cycles slowing you down.

### Tasks
1. **VATSIM API polling + distance calc** (~1 hr)
   - Timer polling `https://data.vatsim.net/v3/vatsim-data.json` every 30s.
   - Haversine distance from current position to each online controller.
   - Note: without SimConnect (deferred to Session 3), you won't have live position yet — hardcode a test lat/lon/speed for now so you can validate the alert logic independently of the SimConnect integration. This decouples two hard problems instead of debugging them simultaneously.

2. **Airspace alert logic** (~45 min)
   - Time-to-intercept from distance + ground speed.
   - Fire `airspace_alert` when ETA ≤ 5 min, with basic de-duplication (don't re-fire every 30s for the same controller — track "already alerted" per controller per session).

3. **Remote connect/disconnect** (~1 hr)
   - Handle incoming `{"action": "connect", ...}` / `{"action": "disconnect"}` from the WebSocket.
   - Confirm `IBroker.RequestConnect` signature against your installed vPilot version's XML docs — verify whether a disconnect method exists or whether a workaround is needed (flagged as unresolved in ARCHITECTURE.md).
   - Test by sending these commands from your Session 1 test client.

4. **Inno Setup installer** (~1 hr)
   - Write `installer/VPilotRemoteControl.iss` targeting `%LOCALAPPDATA%\vPilot\Plugins`.
   - Build with `iscc`, test on a clean-ish machine or VM if possible — installer bugs are easy to miss when testing on your dev machine where paths already exist.

5. **Start the Swift app skeleton** (~30–45 min, stretch)
   - Only if time remains: scaffold the Xcode project and get a bare WebSocket connection working against your plugin. Full UI is Session 3's job.

### Session 2 deliverable
- [ ] Airspace alerts fire correctly against a hardcoded test position.
- [ ] Remote connect/disconnect works from a test client.
- [ ] `.exe` installer successfully installs the plugin and vPilot loads it post-install.

---

## Session 3 — SimConnect, app polish, and release packaging

**Goal:** Real live position data, a usable native app, and everything needed to actually publish this as an open-source release.

### Tasks
1. **SimConnect integration** (~1.5–2 hrs — the hardest task in the plan, budget accordingly)
   - Add the SimConnect managed client to the plugin project (separate from `IBroker` — this is a second connection to the sim, not part of vPilot's plugin API).
   - Subscribe to lat/lon/altitude/ground speed, feed into the Session 2 airspace calc in place of the hardcoded test values.
   - If this overruns, it's fine to ship v1 with the hardcoded/manual position entry as a documented limitation and pick this up as a fast-follow issue — don't let it block the rest of the release.

2. **Swift app: notifications + UI** (~1.5 hrs)
   - Build out the SwiftUI views from the earlier draft (connection status, message list, connect sheet).
   - Wire local notifications for each message type.
   - Add basic reconnect-on-reconnect logic (flagged as missing in ARCHITECTURE.md) — at minimum, retry on a timer when the socket closes unexpectedly.

3. **Settings persistence** (~30 min)
   - Store server IP/port in `UserDefaults` so it's not re-entered every launch.

4. **Release packaging** (~1 hr)
   - Finalize `LICENSE`, confirm all four docs are accurate to actual behavior (docs drift is easy to introduce during Sessions 2–3 — do a pass now).
   - Tag a `v0.1.0` release, attach the built installer `.exe` as a release asset.
   - Fill in the GitHub Actions workflow (`.github/workflows/build.yml`) to at minimum build the plugin on push, so future contributors get CI feedback without you manually verifying every PR.

### Session 3 deliverable
- [ ] Live SimConnect position feeding real airspace alerts (or clearly documented as a known gap if deferred).
- [ ] Working Mac/iOS app with notifications, connect/disconnect, and message history.
- [ ] Tagged `v0.1.0` GitHub release with installer attached.
- [ ] All docs accurate and consistent with shipped behavior.

---

## After session 3

Not required for v0.1.0, but worth tracking as issues rather than scope-creeping into the sessions above:
- Pairing-token auth on the WebSocket (see security model in ARCHITECTURE.md — do this before any WAN exposure).
- Heading-aware airspace ETA instead of straight-line.
- Automated tests for the distance/ETA math at minimum, since that's the most testable pure-logic piece.
- WAN relay option for off-LAN use.
