# vPilot Remote Control

A vPilot plugin that broadcasts live network state (radio/private messages, connection status, and VATSIM airspace proximity alerts) to a local WebSocket server, paired with a companion Mac/iOS app for push notifications and basic remote control (connect/disconnect).

> **Status:** Early development. Not affiliated with vPilot, Ross Carlson, or VATSIM.

## Why

vPilot has no built-in way to notify you off-PC when someone messages you or when you're about to enter controlled airspace. This project closes that gap using vPilot's plugin API (`IBroker`) to broadcast state locally, which a native app on another device can subscribe to over the LAN.

## How it works

```
vPilot (IBroker events) → Plugin → WebSocket server (localhost:9001) → Mac/iOS app → Notifications
                                          ↑
                              VATSIM Data API (live ATC positions)
```

- The plugin runs inside vPilot and opens a local WebSocket server.
- It subscribes to `RadioMessageReceived`, `PrivateMessageReceived`, and connection events.
- It polls the [VATSIM Data API](https://vatsim.net) every 30s to check for nearby controllers and estimates time-to-intercept based on your current position/speed.
- Any device on your LAN running the companion app connects to `ws://<your-pc-ip>:9001` and receives a live event stream.
- The app can send `connect` / `disconnect` commands back to vPilot.

## Components

| Component | Language | Location |
|---|---|---|
| vPilot Plugin | C# (.NET Framework, matches vPilot's runtime) | `/plugin` |
| Installer | Inno Setup | `/installer` |
| Companion App | Swift (macOS/iOS, SwiftUI) | `/apps/swift` |

## Installation

### Plugin (Windows, where vPilot runs)

1. Download `VPilotRemoteControl-Setup.exe` from [Releases](../../releases).
2. Run it — it installs directly to `%LOCALAPPDATA%\vPilot\Plugins`.
3. Restart vPilot. Check the debug console for `vPilot Remote Control initialized`.
4. Note the IP address of the PC (`ipconfig` → IPv4 address) — you'll need this in the app.

### Companion App (Mac/iOS)

1. Open `apps/swift/VPilotRemote.xcodeproj` in Xcode, or download from TestFlight (once published).
2. On first launch, enter your PC's LAN IP (e.g. `192.168.1.100`) and port `9001`.
3. Grant notification permissions when prompted.

Both devices must be on the same LAN for now (see [ARCHITECTURE.md](ARCHITECTURE.md) for remote/WAN options).

## Building from source

### Plugin
```bash
cd plugin
dotnet build -c Release
```
Output DLL lands in `plugin/bin/Release/`. Copy alongside `RossCarlson.Vatsim.Vpilot.Plugins.dll` into vPilot's `Plugins` folder to test without the installer.

### Installer
Requires [Inno Setup 6](https://jrsoftware.org/isinfo.php).
```bash
iscc installer/VPilotRemoteControl.iss
```

### App
```bash
cd apps/swift
open VPilotRemote.xcodeproj
```

## Testing without Xcode

`tools/test-client.html` is a dependency-free WebSocket test client — open it in any browser on another device on your LAN, point it at the PC's IP and port 9001, and you'll see every plugin event live, plus buttons to send `connect`/`disconnect` commands. Useful for verifying the plugin works before touching the Swift app at all.

## Data & privacy

- No data leaves your LAN except calls to the public VATSIM Data API (your position is never sent anywhere but stays local — only used to compute distance client-side).
- No credentials ever leave vPilot: it authenticates with VATSIM itself, and the plugin can only ask an already-signed-in vPilot to go online with a callsign/type/SELCAL over your local network. See [ARCHITECTURE.md](ARCHITECTURE.md#security-model) for the security model and its current limitations before using this over WAN.

## License

MIT — see [LICENSE](LICENSE).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## Roadmap

See [SESSION_PLAN.md](SESSION_PLAN.md) for the build plan, and open [Issues](../../issues) for planned features (SimConnect live position, WAN relay, message replies from the app).
