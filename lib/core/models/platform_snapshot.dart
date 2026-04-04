class PlatformSnapshot {
  const PlatformSnapshot({
    required this.platformName,
    required this.platformRole,
    required this.deviceName,
    required this.isNativeChannelAvailable,
    required this.capabilities,
  });

  final String platformName;
  final String platformRole;
  final String deviceName;
  final bool isNativeChannelAvailable;
  final List<String> capabilities;

  factory PlatformSnapshot.fromMap(Map<Object?, Object?> data) {
    return PlatformSnapshot(
      platformName: data['platformName'] as String? ?? 'Unknown',
      platformRole: data['platformRole'] as String? ?? 'companion',
      deviceName: data['deviceName'] as String? ?? 'Unknown device',
      isNativeChannelAvailable:
          data['isNativeChannelAvailable'] as bool? ?? false,
      capabilities: (data['capabilities'] as List<Object?>? ?? const [])
          .map((entry) => entry.toString())
          .toList(),
    );
  }
}
