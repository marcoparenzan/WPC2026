#:sdk Microsoft.NET.Sdk.Web

// A REST API that authenticates with a CERTIFICATE, not with a key or a token.
//
// WHAT: a small HTTPS API that only lets in clients whose certificate was issued by the Azure Device Registry (ADR)
//       Issuing CA of our namespace: the same certificate a device uses with the IoT Hub.
// WHY:  the certificate a device gets from ADR is a normal X.509 certificate. It opens the IoT Hub, but nothing stops
//       you from using it to open YOUR OWN service: no shared secret to store, no token to renew.
// HOW:  Kestrel asks every client for a certificate during the TLS handshake and checks three things:
//         1. the chain ends in the ADR Root CA that we trust;
//         2. the certificate is not revoked: ADR publishes a revocation list (CRL), the address is in the certificate;
//         3. the certificate is inside its dates and is meant for client authentication.
//       The device identity is the common name of the certificate (the registration ID).
//
// Two things found by trying (2026-11-22), both about ADR certificates:
//   - The certificate of the device has a CRITICAL extension of Microsoft (1.3.6.1.4.1.311.133.1.1.1, 32 bytes). A strict
//     X.509 validator must refuse a critical extension it does not know, and .NET does (HasNotSupportedCriticalExtension).
//     This API tolerates that one extension by name, and nothing else. Any other unknown critical extension is refused.
//   - ADR does publish the CRL (http://primary-cdn.pki.azure.net/<region>/crls/...): a certificate revoked with
//     "az iot adr ns device auth revoke-certs" appears there, so this API can refuse it too.
//
// Run:  dotnet run cert-api.cs -- <adr-trust.pem> [port]
//       adr-trust.pem = the Root CA and the Issuing CA of ADR, as PEM (the notebook builds it from the chain of a device).
// Try:  GET  https://localhost:8443/whoami      who am I, according to my certificate
//       POST https://localhost:8443/telemetry   send a JSON message

using System.Security.Cryptography;
using System.Security.Cryptography.X509Certificates;
using System.Text.Json.Nodes;
using Microsoft.AspNetCore.Server.Kestrel.Https;

if (args.Length < 1)
{
    Console.Error.WriteLine("usage: dotnet run cert-api.cs -- <adr-trust.pem> [port]");
    return 1;
}

// The trust file holds the Root (self-signed: our anchor) and the Issuing CA (only a helper to build the chain).
var bundle = new X509Certificate2Collection();
bundle.ImportFromPem(File.ReadAllText(args[0]));
var roots = bundle.Where(c => c.Subject == c.Issuer).ToArray();
var helpers = bundle.Where(c => c.Subject != c.Issuer).ToArray();
if (roots.Length == 0)
{
    Console.Error.WriteLine("The trust file has no root CA (a self-signed certificate).");
    return 1;
}
var port = args.Length > 1 ? int.Parse(args[1]) : 8443;

// The only critical extensions we accept besides the ones every validator knows.
const string BasicConstraints = "2.5.29.19";
const string KeyUsage = "2.5.29.15";
const string MicrosoftAdrExtension = "1.3.6.1.4.1.311.133.1.1.1";
// What .NET reports because of that extension, and only on the device certificate.
const X509ChainStatusFlags ToleratedOnLeaf =
    X509ChainStatusFlags.HasNotSupportedCriticalExtension | X509ChainStatusFlags.InvalidExtension;

// The certificate of the SERVER: a throw-away self-signed one for localhost, made at every start.
// (It only protects the channel. The clients are the ones that must prove who they are.)
// RSA, not ECDSA: it is the combination every Windows TLS stack accepts as a server certificate.
using var serverKey = RSA.Create(2048);
var serverRequest = new CertificateRequest("CN=localhost", serverKey, HashAlgorithmName.SHA256, RSASignaturePadding.Pkcs1);
var serverNames = new SubjectAlternativeNameBuilder();
serverNames.AddDnsName("localhost");
serverRequest.CertificateExtensions.Add(serverNames.Build());
using var selfSigned = serverRequest.CreateSelfSigned(DateTimeOffset.UtcNow.AddDays(-1), DateTimeOffset.UtcNow.AddDays(30));
// Exported and loaded again: Windows needs a key it can persist for TLS.
var serverCertificate = X509CertificateLoader.LoadPkcs12(selfSigned.Export(X509ContentType.Pfx), null);

// The rule. Returns why a certificate is refused, or null when it is accepted.
string? WhyRefused(X509Certificate2 certificate)
{
    using var chain = new X509Chain();
    chain.ChainPolicy.TrustMode = X509ChainTrustMode.CustomRootTrust;       // do not use the machine's trusted roots
    foreach (var root in roots) chain.ChainPolicy.CustomTrustStore.Add(root);  // trust only the ADR root
    foreach (var helper in helpers) chain.ChainPolicy.ExtraStore.Add(helper);  // the Issuing CA completes the chain
    chain.ChainPolicy.RevocationMode = X509RevocationMode.Online;           // read the CRL that ADR publishes
    chain.ChainPolicy.RevocationFlag = X509RevocationFlag.EntireChain;
    chain.ChainPolicy.UrlRetrievalTimeout = TimeSpan.FromSeconds(10);
    chain.ChainPolicy.ApplicationPolicy.Add(new Oid("1.3.6.1.5.5.7.3.2")); // extended key usage: clientAuth
    chain.Build(certificate);

    // The device certificate may only carry the tolerated status; the CAs must be clean. Revocation that cannot be
    // checked (CRL not reachable) is a refusal too: the API fails closed.
    var problems = new List<string>();
    for (var i = 0; i < chain.ChainElements.Count; i++)
    {
        var status = chain.ChainElements[i].ChainElementStatus.Aggregate(X509ChainStatusFlags.NoError, (all, s) => all | s.Status);
        if (i == 0) status &= ~ToleratedOnLeaf;
        if (status != X509ChainStatusFlags.NoError) problems.Add($"{chain.ChainElements[i].Certificate.Subject}: {status}");
    }
    if (chain.ChainElements.Count < 2) problems.Add("the chain has no issuer");

    // The tolerance is by name: any OTHER critical extension that is not a standard one is refused.
    var unknownCritical = certificate.Extensions
        .Where(e => e.Critical && e.Oid?.Value is not (BasicConstraints or KeyUsage or MicrosoftAdrExtension))
        .Select(e => e.Oid?.Value);
    foreach (var oid in unknownCritical) problems.Add($"unknown critical extension {oid}");

    return problems.Count == 0 ? null : string.Join("; ", problems);
}

bool IsIssuedByAdr(X509Certificate2 certificate)
{
    var why = WhyRefused(certificate);
    // Say why a certificate is refused: this is what you need to read when a client is turned away.
    Console.WriteLine(why is null ? $"accepted {certificate.Subject}" : $"refused {certificate.Subject}: {why}");
    return why is null;
}

var builder = WebApplication.CreateBuilder();
builder.WebHost.ConfigureKestrel(kestrel =>
    kestrel.ListenLocalhost(port, listen => listen.UseHttps(https =>
    {
        https.ServerCertificate = serverCertificate;
        https.ClientCertificateMode = ClientCertificateMode.RequireCertificate;   // no certificate, no connection
        https.ClientCertificateValidation = (certificate, chain, errors) => IsIssuedByAdr(certificate);
    })));

var app = builder.Build();

// Who am I: what the API learned from the certificate alone.
app.MapGet("/whoami", (HttpContext context) =>
{
    var certificate = context.Connection.ClientCertificate!;
    // JsonObject, not an anonymous type: a file-based app serializes without reflection.
    var answer = new JsonObject
    {
        ["deviceId"] = certificate.GetNameInfo(X509NameType.SimpleName, false),
        ["issuer"] = certificate.Issuer,
        ["thumbprint"] = certificate.Thumbprint,
        ["notAfter"] = certificate.NotAfter.ToString("yyyy-MM-dd")
    };
    return Results.Text(answer.ToJsonString(), "application/json");
});

// Telemetry: the device is identified by its certificate, so the body does not have to say who sends it.
app.MapPost("/telemetry", async (HttpContext context) =>
{
    var deviceId = context.Connection.ClientCertificate!.GetNameInfo(X509NameType.SimpleName, false);
    using var reader = new StreamReader(context.Request.Body);
    var body = await reader.ReadToEndAsync();
    Console.WriteLine($"{DateTimeOffset.UtcNow:O} {deviceId}: {body}");
    var answer = new JsonObject { ["deviceId"] = deviceId, ["bytes"] = body.Length };
    return Results.Text(answer.ToJsonString(), "application/json", null, StatusCodes.Status202Accepted);
});

Console.WriteLine($"Listening on https://localhost:{port}. Trusted root: {roots[0].Subject}");
app.Run();
return 0;
