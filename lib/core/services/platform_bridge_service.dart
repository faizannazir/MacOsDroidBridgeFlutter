import 'package:droid_bridge/core/models/mirroring_status.dart';
import 'package:droid_bridge/core/models/platform_snapshot.dart';
import 'package:flutter/services.dart';

class PlatformBridgeService {
  static const _channel = MethodChannel('droid_bridge/platform');

  Future<PlatformSnapshot> loadSnapshot() async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'getPlatformSnapshot',
    );

    if (response == null) {
      return const PlatformSnapshot(
        platformName: 'Unknown',
        platformRole: 'companion',
        deviceName: 'Unknown device',
        isNativeChannelAvailable: false,
        capabilities: <String>[],
      );
    }

    return PlatformSnapshot.fromMap(response);
  }

  Future<MirroringStatus> loadMirroringStatus() async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'getMirroringStatus',
    );

    if (response == null) {
      return const MirroringStatus(
        supported: false,
        mode: 'none',
        isActive: false,
        permissionGranted: false,
        message: 'Native mirroring bridge unavailable.',
      );
    }

    return MirroringStatus.fromMap(response);
  }

  Future<MirroringStatus> requestScreenCapturePermission() async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'requestScreenCapturePermission',
    );
    return MirroringStatus.fromMap(response ?? const <Object?, Object?>{});
  }

  Future<MirroringStatus> openMirrorReceiverWindow() async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'openMirrorReceiverWindow',
    );
    return MirroringStatus.fromMap(response ?? const <Object?, Object?>{});
  }

  Future<MirroringStatus> stopMirroringSession() async {
    final response = await _channel.invokeMapMethod<Object?, Object?>(
      'stopMirroringSession',
    );
    return MirroringStatus.fromMap(response ?? const <Object?, Object?>{});
  }
}
