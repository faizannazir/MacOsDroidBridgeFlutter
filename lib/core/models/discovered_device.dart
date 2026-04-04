class DiscoveredDevice {
  const DiscoveredDevice({
    required this.name,
    required this.role,
    required this.host,
    required this.port,
    required this.pairingCode,
    required this.capabilities,
    required this.lastSeen,
  });

  final String name;
  final String role;
  final String host;
  final int port;
  final String pairingCode;
  final List<String> capabilities;
  final DateTime lastSeen;
}
