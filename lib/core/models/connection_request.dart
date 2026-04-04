class ConnectionRequest {
  const ConnectionRequest({
    required this.deviceName,
    required this.role,
    required this.host,
    required this.port,
    required this.pairingCode,
    required this.createdAt,
  });

  final String deviceName;
  final String role;
  final String host;
  final int port;
  final String pairingCode;
  final DateTime createdAt;
}
