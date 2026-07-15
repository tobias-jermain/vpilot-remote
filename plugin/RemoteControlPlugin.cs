using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Net.WebSockets;
using System.Text;
using System.Text.Json;
using System.Threading;
using System.Threading.Tasks;
using RossCarlson.Vatsim.Vpilot.Plugins;
using RossCarlson.Vatsim.Vpilot.Plugins.Events;

namespace VPilotRemoteControl
{
    public class RemoteControlPlugin : IPlugin
    {
        public string Name => "vPilot Remote Control";

        private const int ProtocolVersion = 1;
        private const int WebSocketPort = 9001;
        private const double AlertThresholdMinutes = 5.0;

        private IBroker _broker;
        private HttpListener _httpListener;
        private readonly ConcurrentDictionary<Guid, WebSocket> _clients = new();
        private CancellationTokenSource _cts;
        private System.Timers.Timer _atcCheckTimer;
        private readonly HashSet<string> _alreadyAlerted = new();

        // Live state. Position fields are placeholders until SimConnect is
        // wired in (Session 3) — see ARCHITECTURE.md "Known limitations".
        private bool _isConnected;
        private string _callsign = "";
        private double _latitude, _longitude;
        private int _groundSpeedKts;

        public void Initialize(IBroker broker)
        {
            _broker = broker;
            _cts = new CancellationTokenSource();

            _broker.NetworkConnected += OnNetworkConnected;
            _broker.NetworkDisconnected += OnNetworkDisconnected;
            _broker.RadioMessageReceived += OnRadioMessageReceived;
            _broker.PrivateMessageReceived += OnPrivateMessageReceived;

            StartWebSocketServer();

            _atcCheckTimer = new System.Timers.Timer(30_000);
            _atcCheckTimer.Elapsed += async (s, e) => await CheckNearbyAtcAsync();
            _atcCheckTimer.Start();

            _broker.PostDebugMessage($"{Name} initialized. Listening on ws://localhost:{WebSocketPort}");
        }

        // --- WebSocket server -------------------------------------------------

        private void StartWebSocketServer()
        {
            Task.Run(async () =>
            {
                _httpListener = new HttpListener();
                _httpListener.Prefixes.Add($"http://+:{WebSocketPort}/");

                try
                {
                    _httpListener.Start();
                }
                catch (HttpListenerException)
                {
                    // Binding to all interfaces (needed so LAN devices can reach this)
                    // requires either admin privileges or a URL ACL reservation — the
                    // installer sets one up automatically. Without it, HttpListener
                    // throws here. Fall back to loopback-only so local testing on this
                    // same PC still works, rather than failing to start entirely.
                    _broker.PostDebugMessage(
                        $"{Name}: couldn't bind to all interfaces — LAN devices won't be able to connect. " +
                        $"Run as admin once, or run 'netsh http add urlacl url=http://+:{WebSocketPort}/ user=Everyone' " +
                        "(see CONTRIBUTING.md). Falling back to localhost-only.");
                    _httpListener = new HttpListener();
                    _httpListener.Prefixes.Add($"http://localhost:{WebSocketPort}/");
                    _httpListener.Start();
                }

                while (!_cts.IsCancellationRequested)
                {
                    try
                    {
                        var context = await _httpListener.GetContextAsync();
                        if (context.Request.IsWebSocketRequest)
                        {
                            _ = HandleClientAsync(context); // fire-and-forget per client
                        }
                        else
                        {
                            context.Response.StatusCode = 400;
                            context.Response.Close();
                        }
                    }
                    catch (Exception ex) when (!_cts.IsCancellationRequested)
                    {
                        _broker.PostDebugMessage($"WebSocket listener error: {ex.Message}");
                    }
                }
            }, _cts.Token);
        }

        private async Task HandleClientAsync(HttpListenerContext context)
        {
            var clientId = Guid.NewGuid();
            WebSocket socket = null;

            try
            {
                var wsContext = await context.AcceptWebSocketAsync(null);
                socket = wsContext.WebSocket;
                _clients[clientId] = socket;

                await SendAsync(socket, new
                {
                    v = ProtocolVersion,
                    type = "state_change",
                    isConnected = _isConnected,
                    callsign = _callsign,
                    timestamp = DateTime.UtcNow
                });

                var buffer = new byte[4096];
                while (socket.State == WebSocketState.Open && !_cts.IsCancellationRequested)
                {
                    var result = await socket.ReceiveAsync(new ArraySegment<byte>(buffer), _cts.Token);
                    if (result.MessageType == WebSocketMessageType.Close) break;
                    if (result.MessageType == WebSocketMessageType.Text)
                    {
                        var text = Encoding.UTF8.GetString(buffer, 0, result.Count);
                        HandleClientCommand(text);
                    }
                }
            }
            catch (Exception ex)
            {
                _broker.PostDebugMessage($"Client {clientId} error: {ex.Message}");
            }
            finally
            {
                _clients.TryRemove(clientId, out _);
                socket?.Dispose();
            }
        }

        private void HandleClientCommand(string json)
        {
            try
            {
                using var doc = JsonDocument.Parse(json);
                var root = doc.RootElement;
                if (!root.TryGetProperty("action", out var actionEl)) return;

                switch (actionEl.GetString())
                {
                    case "connect":
                        var callsign = root.GetProperty("callsign").GetString();
                        var typeCode = root.GetProperty("typeCode").GetString();
                        var selcal = root.TryGetProperty("selcal", out var sc) ? sc.GetString() : null;
                        // vPilot authenticates with VATSIM itself (CID/password live in
                        // vPilot's own settings) — the plugin can only ask vPilot to go
                        // online with a callsign/type/selcal. No credentials cross the wire.
                        _broker.RequestConnect(callsign, typeCode, selcal);
                        break;

                    case "disconnect":
                        _broker.RequestDisconnect();
                        break;

                    default:
                        _broker.PostDebugMessage($"Unknown remote action: {actionEl.GetString()}");
                        break;
                }
            }
            catch (Exception ex)
            {
                _broker.PostDebugMessage($"Failed to handle client command: {ex.Message}");
            }
        }

        private void BroadcastAsync(object payload)
        {
            var json = JsonSerializer.Serialize(payload);
            var bytes = Encoding.UTF8.GetBytes(json);
            var segment = new ArraySegment<byte>(bytes);

            foreach (var (id, socket) in _clients)
            {
                if (socket.State != WebSocketState.Open)
                {
                    _clients.TryRemove(id, out _);
                    continue;
                }

                // Fire-and-forget with a timeout guard so one slow client can't
                // stall the broadcast loop for everyone else. See ARCHITECTURE.md
                // "Known limitations" — a bounded queue per client is the proper fix.
                _ = SendWithTimeoutAsync(socket, segment, id);
            }
        }

        private async Task SendWithTimeoutAsync(WebSocket socket, ArraySegment<byte> data, Guid clientId)
        {
            try
            {
                var sendTask = socket.SendAsync(data, WebSocketMessageType.Text, true, _cts.Token);
                if (await Task.WhenAny(sendTask, Task.Delay(1000)) != sendTask)
                {
                    _clients.TryRemove(clientId, out _);
                }
            }
            catch
            {
                _clients.TryRemove(clientId, out _);
            }
        }

        private static async Task SendAsync(WebSocket socket, object payload)
        {
            var json = JsonSerializer.Serialize(payload);
            var bytes = Encoding.UTF8.GetBytes(json);
            await socket.SendAsync(new ArraySegment<byte>(bytes), WebSocketMessageType.Text, true, CancellationToken.None);
        }

        // --- IBroker event handlers -------------------------------------------

        private void OnNetworkConnected(object sender, NetworkConnectedEventArgs e)
        {
            _isConnected = true;
            _callsign = e.Callsign;
            _alreadyAlerted.Clear();
            BroadcastAsync(new { v = ProtocolVersion, type = "state_change", isConnected = true, callsign = _callsign, timestamp = DateTime.UtcNow });
        }

        private void OnNetworkDisconnected(object sender, EventArgs e)
        {
            _isConnected = false;
            BroadcastAsync(new { v = ProtocolVersion, type = "state_change", isConnected = false, callsign = _callsign, timestamp = DateTime.UtcNow });
        }

        private void OnRadioMessageReceived(object sender, RadioMessageReceivedEventArgs e)
        {
            BroadcastAsync(new
            {
                v = ProtocolVersion,
                type = "radio_message",
                from = e.From,
                message = e.Message,
                frequencies = e.Frequencies,
                timestamp = DateTime.UtcNow
            });
        }

        private void OnPrivateMessageReceived(object sender, PrivateMessageReceivedEventArgs e)
        {
            BroadcastAsync(new
            {
                v = ProtocolVersion,
                type = "private_message",
                from = e.From,
                message = e.Message,
                timestamp = DateTime.UtcNow
            });
        }

        // --- VATSIM airspace polling ------------------------------------------

        private static readonly HttpClient SharedHttpClient = new HttpClient
        {
            Timeout = TimeSpan.FromSeconds(10)
        };

        private async Task CheckNearbyAtcAsync()
        {
            if (!_isConnected) return;

            try
            {
                var response = await SharedHttpClient.GetAsync("https://data.vatsim.net/v3/vatsim-data.json");
                if (!response.IsSuccessStatusCode) return;

                var json = await response.Content.ReadAsStringAsync();
                using var doc = JsonDocument.Parse(json);
                var controllers = doc.RootElement.GetProperty("controllers");

                foreach (var controller in controllers.EnumerateArray())
                {
                    if (!controller.TryGetProperty("callsign", out var callsignEl)) continue;
                    var callsign = callsignEl.GetString();

                    if (!TryGetDouble(controller, "latitude", out var lat) ||
                        !TryGetDouble(controller, "longitude", out var lon))
                        continue;

                    var distanceNm = HaversineNm(_latitude, _longitude, lat, lon);
                    var etaMinutes = TimeToInterceptMinutes(distanceNm, _groundSpeedKts);

                    if (etaMinutes >= 0 && etaMinutes <= AlertThresholdMinutes)
                    {
                        if (_alreadyAlerted.Contains(callsign)) continue; // de-dup per session
                        _alreadyAlerted.Add(callsign);

                        var frequency = controller.TryGetProperty("frequency", out var freqEl) ? freqEl.GetString() : "";

                        BroadcastAsync(new
                        {
                            v = ProtocolVersion,
                            type = "airspace_alert",
                            controller = callsign,
                            frequency,
                            timeToIntercept = Math.Round(etaMinutes, 1),
                            distance = Math.Round(distanceNm, 1),
                            timestamp = DateTime.UtcNow
                        });
                    }
                }
            }
            catch (Exception ex)
            {
                _broker.PostDebugMessage($"ATC check failed: {ex.Message}");
            }
        }

        private static bool TryGetDouble(JsonElement obj, string prop, out double value)
        {
            value = 0;
            if (!obj.TryGetProperty(prop, out var el)) return false;
            return el.TryGetDouble(out value);
        }

        /// <summary>Great-circle distance in nautical miles. Does not account for heading —
        /// see ARCHITECTURE.md known limitations.</summary>
        private static double HaversineNm(double lat1, double lon1, double lat2, double lon2)
        {
            const double earthRadiusNm = 3440.065;
            double dLat = ToRadians(lat2 - lat1);
            double dLon = ToRadians(lon2 - lon1);
            double a = Math.Sin(dLat / 2) * Math.Sin(dLat / 2) +
                       Math.Cos(ToRadians(lat1)) * Math.Cos(ToRadians(lat2)) *
                       Math.Sin(dLon / 2) * Math.Sin(dLon / 2);
            double c = 2 * Math.Atan2(Math.Sqrt(a), Math.Sqrt(1 - a));
            return earthRadiusNm * c;
        }

        private static double ToRadians(double deg) => deg * Math.PI / 180.0;

        private static double TimeToInterceptMinutes(double distanceNm, int groundSpeedKts)
        {
            if (groundSpeedKts <= 0) return -1;
            return (distanceNm / groundSpeedKts) * 60.0;
        }
    }
}
