enum TransferDirection {
  incoming,
  outgoing,
}

class TransferRecord {
  const TransferRecord({
    required this.name,
    required this.path,
    required this.sizeBytes,
    required this.direction,
    required this.createdAt,
    required this.summary,
  });

  final String name;
  final String path;
  final int sizeBytes;
  final TransferDirection direction;
  final DateTime createdAt;
  final String summary;
}
