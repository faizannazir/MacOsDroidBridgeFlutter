import 'package:droid_bridge/core/models/bridge_feature.dart';
import 'package:droid_bridge/core/models/share_note.dart';
import 'package:droid_bridge/core/models/transfer_record.dart';
import 'package:droid_bridge/core/services/feature_catalog.dart';
import 'package:droid_bridge/core/services/local_bridge_controller.dart';
import 'package:flutter/material.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final LocalBridgeController _controller;
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = LocalBridgeController()..initialize();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _codeController.dispose();
    _noteController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              scheme.surface,
              const Color(0xFFE2F4EF),
              const Color(0xFFFFE1D5),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  _Hero(controller: _controller),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 980;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _ConnectionCard(
                                controller: _controller,
                                hostController: _hostController,
                                codeController: _codeController,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: _ActionsCard(
                                controller: _controller,
                                noteController: _noteController,
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _ConnectionCard(
                            controller: _controller,
                            hostController: _hostController,
                            codeController: _codeController,
                          ),
                          const SizedBox(height: 16),
                          _ActionsCard(
                            controller: _controller,
                            noteController: _noteController,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  _MirroringCard(controller: _controller),
                  const SizedBox(height: 20),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final wide = constraints.maxWidth > 980;
                      if (wide) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _SharedContentCard(controller: _controller),
                            ),
                            const SizedBox(width: 16),
                            const Expanded(child: _FeatureCardList()),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _SharedContentCard(controller: _controller),
                          const SizedBox(height: 16),
                          const _FeatureCardList(),
                        ],
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.controller});

  final LocalBridgeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _Pill(
                  label: controller.snapshot?.platformName ?? 'Loading platform',
                  color: theme.colorScheme.primary,
                ),
                _Pill(
                  label: controller.localDeviceName,
                  color: theme.colorScheme.secondary,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Droid Bridge',
              style: theme.textTheme.displaySmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -1.1,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'A working local-network companion for Android and macOS with manual pairing, clipboard sharing, quick notes, and direct file transfer.',
              style: theme.textTheme.titleMedium?.copyWith(height: 1.45),
            ),
            const SizedBox(height: 18),
            Text(
              controller.statusLine,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (controller.errorMessage case final error?)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  error,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFFB43F2B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.controller,
    required this.hostController,
    required this.codeController,
  });

  final LocalBridgeController controller;
  final TextEditingController hostController;
  final TextEditingController codeController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peer = controller.connectedPeer;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect a device',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'On the other device, open this same app. Use its IP address and pairing code here.',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 18),
            _InfoLine(label: 'Your endpoint', value: controller.listeningEndpoint),
            _InfoLine(label: 'Your code', value: controller.pairingCode),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final address in controller.localAddresses)
                  Chip(label: Text(address)),
                if (controller.localAddresses.isEmpty)
                  const Chip(label: Text('Waiting for network interface')),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: hostController,
              decoration: const InputDecoration(
                labelText: 'Peer IP address or endpoint',
                hintText: '192.168.1.22 or 192.168.1.22:45454',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Peer pairing code',
                hintText: '6 digits',
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton(
                  onPressed: controller.isConnecting
                      ? null
                      : () {
                          controller.connectToPeer(
                            host: hostController.text,
                            remoteCode: codeController.text,
                          );
                        },
                  child: Text(
                    controller.isConnecting ? 'Connecting...' : 'Connect',
                  ),
                ),
                OutlinedButton(
                  onPressed: controller.isConnected ? controller.disconnect : null,
                  child: const Text('Disconnect'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              peer == null ? 'No peer connected yet.' : 'Connected peer',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              peer == null
                  ? 'Once paired, this device can send clipboard text, short notes, and files.'
                  : '${peer.name} at ${peer.host}:${peer.port}',
            ),
            if (peer != null && peer.capabilities.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final capability in peer.capabilities)
                    Chip(label: Text(capability)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionsCard extends StatelessWidget {
  const _ActionsCard({
    required this.controller,
    required this.noteController,
  });

  final LocalBridgeController controller;
  final TextEditingController noteController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share actions',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'These actions work over the active peer session on the same local network.',
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: controller.isConnected ? controller.sendClipboard : null,
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Send clipboard'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.remoteClipboardText == null
                      ? null
                      : controller.applyRemoteClipboard,
                  icon: const Icon(Icons.content_paste_go_rounded),
                  label: const Text('Use remote clipboard'),
                ),
                OutlinedButton.icon(
                  onPressed: controller.isConnected ? controller.pickAndSendFile : null,
                  icon: const Icon(Icons.file_upload_rounded),
                  label: const Text('Send file'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            TextField(
              controller: noteController,
              minLines: 3,
              maxLines: 5,
              decoration: const InputDecoration(
                labelText: 'Quick note',
                hintText: 'Send a note, URL, or short message to the other device.',
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: controller.isConnected
                  ? () async {
                      final text = noteController.text;
                      noteController.clear();
                      await controller.sendNote(text);
                    }
                  : null,
              child: const Text('Send note'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SharedContentCard extends StatelessWidget {
  const _SharedContentCard({required this.controller});

  final LocalBridgeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Shared content',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Remote clipboard',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                controller.remoteClipboardText?.trim().isNotEmpty == true
                    ? controller.remoteClipboardText!
                    : 'Remote clipboard text will appear here.',
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Messages',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (controller.notes.isEmpty)
              const Text('No shared notes yet.')
            else
              for (final note in controller.notes.take(6)) ...[
                _NoteTile(note: note),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 12),
            Text(
              'File transfers',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            if (controller.transfers.isEmpty)
              const Text('No file transfers yet.')
            else
              for (final transfer in controller.transfers.take(8)) ...[
                _TransferTile(record: transfer),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

class _MirroringCard extends StatelessWidget {
  const _MirroringCard({required this.controller});

  final LocalBridgeController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.mirroringStatus;
    final isDesktop = controller.snapshot?.platformRole == 'desktop';
    final isPhone = controller.snapshot?.platformRole == 'phone';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mirroring bridge',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              status.message,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                  label: status.supported ? 'Native bridge ready' : 'Unsupported',
                  color: status.supported
                      ? const Color(0xFF2E7D7A)
                      : const Color(0xFFE9715F),
                ),
                _Pill(
                  label: status.mode,
                  color: const Color(0xFFDA8B27),
                ),
                _Pill(
                  label: status.permissionGranted
                      ? 'Permission granted'
                      : 'Permission pending',
                  color: const Color(0xFF4A6FA5),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (isPhone)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: controller.isBusyWithMirroring
                        ? null
                        : controller.requestMirroringPermission,
                    child: const Text('Request capture permission'),
                  ),
                  OutlinedButton(
                    onPressed: controller.isBusyWithMirroring
                        ? null
                        : controller.stopMirroringSession,
                    child: const Text('Reset mirroring state'),
                  ),
                ],
              ),
            if (isDesktop)
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton(
                    onPressed: controller.isBusyWithMirroring
                        ? null
                        : controller.openMirrorReceiverWindow,
                    child: const Text('Open receiver window'),
                  ),
                  OutlinedButton(
                    onPressed: controller.isBusyWithMirroring
                        ? null
                        : controller.stopMirroringSession,
                    child: const Text('Close receiver'),
                  ),
                ],
              ),
            if (!isPhone && !isDesktop)
              const Text(
                'Mirroring controls will appear once the platform role is known.',
              ),
          ],
        ),
      ),
    );
  }
}

class _FeatureCardList extends StatelessWidget {
  const _FeatureCardList();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'What is already real',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 12),
            for (final feature in featureCatalog) ...[
              _FeasibilityTile(feature: feature),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _FeasibilityTile extends StatelessWidget {
  const _FeasibilityTile({required this.feature});

  final BridgeFeature feature;

  @override
  Widget build(BuildContext context) {
    final status = switch (feature.status) {
      BridgeFeatureStatus.ready => ('Ready', const Color(0xFF2E7D7A)),
      BridgeFeatureStatus.prototype => ('Built next', const Color(0xFFDA8B27)),
      BridgeFeatureStatus.nativeRequired =>
        ('Native work', const Color(0xFFE9715F)),
      BridgeFeatureStatus.blocked => ('Blocked', const Color(0xFF8A5CF6)),
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  feature.title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              _Pill(label: status.$1, color: status.$2),
            ],
          ),
          const SizedBox(height: 8),
          Text(feature.summary),
        ],
      ),
    );
  }
}

class _TransferTile extends StatelessWidget {
  const _TransferTile({required this.record});

  final TransferRecord record;

  @override
  Widget build(BuildContext context) {
    final outgoing = record.direction == TransferDirection.outgoing;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            record.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 6),
          Text(record.summary),
          const SizedBox(height: 6),
          Text(
            '${outgoing ? 'Sent' : 'Saved'} at ${record.path} • ${_formatBytes(record.sizeBytes)}',
          ),
        ],
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});

  final ShareNote note;

  @override
  Widget build(BuildContext context) {
    final accent =
        note.isLocal ? Theme.of(context).colorScheme.primary : const Color(0xFFE9715F);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            note.author,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
          ),
          const SizedBox(height: 6),
          Text(note.message),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) {
    return '$bytes B';
  }
  if (bytes < 1024 * 1024) {
    return '${(bytes / 1024).toStringAsFixed(1)} KB';
  }
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
