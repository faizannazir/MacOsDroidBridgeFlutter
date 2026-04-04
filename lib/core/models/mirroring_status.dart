class MirroringStatus {
  const MirroringStatus({
    required this.supported,
    required this.mode,
    required this.isActive,
    required this.permissionGranted,
    required this.message,
  });

  final bool supported;
  final String mode;
  final bool isActive;
  final bool permissionGranted;
  final String message;

  factory MirroringStatus.fromMap(Map<Object?, Object?> data) {
    return MirroringStatus(
      supported: data['supported'] as bool? ?? false,
      mode: data['mode'] as String? ?? 'none',
      isActive: data['isActive'] as bool? ?? false,
      permissionGranted: data['permissionGranted'] as bool? ?? false,
      message: data['message'] as String? ?? '',
    );
  }
}
