class PeerDevice {
  const PeerDevice({
    required this.name,
    required this.role,
    required this.host,
    required this.pairingCode,
    required this.capabilities,
  });

  final String name;
  final String role;
  final String host;
  final String pairingCode;
  final List<String> capabilities;
}
