# Payload

Payload - a signed file (like a firmware) that a server publishes and a device verifies and applies (notebook 06).
Server side: Publish-Payload (holds the private signing key). Device side: Test-PayloadSignature, Get-DevicePayloadTelemetry,
Install-Payload (hold only the public key). The payloads themselves (the PowerShell text that defines Get-Telemetry) are
content of the notebook, not part of this library.
