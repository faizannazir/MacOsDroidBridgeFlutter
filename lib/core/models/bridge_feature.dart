enum BridgeFeatureStatus {
  ready,
  prototype,
  nativeRequired,
  blocked,
}

class BridgeFeature {
  const BridgeFeature({
    required this.title,
    required this.summary,
    required this.status,
    required this.details,
  });

  final String title;
  final String summary;
  final BridgeFeatureStatus status;
  final String details;
}
