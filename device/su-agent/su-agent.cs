// A device process that asks Azure Device Registry for software updates, the way the C SDK client does.
//
// WHAT: OUR implementation of the device side, written from the sources of the Azure IoT C SDK 2.0.0-preview.2
//       (c/src/features/su/su_protocol.c, su_channel_dps.c, docs/eng/software-updates.md). It is NOT the Microsoft client.
//       The service side is real: DPS, Azure Device Registry and Azure Update Service.
// HOW:  the device PULLS. It never receives a push: it opens an MQTT 3.1.1 + TLS session to DPS with its bootstrap certificate
//       and, every time it asks, the service answers with an update or with nothing. In order:
//         1. ask "is there an update for me?" (topic iotdps-get-deviceupdate), declaring manufacturer, model and the installed update;
//         2. if there is one: verify the signature of the manifest (RS256: root key -> signing key -> manifest hash),
//            download each file over HTTPS and check size and SHA-256;
//         3. report IN_PROGRESS, keep the good version aside, install the file, test it, and if the test fails restore the good version;
//         4. report SUCCEEDED or FAILED (with the result code) and remember the installed update.
// NEEDS: .NET 11 and PowerShell (pwsh) for the self-test of the installed file. No packages: the MQTT part is a few lines of
//        MQTT 3.1.1 on an SslStream, the signature is System.Security.Cryptography.
//
// Run:  dotnet run su-agent.cs -- --folder <device folder> --registration-id <id> --id-scope <scope> --state <folder>
//       [--manufacturer Contoso] [--model RobotV1] [--poll-seconds N]   (0 = ask once and exit)
//       <device folder> holds bootstrap-chain.pem and bootstrap-key.pem.

using System.Net.Security;
using System.Net.Sockets;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text;
using System.Text.Json;
using System.Text.Json.Nodes;
using System.Text.RegularExpressions;

const string DpsHost = "global.azure-devices-provisioning.net";
const int SuccessCode = 700;                         // AZ_IOT_SU_AGENT_RESULT_CODE_SUCCESS
const uint FacilityInstall = 0x5, FacilityRefused = 0xB, FacilityHash = 0x3;   // the top 4 bits of the extended result code

var opt = ParseArgs(args);
string folder = opt["folder"], regId = opt["registration-id"], idScope = opt["id-scope"], state = opt["state"];
string manufacturer = opt.GetValueOrDefault("manufacturer", "Contoso"), model = opt.GetValueOrDefault("model", "RobotV1");
int pollSeconds = int.Parse(opt.GetValueOrDefault("poll-seconds", "0"));
Directory.CreateDirectory(state);

Say($"device {regId}: connecting to DPS ({DpsHost}) with the bootstrap certificate");
await using var dps = await DpsSession.OpenAsync(folder, regId, idScope);
Say("connected");
while (true)
{
    var outcome = await CheckOnce();
    if (pollSeconds <= 0 || outcome == "installed") break;
    Say($"next check in {pollSeconds} s");
    await Task.Delay(TimeSpan.FromSeconds(pollSeconds));
}
Say("device process ends");
return 0;

// ------------------------------------------------------------------------------------------------ one check
async Task<string> CheckOnce()
{
    var cur = ReadJson(Path.Combine(state, "installed.json"));
    var ask = new JsonObject
    {
        ["agentInfo"] = new JsonObject
        {
            ["agentSdkVersion"] = "DU;agent/1.0.0",
            ["agentProfile"] = 1,
            ["compatibilityProperties"] = new JsonObject { ["manufacturer"] = manufacturer, ["model"] = model },
        },
    };
    if (cur != null) ask["installedUpdateId"] = cur.DeepClone();
    Say($"asking for updates (manufacturer={manufacturer}, model={model}, installed={(cur == null ? "nothing" : cur["name"] + " " + cur["version"])})");
    var (status, ans) = await dps.RequestAsync("iotdps-get-deviceupdate", ask);
    if (status != 200) { Say($"  the service answers {status}: {ans}"); return "error"; }
    var meta = ans["updateMetadata"];
    if (meta == null) { Say("  the service answers 200 with no update: nothing for this device"); return "none"; }

    var wf = (string)meta["workflowId"]!;
    Say($"  UPDATE OFFERED, workflow {wf}");
    JsonNode manifest;
    try { manifest = await VerifyUpdate(meta, (string)ans["serviceConfiguration"]!["rootKeyDownloadUrl"]!); }
    catch (Exception ex)
    {
        Say($"  signature check FAILED: {ex.Message}; the update is refused");
        await Report(wf, cur, Result("FAILED", "AGENT_CORE", -11, FacilityRefused, $"update refused: {ex.Message}"));
        return "refused";
    }
    var uid = manifest["updateId"]!;
    var newId = new JsonObject { ["provider"] = (string)uid["provider"]!, ["name"] = (string)uid["name"]!, ["version"] = (string)uid["version"]! };
    Say($"  update: {newId["provider"]} / {newId["name"]} / {newId["version"]}");

    var fid = (string)manifest["instructions"]!["steps"]![0]!["files"]![0]!;
    var file = manifest["files"]![fid]!;
    string fileName = (string)file["fileName"]!;
    string download = Path.Combine(state, "download");
    Directory.CreateDirectory(download);
    string dest = Path.Combine(download, fileName);
    try
    {
        using var http = new HttpClient();
        var bytes = await http.GetByteArrayAsync((string)meta["fileUrls"]![fid]!);      // HTTPS only
        if (bytes.Length != (long)file["sizeInBytes"]!) throw new Exception($"size {bytes.Length} instead of {file["sizeInBytes"]}");
        if (Convert.ToBase64String(SHA256.HashData(bytes)) != (string)file["hashes"]!["sha256"]!) throw new Exception("SHA-256 does not match the manifest");
        await File.WriteAllBytesAsync(dest, bytes);
        Say($"  downloaded {fileName} over HTTPS: {bytes.Length} bytes, SHA-256 matches the manifest");
    }
    catch (Exception ex)
    {
        Say($"  download/check FAILED: {ex.Message}");
        await Report(wf, cur, Result("FAILED", "AGENT_CORE", -2, FacilityHash, ex.Message));
        return "failed";
    }

    await Report(wf, cur, Result("IN_PROGRESS", "NOT_APPLICABLE", 1, 0));
    string payloadDir = Path.Combine(state, "payload");
    Directory.CreateDirectory(payloadDir);
    string current = Path.Combine(payloadDir, "current.ps1"), good = Path.Combine(payloadDir, "good.ps1");
    bool hadGood = File.Exists(current);
    if (hadGood) { File.Copy(current, good, true); Say("  the good version is kept aside"); }
    File.Copy(dest, current, true);
    Say($"  installed {fileName}; testing it");
    var (ok, detail) = await SelfTest(current);
    if (!ok)
    {
        Say($"  TEST FAILED ({detail}): restoring the good version");
        if (hadGood) File.Copy(good, current, true); else File.Delete(current);
        var failed = Result("FAILED", "DEVICE", -5, FacilityInstall, $"self-test failed: {detail}");
        await Report(wf, cur, failed, failed);
        return "failed";
    }
    Say($"  test passed (payloadVersion {detail})");
    File.WriteAllText(Path.Combine(state, "installed.json"), newId.ToJsonString());
    var success = Result("SUCCEEDED", "NOT_APPLICABLE", SuccessCode, 0);
    await Report(wf, newId, success, success);
    return "installed";
}

// ------------------------------------------------------------------------------------------------ report (topic iotdps-report-deviceupdatestatus)
async Task Report(string workflowId, JsonNode? installed, JsonObject result, JsonObject? step = null)
{
    var body = new JsonObject { ["workflowId"] = workflowId, ["installResult"] = result.DeepClone() };
    if (installed != null) body["installedUpdateId"] = installed.DeepClone();
    if (step != null) body["installResult"]!["stepResults"] = new JsonObject { ["step_0"] = step.DeepClone() };
    var (status, answer) = await dps.RequestAsync("iotdps-report-deviceupdatestatus", body);
    Say($"  report {result["outcome"]}: the service answers {status}" + (status == 200 ? "" : " " + answer));
}

static JsonObject Result(string outcome, string origin, int code, uint facility, string? details = null)
{
    // extendedResultCodes: the facility in the top 4 bits, in hexadecimal without 0x and without padding (su_protocol.c)
    var r = new JsonObject
    {
        ["outcome"] = outcome, ["failureOrigin"] = origin, ["resultCode"] = code,
        ["extendedResultCodes"] = (facility << 28).ToString("X"),
    };
    if (details != null) r["resultDetails"] = details.Length > 1000 ? details[..1000] : details;
    return r;
}

// ------------------------------------------------------------------------------------------------ the self-test of the installed file
static async Task<(bool, string)> SelfTest(string path)
{
    // the file must define Get-Telemetry and it must answer with a payloadVersion
    var psi = new System.Diagnostics.ProcessStartInfo("pwsh") { RedirectStandardOutput = true, RedirectStandardError = true };
    foreach (var a in new[] { "-NoProfile", "-NonInteractive", "-Command", $". '{path}'; (Get-Telemetry).payloadVersion" }) psi.ArgumentList.Add(a);
    using var p = System.Diagnostics.Process.Start(psi)!;
    var o = p.StandardOutput.ReadToEndAsync();
    var e = p.StandardError.ReadToEndAsync();
    await p.WaitForExitAsync();
    string output = (await o).Trim();
    // PowerShell colours its errors with escape sequences: take them out and keep the last readable line (the message)
    var err = Regex.Replace(await e, "\u001b\\[[0-9;]*m", "").Split('\n').Select(l => l.Trim(' ', '|', '\r')).Where(l => l.Length > 0).ToArray();
    return (p.ExitCode == 0 && output.Length > 0, output.Length > 0 ? output : err.LastOrDefault() ?? "no output");
}

// ------------------------------------------------------------------------------------------------ signature: root key -> signing key -> manifest hash (RS256)
async Task<JsonNode> VerifyUpdate(JsonNode meta, string rootKeyUrl)
{
    string manifestText = (string)meta["updateManifest"]!;
    string outer = (string)meta["updateManifestSignature"]!;
    var rootKeys = await LoadRootKeys(rootKeyUrl);
    string sjwk = (string)JsonNode.Parse(B64u(outer.Split('.')[0]))!["sjwk"]!;
    string kid = (string)JsonNode.Parse(B64u(sjwk.Split('.')[0]))!["kid"]!;
    if (!rootKeys.TryGetValue(kid, out var root)) throw new Exception($"root key {kid} unknown or disabled");
    var jwk = JsonNode.Parse(VerifyCompact(sjwk, root))!;
    Say($"  signing key signed by root key {kid}: ok");
    using var signing = Rsa((string)jwk["n"]!, (string)jwk["e"]!);
    var signed = JsonNode.Parse(VerifyCompact(outer, signing))!;
    if ((string)signed["sha256"]! != Convert.ToBase64String(SHA256.HashData(Encoding.UTF8.GetBytes(manifestText))))
        throw new Exception("manifest hash differs from the signed one");
    Say("  manifest signed by the signing key and its hash matches: ok");
    return JsonNode.Parse(manifestText)!;
}

// The root keys come from the root key package the service points to (HTTPS); kept in the state folder.
async Task<Dictionary<string, RSA>> LoadRootKeys(string url)
{
    string path = Path.Combine(state, "rootkeypackage.json");
    if (!File.Exists(path))
    {
        Say($"root key package: download from {url.Split('?')[0]}");
        using var http = new HttpClient();
        await File.WriteAllBytesAsync(path, await http.GetByteArrayAsync(url));
    }
    var pkg = JsonNode.Parse(File.ReadAllText(path))!["protected"]!;
    var disabled = pkg["disabledRootKeys"]!.AsArray().Select(x => (string)x!).ToHashSet();
    return pkg["rootKeys"]!.AsObject().Where(k => !disabled.Contains(k.Key))
        .ToDictionary(k => k.Key, k => Rsa((string)k.Value!["n"]!, k.Value!["e"]!.ToString()));
}

static RSA Rsa(string n, string e)
{
    // e is a number in the root key package (65537) and base64url in a JWK
    byte[] exponent = int.TryParse(e, out var num) ? BitConverter.GetBytes(num).Reverse().SkipWhile(b => b == 0).ToArray() : B64uBytes(e);
    var rsa = RSA.Create();
    rsa.ImportParameters(new RSAParameters { Modulus = B64uBytes(n), Exponent = exponent });
    return rsa;
}

static string VerifyCompact(string jws, RSA key)
{
    var parts = jws.Split('.');
    if ((string)JsonNode.Parse(B64u(parts[0]))!["alg"]! != "RS256") throw new Exception("alg must be RS256");
    if (!key.VerifyData(Encoding.ASCII.GetBytes(parts[0] + "." + parts[1]), B64uBytes(parts[2]), HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1))
        throw new Exception("signature does not match");
    return B64u(parts[1]);
}

static byte[] B64uBytes(string s) => Convert.FromBase64String(s.Replace('-', '+').Replace('_', '/').PadRight(s.Length + (4 - s.Length % 4) % 4, '='));
static string B64u(string s) => Encoding.UTF8.GetString(B64uBytes(s));

// ------------------------------------------------------------------------------------------------ small things
static void Say(string msg) => Console.WriteLine($"{DateTime.Now:HH:mm:ss}  {msg}");
static JsonNode? ReadJson(string path) => File.Exists(path) ? JsonNode.Parse(File.ReadAllText(path)) : null;

static Dictionary<string, string> ParseArgs(string[] a)
{
    var d = new Dictionary<string, string>();
    for (int i = 0; i + 1 < a.Length; i += 2) d[a[i].TrimStart('-')] = a[i + 1];
    foreach (var k in new[] { "folder", "registration-id", "id-scope", "state" })
        if (!d.ContainsKey(k)) throw new ArgumentException($"missing --{k}");
    return d;
}

// ------------------------------------------------------------------------------------------------ the DPS session: MQTT 3.1.1 over TLS, only what the check needs
sealed class DpsSession : IAsyncDisposable
{
    const string ApiVersionForConnect = "2026-11-02-preview";     // the DPS api-version the SDK sends in the CONNECT user name
    readonly TcpClient tcp;
    readonly SslStream tls;
    int counter, packetId;
    readonly System.Collections.Concurrent.ConcurrentDictionary<string, TaskCompletionSource<(int, JsonNode)>> waiting = new();
    readonly SemaphoreSlim writeLock = new(1, 1);

    DpsSession(TcpClient t, SslStream s) { tcp = t; tls = s; }

    public static async Task<DpsSession> OpenAsync(string folder, string regId, string idScope)
    {
        // the leaf is bootstrap-chain.pem's first certificate; the rest of the file is the CA that issued it
        var chain = new X509Certificate2Collection();
        chain.ImportFromPemFile(Path.Combine(folder, "bootstrap-chain.pem"));
        using var leafPublic = chain[0];
        // a key read from PEM is ephemeral and Windows (SChannel) cannot use it for TLS: going through a PFX makes it usable
        using var withKey = X509Certificate2.CreateFromPemFile(Path.Combine(folder, "bootstrap-chain.pem"), Path.Combine(folder, "bootstrap-key.pem"));
        var leaf = X509CertificateLoader.LoadPkcs12(withKey.Export(X509ContentType.Pfx), null);
        var extra = new X509Certificate2Collection();
        for (int i = 1; i < chain.Count; i++) extra.Add(chain[i]);

        var tcp = new TcpClient();
        await tcp.ConnectAsync("global.azure-devices-provisioning.net", 8883);
        var tls = new SslStream(tcp.GetStream(), false);
        await tls.AuthenticateAsClientAsync(new SslClientAuthenticationOptions
        {
            TargetHost = "global.azure-devices-provisioning.net",
            ClientCertificateContext = SslStreamCertificateContext.Create(leaf, extra, offline: true),
            EnabledSslProtocols = SslProtocols.Tls12 | SslProtocols.Tls13,
        });
        var s = new DpsSession(tcp, tls);
        // CONNECT: client id = registration id, user name = <idScope>/registrations/<registrationId>/api-version=<version>, clean session
        await s.SendAsync(0x10, Concat(Str("MQTT"), new byte[] { 4, 0x82, 0, 60 }, Str(regId),
            Str($"{idScope}/registrations/{regId}/api-version={ApiVersionForConnect}")));
        var (type, body) = await s.ReadPacketAsync();
        if (type != 0x20 || body[1] != 0) throw new Exception($"DPS refused the connection (CONNACK {(body.Length > 1 ? body[1] : -1)})");
        _ = Task.Run(s.ReadLoopAsync);
        // SUBSCRIBE to every response, QoS 1
        var subscribe = Concat(new byte[] { 0, 1 }, Str("$dps/registrations/res/#"), new byte[] { 1 });
        await s.SendAsync(0x82, subscribe);
        await Task.Delay(1000);     // the SUBACK
        return s;
    }

    public async Task<(int, JsonNode)> RequestAsync(string operation, JsonNode body, int timeoutSeconds = 60)
    {
        string rid = "su" + Interlocked.Increment(ref counter);
        var tcs = new TaskCompletionSource<(int, JsonNode)>(TaskCreationOptions.RunContinuationsAsynchronously);
        waiting[rid] = tcs;
        // PUBLISH QoS 1: topic, packet id, payload
        int id = Interlocked.Increment(ref packetId);
        var packet = Concat(Str($"$dps/registrations/POST/{operation}/?$rid={rid}"), new[] { (byte)(id >> 8), (byte)id }, Encoding.UTF8.GetBytes(body.ToJsonString()));
        await SendAsync(0x32, packet);
        return await tcs.Task.WaitAsync(TimeSpan.FromSeconds(timeoutSeconds));
    }

    async Task ReadLoopAsync()
    {
        try
        {
            while (true)
            {
                var (type, body) = await ReadPacketAsync();
                if ((type & 0xF0) != 0x30) continue;                             // only PUBLISH matters
                int topicLength = (body[0] << 8) | body[1];
                string topic = Encoding.UTF8.GetString(body, 2, topicLength);
                int offset = 2 + topicLength;
                if ((type & 0x06) != 0)                                          // QoS 1: acknowledge with PUBACK
                {
                    await SendAsync(0x40, new[] { body[offset], body[offset + 1] });
                    offset += 2;
                }
                // $dps/registrations/res/<status>/?$rid=<rid>[&retry-after=<s>]
                int status = int.Parse(topic.Split("/res/")[1].Split('/')[0]);
                string rid = topic.Split("$rid=")[1].Split('&')[0];
                var payload = body.Length > offset ? JsonNode.Parse(body.AsSpan(offset)) ?? new JsonObject() : new JsonObject();
                if (waiting.TryRemove(rid, out var tcs)) tcs.TrySetResult((status, payload));
            }
        }
        catch { /* the session is closed */ }
    }

    async Task SendAsync(byte header, byte[] body)
    {
        await writeLock.WaitAsync();
        try
        {
            var packet = new List<byte> { header };
            int len = body.Length;
            do { byte b = (byte)(len % 128); len /= 128; if (len > 0) b |= 128; packet.Add(b); } while (len > 0);
            packet.AddRange(body);
            await tls.WriteAsync(packet.ToArray());
            await tls.FlushAsync();
        }
        finally { writeLock.Release(); }
    }

    async Task<(byte, byte[])> ReadPacketAsync()
    {
        var first = new byte[1];
        await tls.ReadExactlyAsync(first);
        int len = 0, shift = 0;
        while (true)
        {
            var b = new byte[1];
            await tls.ReadExactlyAsync(b);
            len |= (b[0] & 127) << shift;
            if ((b[0] & 128) == 0) break;
            shift += 7;
        }
        var body = new byte[len];
        await tls.ReadExactlyAsync(body);
        return (first[0], body);
    }

    static byte[] Str(string s) { var b = Encoding.UTF8.GetBytes(s); return new[] { (byte)(b.Length >> 8), (byte)b.Length }.Concat(b).ToArray(); }
    static byte[] Concat(params byte[][] parts) => parts.SelectMany(p => p).ToArray();

    public async ValueTask DisposeAsync()
    {
        try { await SendAsync(0xE0, Array.Empty<byte>()); } catch { }     // DISCONNECT
        tls.Dispose();
        tcp.Dispose();
    }
}
