import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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

  final PlatformBridgeService _platformBridgeService;
  final List<ShareNote> notes = <ShareNote>[];
  final List<TransferRecord> transfers = <TransferRecord>[];
  final List<String> localAddresses = <String>[];

  PlatformSnapshot? snapshot;
  HttpServer? _server;
  WebSocket? _socket;
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

    isConnecting = true;
    errorMessage = null;
    statusLine = 'Connecting to $normalizedHost...';
    notifyListeners();

    try {
      final socket = await WebSocket.connect(
        'ws://$normalizedHost:$port/ws?code=$normalizedCode',
      );
      _bindSocket(
        socket,
        hostOverride: normalizedHost,
        remoteCodeHint: normalizedCode,
      );
      statusLine = 'Connected to $normalizedHost';
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
        port,
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
      _bindSocket(socket, hostOverride: host);
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

  void _bindSocket(
    WebSocket socket, {
    required String hostOverride,
    String? remoteCodeHint,
  }) {
    unawaited(_socket?.close());
    _socket = socket;
    connectedPeer = PeerDevice(
      name: 'Connected peer',
      role: 'companion',
      host: hostOverride,
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
