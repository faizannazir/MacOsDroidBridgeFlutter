class ShareNote {
  const ShareNote({
    required this.author,
    required this.message,
    required this.isLocal,
    required this.timestamp,
  });

  final String author;
  final String message;
  final bool isLocal;
  final DateTime timestamp;
}
