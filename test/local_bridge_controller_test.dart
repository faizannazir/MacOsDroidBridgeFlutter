import 'package:droid_bridge/core/services/local_bridge_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalBridgeController', () {
    late LocalBridgeController controller;

    setUp(() {
      controller = LocalBridgeController();
    });

    tearDown(() {
      controller.dispose();
    });

    test('initializes with default status and safety', () async {
      expect(controller.isReady, isFalse);
      expect(controller.isConnected, isFalse);
      expect(controller.autoSyncClipboard, isTrue);
      expect(controller.selectedTransportMode, TransportMode.usbDirect);

      await controller.initialize();

      expect(controller.isReady, isTrue);
      expect(controller.statusLine, isNotEmpty);
    });

    test('updates transport mode', () {
      controller.setTransportMode(TransportMode.localNetwork);
      expect(controller.selectedTransportMode, TransportMode.localNetwork);

      controller.setTransportMode(TransportMode.wifiP2p);
      expect(controller.selectedTransportMode, TransportMode.wifiP2p);
    });

    test('validates host and pairing code on connectToPeer', () async {
      await controller.connectToPeer(host: '', remoteCode: '');
      expect(controller.errorMessage, contains('Please enter both'));

      await controller.connectToPeer(host: 'invalid host address!', remoteCode: '123456');
      expect(controller.errorMessage, contains('Invalid device address'));
    });

    test('toggles auto sync clipboard mode', () {
      controller.toggleAutoSyncClipboard(false);
      expect(controller.autoSyncClipboard, isFalse);

      controller.toggleAutoSyncClipboard(true);
      expect(controller.autoSyncClipboard, isTrue);
    });
  });
}
