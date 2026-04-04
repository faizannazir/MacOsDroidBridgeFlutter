import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:droid_bridge/core/models/connection_request.dart';
import 'package:droid_bridge/core/models/discovered_device.dart';
import 'package:droid_bridge/core/models/peer_device.dart';
import 'package:droid_bridge/core/models/mirroring_status.dart';
import 'package:droid_bridge/core/models/platform_snapshot.dart';
import 'package:droid_bridge/core/models/share_note.dart';
import 'package:droid_bridge/core/models/transfer_record.dart';
import 'package:droid_bridge/core/services/platform_bridge_service.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class LocalBridgeController extends ChangeNotifier {
  LocalBridgeController({
    PlatformBridgeService? platformBridgeService,
  }) : _platformBridgeService =
            platformBridgeService ?? PlatformBridgeService();

  static const int _defaultPort = 45454;
  static const int _discoveryPort = 45455;

  final PlatformBridgeService _platformBridgeService;
  final List<ShareNote> notes = <ShareNote>[];
  final List<TransferRecord> transfers = <TransferRecord>[];
  final List<String> localAddresses = <String>[];
  final List<DiscoveredDevice> discoveredDevices = <DiscoveredDevice>[];
  final List<ConnectionRequest> incomingConnectionRequests =
      <ConnectionRequest>[];
  final Set<String> outgoingConnectionRequestHosts = <String>{};

  PlatformSnapshot? snapshot;
  HttpServer? _server;
  RawDatagramSocket? _discoverySocket;
  WebSocket? _socket;
  Timer? _discoveryAnnouncementTimer;
  PeerDevice? connectedPeer;
  String pairingCode = _generatePairingCode();
  String statusLine = 'Starting local bridge...';
  String? errorMessage;
  String? remoteClipboardText;
  MirroringStatus mirroringStatus = const MirroringStatus(
    supported: false,
    mode: 'none',
    isActive: false,
    permissionGranted: false,
    message: 'Checking native mirroring support...',
  );
  bool isReady = false;
  bool isConnecting = false;
  bool isBusyWithMirroring = false;

  int get port => _defaultPort;

  String get primaryAddress =>
      localAddresses.isEmpty ? '127.0.0.1' : localAddresses.first;

  String get localDeviceName =>
      snapshot?.deviceName ?? snapshot?.platformName ?? 'This device';

  bool get isConnected => connectedPeer != null && _socket != null;

  String get listeningEndpoint => '$primaryAddress:$port';

  Future<void> initialize() async {
    try {
      snapshot = await _platformBridgeService.loadSnapshot();
      mirroringStatus = await _platformBridgeService.loadMirroringStatus();
      await _startServer();
      await _loadLocalAddresses();
      await _startDiscovery();
      statusLine = 'Ready to pair';
      isReady = true;
    } catch (error) {
      errorMessage = 'Failed to initialize local bridge: $error';
      statusLine = 'Initialization failed';
    }
    notifyListeners();
  }

  Future<void> connectToPeer({
    required String host,
    required String remoteCode,
  }) async {
    final normalizedHost = host.trim();
    final normalizedCode = remoteCode.trim();

    if (normalizedHost.isEmpty || normalizedCode.isEmpty) {
      errorMessage = 'Enter both the peer IP address and the peer code.';
      notifyListeners();
      return;
    }

    final peerAddress = _parsePeerAddress(normalizedHost);
    if (peerAddress == null) {
      errorMessage =
          'Enter a valid peer address like 192.168.1.22 or 192.168.1.22:45454.';
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
      );
      _bindSocket(
        socket,
        hostOverride: peerAddress.host,
        portOverride: peerAddress.port,
        remoteCodeHint: normalizedCode,
      );
      statusLine = 'Connected to ${peerAddress.host}:${peerAddress.port}';
    } catch (error) {
      errorMessage = 'Connection failed: $error';
      statusLine = 'Unable to connect';
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
    await socket?.close();
    statusLine = 'Ready to pair';
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
      errorMessage = 'Unable to request screen capture permission: $error';
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
      errorMessage = 'Unable to open mirror receiver: $error';
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
      errorMessage = 'Unable to stop mirroring: $error';
    }

    isBusyWithMirroring = false;
    notifyListeners();
  }

  Future<void> sendClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text == null || text.isEmpty) {
      errorMessage = 'There is no text in the clipboard to send.';
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
    statusLine = 'Sent clipboard text';
    notifyListeners();
  }

  Future<void> applyRemoteClipboard() async {
    final text = remoteClipboardText;
    if (text == null || text.isEmpty) {
      errorMessage = 'No remote clipboard text has been received yet.';
      notifyListeners();
      return;
    }

    await Clipboard.setData(ClipboardData(text: text));
    statusLine = 'Copied remote clipboard locally';
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
    statusLine = 'Sent message';
    notifyListeners();
  }

  Future<void> pickAndSendFile() async {
    if (!_canSend()) {
      return;
    }

    final file = await openFile();
    if (file == null) {
      return;
    }

    final peer = connectedPeer;
    if (peer == null) {
      errorMessage = 'Connect to a peer before sending files.';
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
          summary: 'Sent to ${peer.name}',
        ),
      );
      statusLine = 'Sent ${file.name}';
      notifyListeners();
    } catch (error) {
      errorMessage = 'File transfer failed: $error';
      statusLine = 'File transfer failed';
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _discoveryAnnouncementTimer?.cancel();
    _discoverySocket?.close();
    unawaited(_socket?.close());
    unawaited(_server?.close(force: true));
    super.dispose();
  }

  Future<void> _startServer() async {
    _server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      port,
      shared: true,
    );
    unawaited(
      _server!.forEach(_handleRequest),
    );
  }

  Future<void> _loadLocalAddresses() async {
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
  }

  Future<void> _startDiscovery() async {
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

    _discoverySocket!.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }

      final datagram = _discoverySocket!.receive();
      if (datagram == null) {
        return;
      }

      _handleDiscoveryDatagram(datagram);
    });

    await _announcePresence();
    _discoveryAnnouncementTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => unawaited(_announcePresence()),
    );
  }

  Future<void> _handleRequest(HttpRequest request) async {
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
      statusLine = 'Peer connected from $host';
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
          summary: 'Received from ${connectedPeer?.name ?? request.connectionInfo?.remoteAddress.address ?? 'peer'}',
        ),
      );
      statusLine = 'Received $uniqueName';
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
  }

  void useDiscoveredDevice(DiscoveredDevice device) {
    errorMessage = null;
    statusLine = 'Loaded ${device.name} from nearby discovery.';
    notifyListeners();
  }

  Future<void> sendConnectionRequest(DiscoveredDevice device) async {
    errorMessage = null;
    outgoingConnectionRequestHosts.add(device.host);
    statusLine = 'Sent connection request to ${device.name}.';
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
    statusLine = 'Accepted ${request.deviceName}. Connecting...';
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
    statusLine = 'Declined ${request.deviceName}.';
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

  void _bindSocket(
    WebSocket socket, {
    required String hostOverride,
    required int portOverride,
    String? remoteCodeHint,
  }) {
    unawaited(_socket?.close());
    _socket = socket;
    connectedPeer = PeerDevice(
      name: 'Connected peer',
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
            name: payload['deviceName'] as String? ?? 'Connected peer',
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
          remoteClipboardText = payload['text'] as String? ?? '';
          statusLine = 'Received clipboard text';
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
          statusLine = 'Received message';
          break;
        default:
          statusLine = 'Received an unsupported event';
      }
    } catch (error) {
      errorMessage = 'Malformed peer message: $error';
    }

    notifyListeners();
  }

  bool _canSend() {
    if (!isConnected || _socket == null || connectedPeer == null) {
      errorMessage = 'Connect to a peer first.';
      notifyListeners();
      return false;
    }
    errorMessage = null;
    return true;
  }

  void _sendJson(Map<String, Object?> payload) {
    _socket?.add(jsonEncode(payload));
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
            name: payload['deviceName'] as String? ?? 'Nearby device',
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
            deviceName: payload['deviceName'] as String? ?? 'Nearby device',
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
          statusLine = '${request.deviceName} wants to connect.';
          notifyListeners();
          break;
        case 'connection_response':
          outgoingConnectionRequestHosts.remove(host);
          final responseStatus = payload['status'] as String? ?? 'unknown';
          final responderName =
              payload['deviceName'] as String? ?? 'Nearby device';
          if (responseStatus == 'accepted') {
            statusLine = '$responderName accepted the request. Connecting...';
            notifyListeners();
            unawaited(
              connectToPeer(
                host: '$host:${payload['port'] as int? ?? port}',
                remoteCode: payload['pairingCode'] as String? ?? '',
              ),
            );
          } else {
            statusLine = '$responderName declined the request.';
            notifyListeners();
          }
          break;
      }
    } catch (_) {
      // Ignore malformed discovery packets from the local network.
    }
  }

  Future<void> _sendDiscoveryPayload(
    Map<String, Object?> payload, {
    String? targetHost,
  }) async {
    final socket = _discoverySocket;
    if (socket == null) {
      return;
    }

    final bytes = utf8.encode(jsonEncode(payload));
    socket.send(
      bytes,
      targetHost == null
          ? InternetAddress('255.255.255.255')
          : InternetAddress(targetHost),
      _discoveryPort,
    );
  }

  Future<Directory> _receivedDirectory() async {
    final baseDirectory =
        await getApplicationDocumentsDirectory();
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

    final uri = Uri.tryParse('ws://$value');
    if (uri == null || uri.host.isEmpty) {
      return null;
    }

    final resolvedPort = uri.hasPort ? uri.port : _defaultPort;
    if (resolvedPort <= 0) {
      return null;
    }

    return _PeerAddress(uri.host, resolvedPort);
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
}

class _PeerAddress {
  const _PeerAddress(this.host, this.port);

  final String host;
  final int port;
}
