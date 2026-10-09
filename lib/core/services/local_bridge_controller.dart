import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:droid_bridge/core/models/connection_request.dart';
import 'package:droid_bridge/core/models/discovered_device.dart';
import 'package:droid_bridge/core/models/mirroring_status.dart';
import 'package:droid_bridge/core/models/peer_device.dart';
import 'package:droid_bridge/core/models/platform_snapshot.dart';
import 'package:droid_bridge/core/models/share_note.dart';
import 'package:droid_bridge/core/models/transfer_record.dart';
import 'package:droid_bridge/core/services/platform_bridge_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

enum TransportMode {
  usbDirect,
  localNetwork,
  wifiP2p,
}

class LocalBridgeController extends ChangeNotifier {
  LocalBridgeController({
    PlatformBridgeService? platformBridgeService,
  }) : _platformBridgeService =
            platformBridgeService ?? PlatformBridgeService();

  static const int _defaultPort = 45454;
  static const int _discoveryPort = 45455;
  static const int _usbTunnelPort = 27183;

  final PlatformBridgeService _platformBridgeService;
  final List<ShareNote> notes = <ShareNote>[];
  final List<TransferRecord> transfers = <TransferRecord>[];
  final List<String> localAddresses = <String>[];
  final List<DiscoveredDevice> discoveredDevices = <DiscoveredDevice>[];
  final List<ConnectionRequest> incomingConnectionRequests =
      <ConnectionRequest>[];
  final Set<String> outgoingConnectionRequestHosts = <String>{};
  final List<String> clipboardHistory = <String>[];

  bool _isDisposed = false;
  PlatformSnapshot? snapshot;
  HttpServer? _server;
  RawDatagramSocket? _discoverySocket;
  WebSocket? _socket;
  Timer? _discoveryAnnouncementTimer;
  Timer? _clipboardPollingTimer;

  PeerDevice? connectedPeer;
  String pairingCode = _generatePairingCode();
  String statusLine = 'Initializing Continuity Bridge...';
  String? errorMessage;
  String? remoteClipboardText;
  bool autoSyncClipboard = true;
  TransportMode selectedTransportMode = TransportMode.usbDirect;

  MirroringStatus mirroringStatus = const MirroringStatus(
    supported: false,
    mode: 'none',
    isActive: false,
    permissionGranted: false,
    message: 'Checking native Continuity mirroring support...',
  );

  bool isReady = false;
  bool isConnecting = false;
  bool isBusyWithMirroring = false;

  int get port => _defaultPort;

  String get primaryAddress =>
      localAddresses.isEmpty ? '127.0.0.1' : localAddresses.first;

  String get localDeviceName =>
      snapshot?.deviceName ?? snapshot?.platformName ?? 'This Device';

  bool get isConnected => connectedPeer != null && _socket != null;

  String get listeningEndpoint => '$primaryAddress:$port';

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Future<void> initialize() async {
    try {
      snapshot = await _platformBridgeService.loadSnapshot();
      mirroringStatus = await _platformBridgeService.loadMirroringStatus();
      await _startServer();
      await _loadLocalAddresses();
      await _startDiscovery();
      _startClipboardPoller();
      statusLine = 'Ready for Continuity (${_transportName(selectedTransportMode)})';
      isReady = true;
    } catch (error) {
      errorMessage = 'Failed to initialize bridge: $error';
      statusLine = 'Initialization warning';
      isReady = true;
    }
    notifyListeners();
  }

  void setTransportMode(TransportMode mode) {
    selectedTransportMode = mode;
    statusLine = 'Transport mode set to ${_transportName(mode)}';
    notifyListeners();
  }

  Future<void> connectViaUsbLoopback() async {
    isConnecting = true;
    errorMessage = null;
    statusLine = 'Connecting via USB direct tunnel (127.0.0.1:$_usbTunnelPort)...';
    notifyListeners();

    try {
      final socket = await WebSocket.connect(
        'ws://127.0.0.1:$_usbTunnelPort/ws?code=$pairingCode',
      ).timeout(const Duration(seconds: 5));

      _bindSocket(
        socket,
        hostOverride: '127.0.0.1 (USB Direct)',
        portOverride: _usbTunnelPort,
        remoteCodeHint: pairingCode,
      );
      statusLine = 'Connected via Direct USB Cable (No Wi-Fi needed)';
    } catch (error) {
      errorMessage = 'USB direct connection failed: $error. Ensure USB cable is attached or ADB reverse is active.';
      statusLine = 'USB connection pending';
    }

    isConnecting = false;
    notifyListeners();
  }

  Future<void> connectToPeer({
    required String host,
    required String remoteCode,
  }) async {
    final normalizedHost = host.trim();
    final normalizedCode = remoteCode.trim();

    if (normalizedHost.isEmpty || normalizedCode.isEmpty) {
      errorMessage = 'Please enter both host address and pairing code.';
      notifyListeners();
      return;
    }

    final peerAddress = _parsePeerAddress(normalizedHost);
    if (peerAddress == null) {
      errorMessage = 'Invalid device address format (e.g. 192.168.1.15).';
      notifyListeners();
      return;
    }

    isConnecting = true;
    errorMessage = null;
    statusLine = 'Connecting to ${peerAddress.host}:${peerAddress.port}...';
    notifyListeners();

    try {
      final socket = await WebSocket.connect(
        'ws://${peerAddress.host}:${peerAddress.port}/ws?code=$normalizedCode',
      ).timeout(const Duration(seconds: 8));

      _bindSocket(
        socket,
        hostOverride: peerAddress.host,
        portOverride: peerAddress.port,
        remoteCodeHint: normalizedCode,
      );
      statusLine = 'Connected via Continuity with ${peerAddress.host}';
    } catch (error) {
      errorMessage = 'Connection failed: $error';
      statusLine = 'Unable to pair';
    }

    isConnecting = false;
    notifyListeners();
  }

  Future<void> disconnect() async {
    statusLine = 'Disconnecting...';
    final socket = _socket;
    _socket = null;
    connectedPeer = null;
    notifyListeners();
    try {
      await socket?.close();
    } catch (_) {}
    statusLine = 'Ready for Continuity';
    notifyListeners();
  }

  Future<void> requestMirroringPermission() async {
    isBusyWithMirroring = true;
    errorMessage = null;
    notifyListeners();

    try {
      mirroringStatus =
          await _platformBridgeService.requestScreenCapturePermission();
      statusLine = mirroringStatus.message;
    } catch (error) {
      errorMessage = 'Screen capture permission failed: $error';
    }

    isBusyWithMirroring = false;
    notifyListeners();
  }

  Future<void> openMirrorReceiverWindow() async {
    isBusyWithMirroring = true;
    errorMessage = null;
    notifyListeners();

    try {
      mirroringStatus = await _platformBridgeService.openMirrorReceiverWindow();
      statusLine = mirroringStatus.message;
    } catch (error) {
      errorMessage = 'Receiver window request failed: $error';
    }

    isBusyWithMirroring = false;
    notifyListeners();
  }

  Future<void> stopMirroringSession() async {
    isBusyWithMirroring = true;
    errorMessage = null;
    notifyListeners();

    try {
      mirroringStatus = await _platformBridgeService.stopMirroringSession();
      statusLine = mirroringStatus.message;
    } catch (error) {
      errorMessage = 'Stop mirroring request failed: $error';
    }

    isBusyWithMirroring = false;
    notifyListeners();
  }

  void toggleAutoSyncClipboard(bool enabled) {
    autoSyncClipboard = enabled;
    statusLine = enabled ? 'Universal Clipboard auto-sync enabled' : 'Universal Clipboard manual mode';
    notifyListeners();
  }

  Future<void> sendClipboard({String? customText}) async {
    String? text = customText;
    if (text == null) {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      text = data?.text?.trim();
    }

    if (text == null || text.isEmpty) {
      errorMessage = 'Clipboard is empty.';
      notifyListeners();
      return;
    }

    if (!_canSend()) {
      return;
    }

    _sendJson(<String, Object?>{
      'type': 'clipboard',
      'text': text,
    });
    statusLine = 'Synced clipboard to peer';
    notifyListeners();
  }

  Future<void> applyRemoteClipboard() async {
    final text = remoteClipboardText;
    if (text == null || text.isEmpty) {
      errorMessage = 'No remote clipboard content available.';
      notifyListeners();
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    statusLine = 'Copied to system clipboard';
    notifyListeners();
  }

  Future<void> sendNote(String message) async {
    final normalized = message.trim();
    if (normalized.isEmpty) {
      return;
    }

    if (!_canSend()) {
      return;
    }

    final author = localDeviceName;
    notes.insert(
      0,
      ShareNote(
        author: author,
        message: normalized,
        isLocal: true,
        timestamp: DateTime.now(),
      ),
    );

    _sendJson(<String, Object?>{
      'type': 'note',
      'author': author,
      'message': normalized,
    });
    statusLine = 'Message sent';
    notifyListeners();
  }

  Future<void> pickAndSendFile() async {
    if (!_canSend()) {
      return;
    }

    XFile? file;
    try {
      file = await openFile();
    } catch (_) {
      file = null;
    }

    if (file == null) {
      return;
    }

    final peer = connectedPeer;
    if (peer == null) {
      errorMessage = 'No connected peer available for transfer.';
      notifyListeners();
      return;
    }

    try {
      final length = await file.length();
      final client = HttpClient();
      final request = await client.post(
        peer.host,
        peer.port,
        '/upload?code=${Uri.encodeQueryComponent(peer.pairingCode)}',
      );
      request.headers.contentType = ContentType.binary;
      request.headers.set('x-file-name', file.name);
      request.contentLength = length;
      await request.addStream(file.openRead());
      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();

      if (response.statusCode >= 400) {
        throw Exception(responseBody);
      }

      transfers.insert(
        0,
        TransferRecord(
          name: file.name,
          path: file.path,
          sizeBytes: length,
          direction: TransferDirection.outgoing,
          createdAt: DateTime.now(),
          summary: 'Sent via AirDrop to ${peer.name}',
        ),
      );
      statusLine = 'AirDrop sent ${file.name} successfully';
      notifyListeners();
    } catch (error) {
      errorMessage = 'File transfer failed: $error';
      statusLine = 'AirDrop transfer failed';
      notifyListeners();
    }
  }

  void useDiscoveredDevice(DiscoveredDevice device) {
    errorMessage = null;
    statusLine = 'Selected ${device.name} (${device.host})';
    notifyListeners();
  }

  Future<void> sendConnectionRequest(DiscoveredDevice device) async {
    errorMessage = null;
    outgoingConnectionRequestHosts.add(device.host);
    statusLine = 'Pairing request sent to ${device.name}...';
    notifyListeners();

    await _sendDiscoveryPayload(
      <String, Object?>{
        'type': 'connection_request',
        'deviceName': localDeviceName,
        'platformRole': snapshot?.platformRole ?? 'companion',
        'pairingCode': pairingCode,
        'port': port,
      },
      targetHost: device.host,
    );
  }

  Future<void> acceptConnectionRequest(ConnectionRequest request) async {
    incomingConnectionRequests.removeWhere(
      (entry) => entry.host == request.host,
    );
    statusLine = 'Accepted pairing with ${request.deviceName}...';
    notifyListeners();

    await _sendDiscoveryPayload(
      <String, Object?>{
        'type': 'connection_response',
        'status': 'accepted',
        'deviceName': localDeviceName,
        'platformRole': snapshot?.platformRole ?? 'companion',
        'pairingCode': pairingCode,
        'port': port,
      },
      targetHost: request.host,
    );

    await connectToPeer(
      host: '${request.host}:${request.port}',
      remoteCode: request.pairingCode,
    );
  }

  Future<void> declineConnectionRequest(ConnectionRequest request) async {
    incomingConnectionRequests.removeWhere(
      (entry) => entry.host == request.host,
    );
    statusLine = 'Declined connection request from ${request.deviceName}.';
    notifyListeners();

    await _sendDiscoveryPayload(
      <String, Object?>{
        'type': 'connection_response',
        'status': 'declined',
        'deviceName': localDeviceName,
        'platformRole': snapshot?.platformRole ?? 'companion',
      },
      targetHost: request.host,
    );
  }

  @override
  void dispose() {
    _isDisposed = true;
    _discoveryAnnouncementTimer?.cancel();
    _clipboardPollingTimer?.cancel();
    try {
      _discoverySocket?.close();
    } catch (_) {}
    unawaited(_socket?.close());
    unawaited(_server?.close(force: true));
    super.dispose();
  }

  Future<void> _startServer() async {
    try {
      _server = await HttpServer.bind(
        InternetAddress.anyIPv4,
        port,
        shared: true,
      );
      unawaited(_server!.forEach(_handleRequest));
    } catch (e) {
      errorMessage = 'Local server bind issue: $e';
    }
  }

  Future<void> _loadLocalAddresses() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      localAddresses
        ..clear()
        ..addAll(
          interfaces
              .expand((interface) => interface.addresses)
              .map((address) => address.address)
              .where((address) => !address.startsWith('169.254.')),
        );
    } catch (_) {}
  }

  Future<void> _startDiscovery() async {
    try {
      _discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
        reusePort: true,
      );
      _discoverySocket!
        ..broadcastEnabled = true
        ..readEventsEnabled = true
        ..writeEventsEnabled = false;

      _discoverySocket!.listen(
        (event) {
          if (_isDisposed || event != RawSocketEvent.read) return;
          try {
            final datagram = _discoverySocket?.receive();
            if (datagram != null) {
              _handleDiscoveryDatagram(datagram);
            }
          } catch (_) {}
        },
        onError: (_) {},
      );

      await _announcePresence();
      _discoveryAnnouncementTimer = Timer.periodic(
        const Duration(seconds: 5),
        (_) => unawaited(_announcePresence()),
      );
    } catch (_) {}
  }

  void _startClipboardPoller() {
    String? previousContent;
    _clipboardPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_isDisposed || !autoSyncClipboard || !isConnected) return;
      try {
        final data = await Clipboard.getData(Clipboard.kTextPlain);
        final current = data?.text?.trim();
        if (current != null && current.isNotEmpty && current != previousContent && current != remoteClipboardText) {
          previousContent = current;
          await sendClipboard(customText: current);
        }
      } catch (_) {}
    });
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final code =
          request.uri.queryParameters['code'] ?? request.headers.value('x-pairing-code');

      if (request.uri.path == '/ws') {
        if (code != pairingCode) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }

        final socket = await WebSocketTransformer.upgrade(request);
        final host = request.connectionInfo?.remoteAddress.address ?? 'peer';
        _bindSocket(
          socket,
          hostOverride: host,
          portOverride: port,
        );
        statusLine = 'Continuity peer connected ($host)';
        notifyListeners();
        return;
      }

      if (request.method == 'POST' && request.uri.path == '/upload') {
        if (code != pairingCode) {
          request.response.statusCode = HttpStatus.unauthorized;
          await request.response.close();
          return;
        }

        final fileName = _safeFileName(
          request.headers.value('x-file-name') ?? 'shared-file.bin',
        );
        final bytes = await request.fold<BytesBuilder>(
          BytesBuilder(copy: false),
          (builder, data) => builder..add(data),
        );
        final directory = await _receivedDirectory();
        final uniqueName = _uniqueFileName(directory.path, fileName);
        final targetFile = File('${directory.path}/$uniqueName');
        await targetFile.writeAsBytes(bytes.takeBytes(), flush: true);

        transfers.insert(
          0,
          TransferRecord(
            name: uniqueName,
            path: targetFile.path,
            sizeBytes: await targetFile.length(),
            direction: TransferDirection.incoming,
            createdAt: DateTime.now(),
            summary: 'Received via AirDrop from ${connectedPeer?.name ?? request.connectionInfo?.remoteAddress.address ?? 'peer'}',
          ),
        );
        statusLine = 'Received $uniqueName via AirDrop';
        notifyListeners();

        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'ok': true,
            'savedPath': targetFile.path,
          }),
        );
        await request.response.close();
        return;
      }

      if (request.method == 'GET' && request.uri.path == '/info') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, Object?>{
            'deviceName': localDeviceName,
            'platformRole': snapshot?.platformRole ?? 'companion',
            'pairingCode': pairingCode,
            'port': port,
          }),
        );
        await request.response.close();
        return;
      }

      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
    } catch (_) {
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  void _bindSocket(
    WebSocket socket, {
    required String hostOverride,
    required int portOverride,
    String? remoteCodeHint,
  }) {
    unawaited(_socket?.close());
    _socket = socket;
    connectedPeer = PeerDevice(
      name: 'Connected Device',
      role: 'companion',
      host: hostOverride,
      port: portOverride,
      pairingCode: remoteCodeHint ?? connectedPeer?.pairingCode ?? '',
      capabilities: const <String>[],
    );

    socket.listen(
      _onSocketData,
      onDone: () {
        _socket = null;
        connectedPeer = null;
        statusLine = 'Peer disconnected';
        notifyListeners();
      },
      onError: (Object error) {
        errorMessage = 'Socket error: $error';
        statusLine = 'Peer connection error';
        notifyListeners();
      },
    );

    _sendJson(<String, Object?>{
      'type': 'hello',
      'deviceName': localDeviceName,
      'platformRole': snapshot?.platformRole ?? 'companion',
      'pairingCode': pairingCode,
      'capabilities': snapshot?.capabilities ?? const <String>[],
    });
  }

  void _onSocketData(dynamic data) {
    try {
      final payload = jsonDecode(data as String) as Map<String, dynamic>;
      final type = payload['type'] as String? ?? '';

      switch (type) {
        case 'hello':
          final existing = connectedPeer;
          connectedPeer = PeerDevice(
            name: payload['deviceName'] as String? ?? 'Connected Device',
            role: payload['platformRole'] as String? ?? 'companion',
            host: existing?.host ?? 'peer',
            port: existing?.port ?? port,
            pairingCode: payload['pairingCode'] as String? ??
                existing?.pairingCode ??
                '',
            capabilities: (payload['capabilities'] as List<dynamic>? ?? const [])
                .map((entry) => entry.toString())
                .toList(),
          );
          statusLine = 'Connected to ${connectedPeer!.name}';
          break;
        case 'clipboard':
          final text = payload['text'] as String? ?? '';
          remoteClipboardText = text;
          if (text.isNotEmpty && !clipboardHistory.contains(text)) {
            clipboardHistory.insert(0, text);
          }
          if (autoSyncClipboard && text.isNotEmpty) {
            Clipboard.setData(ClipboardData(text: text));
            statusLine = 'Universal Clipboard auto-synced';
          } else {
            statusLine = 'New clipboard item received';
          }
          break;
        case 'note':
          notes.insert(
            0,
            ShareNote(
              author: payload['author'] as String? ?? 'Peer',
              message: payload['message'] as String? ?? '',
              isLocal: false,
              timestamp: DateTime.now(),
            ),
          );
          statusLine = 'Message received';
          break;
        default:
          statusLine = 'Received Continuity event';
      }
    } catch (error) {
      errorMessage = 'Malformed message: $error';
    }

    notifyListeners();
  }

  bool _canSend() {
    if (!isConnected || _socket == null || connectedPeer == null) {
      errorMessage = 'Pair with a device first.';
      notifyListeners();
      return false;
    }
    errorMessage = null;
    return true;
  }

  void _sendJson(Map<String, Object?> payload) {
    try {
      _socket?.add(jsonEncode(payload));
    } catch (_) {}
  }

  Future<void> _announcePresence() async {
    await _sendDiscoveryPayload(
      <String, Object?>{
        'type': 'bridge_hello',
        'deviceName': localDeviceName,
        'platformRole': snapshot?.platformRole ?? 'companion',
        'pairingCode': pairingCode,
        'port': port,
        'capabilities': snapshot?.capabilities ?? const <String>[],
      },
    );
  }

  void _handleDiscoveryDatagram(Datagram datagram) {
    try {
      final payload =
          jsonDecode(utf8.decode(datagram.data)) as Map<String, dynamic>;
      final host = datagram.address.address;
      if (localAddresses.contains(host)) {
        return;
      }
      switch (payload['type']) {
        case 'bridge_hello':
          final discoveredDevice = DiscoveredDevice(
            name: payload['deviceName'] as String? ?? 'Nearby Device',
            role: payload['platformRole'] as String? ?? 'companion',
            host: host,
            port: payload['port'] as int? ?? port,
            pairingCode: payload['pairingCode'] as String? ?? '',
            capabilities: (payload['capabilities'] as List<dynamic>? ?? const [])
                .map((entry) => entry.toString())
                .toList(),
            lastSeen: DateTime.now(),
          );

          final existingIndex = discoveredDevices.indexWhere(
            (device) => device.host == discoveredDevice.host,
          );
          if (existingIndex == -1) {
            discoveredDevices.insert(0, discoveredDevice);
          } else {
            discoveredDevices[existingIndex] = discoveredDevice;
          }

          discoveredDevices.sort(
            (left, right) => right.lastSeen.compareTo(left.lastSeen),
          );
          notifyListeners();
          break;
        case 'connection_request':
          final request = ConnectionRequest(
            deviceName: payload['deviceName'] as String? ?? 'Nearby Device',
            role: payload['platformRole'] as String? ?? 'companion',
            host: host,
            port: payload['port'] as int? ?? port,
            pairingCode: payload['pairingCode'] as String? ?? '',
            createdAt: DateTime.now(),
          );
          final existingIndex = incomingConnectionRequests.indexWhere(
            (entry) => entry.host == request.host,
          );
          if (existingIndex == -1) {
            incomingConnectionRequests.insert(0, request);
          } else {
            incomingConnectionRequests[existingIndex] = request;
          }
          statusLine = '${request.deviceName} wants to pair.';
          notifyListeners();
          break;
        case 'connection_response':
          outgoingConnectionRequestHosts.remove(host);
          final responseStatus = payload['status'] as String? ?? 'unknown';
          final responderName =
              payload['deviceName'] as String? ?? 'Nearby Device';
          if (responseStatus == 'accepted') {
            statusLine = '$responderName accepted pairing request. Connecting...';
            notifyListeners();
            unawaited(
              connectToPeer(
                host: '$host:${payload['port'] as int? ?? port}',
                remoteCode: payload['pairingCode'] as String? ?? '',
              ),
            );
          } else {
            statusLine = '$responderName declined pairing request.';
            notifyListeners();
          }
          break;
      }
    } catch (_) {}
  }

  Future<void> _sendDiscoveryPayload(
    Map<String, Object?> payload, {
    String? targetHost,
  }) async {
    final socket = _discoverySocket;
    if (socket == null) {
      return;
    }

    try {
      final bytes = utf8.encode(jsonEncode(payload));
      socket.send(
        bytes,
        targetHost == null
            ? InternetAddress('255.255.255.255')
            : InternetAddress(targetHost),
        _discoveryPort,
      );
    } catch (_) {}
  }

  Future<Directory> _receivedDirectory() async {
    final baseDirectory = await getApplicationDocumentsDirectory();
    final directory = Directory('${baseDirectory.path}/received');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  static String _generatePairingCode() {
    final random = Random.secure();
    return List<String>.generate(
      6,
      (_) => random.nextInt(10).toString(),
    ).join();
  }

  static String _safeFileName(String input) {
    return input.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }

  static _PeerAddress? _parsePeerAddress(String input) {
    final value = input.trim();
    if (value.isEmpty) {
      return null;
    }

    final parts = value.split(':');
    final host = parts[0].trim();
    if (host.isEmpty) {
      return null;
    }

    final hostRegExp = RegExp(r'^[a-zA-Z0-9\.\-_]+$');
    if (!hostRegExp.hasMatch(host)) {
      return null;
    }

    int resolvedPort = _defaultPort;
    if (parts.length > 1) {
      final parsed = int.tryParse(parts[1].trim());
      if (parsed == null || parsed <= 0) {
        return null;
      }
      resolvedPort = parsed;
    }

    return _PeerAddress(host, resolvedPort);
  }

  static String _uniqueFileName(String directoryPath, String fileName) {
    final dot = fileName.lastIndexOf('.');
    final stem = dot == -1 ? fileName : fileName.substring(0, dot);
    final extension = dot == -1 ? '' : fileName.substring(dot);
    var candidate = fileName;
    var counter = 1;

    while (File('$directoryPath/$candidate').existsSync()) {
      candidate = '${stem}_$counter$extension';
      counter += 1;
    }

    return candidate;
  }

  static String _transportName(TransportMode mode) {
    return switch (mode) {
      TransportMode.usbDirect => 'USB Direct Cable (No Wi-Fi needed)',
      TransportMode.localNetwork => 'Local Wi-Fi Network',
      TransportMode.wifiP2p => 'Wi-Fi Direct P2P',
    };
  }
}

class _PeerAddress {
  const _PeerAddress(this.host, this.port);

  final String host;
  final int port;
}
