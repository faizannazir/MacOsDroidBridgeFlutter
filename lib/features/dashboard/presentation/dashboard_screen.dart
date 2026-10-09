import 'package:droid_bridge/core/models/connection_request.dart';
import 'package:droid_bridge/core/models/discovered_device.dart';
import 'package:droid_bridge/core/models/share_note.dart';
import 'package:droid_bridge/core/models/transfer_record.dart';
import 'package:droid_bridge/core/services/feature_catalog.dart';
import 'package:droid_bridge/core/services/local_bridge_controller.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

enum ContinuityTab {
  mirroring,
  airdrop,
  clipboard,
  messages,
  devices,
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final LocalBridgeController _controller;
  ContinuityTab _selectedTab = ContinuityTab.mirroring;

  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = LocalBridgeController()..initialize();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _codeController.dispose();
    _messageController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return Column(
              children: [
                _MacTitleBar(controller: _controller),
                const Divider(height: 1, color: Color(0x1F2C2C35)),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 768;
                      if (isWide) {
                        return Row(
                          children: [
                            _Sidebar(
                              selectedTab: _selectedTab,
                              onTabSelected: (tab) {
                                setState(() => _selectedTab = tab);
                              },
                              controller: _controller,
                            ),
                            const VerticalDivider(width: 1, color: Color(0x1F2C2C35)),
                            Expanded(
                              child: _buildTabContent(_selectedTab),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          _BottomNavTabs(
                            selectedTab: _selectedTab,
                            onTabSelected: (tab) {
                              setState(() => _selectedTab = tab);
                            },
                          ),
                          const Divider(height: 1, color: Color(0x1F2C2C35)),
                          Expanded(
                            child: _buildTabContent(_selectedTab),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTabContent(ContinuityTab tab) {
    return switch (tab) {
      ContinuityTab.mirroring => _IPhoneMirroringView(controller: _controller),
      ContinuityTab.airdrop => _AirDropView(controller: _controller),
      ContinuityTab.clipboard => _UniversalClipboardView(controller: _controller),
      ContinuityTab.messages => _MessagesView(
          controller: _controller,
          messageController: _messageController,
        ),
      ContinuityTab.devices => _DevicesView(
          controller: _controller,
          hostController: _hostController,
          codeController: _codeController,
        ),
    };
  }
}

class _MacTitleBar extends StatelessWidget {
  const _MacTitleBar({required this.controller});

  final LocalBridgeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final peer = controller.connectedPeer;

    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: theme.scaffoldBackgroundColor,
      child: Row(
        children: [
          const Row(
            children: [
              _MacDot(color: Color(0xFFFF5F57)),
              SizedBox(width: 8),
              _MacDot(color: Color(0xFFFEBC2E)),
              SizedBox(width: 8),
              _MacDot(color: Color(0xFF28C840)),
            ],
          ),
          const SizedBox(width: 16),
          const Icon(CupertinoIcons.device_laptop, size: 18, color: Colors.grey),
          const SizedBox(width: 6),
          Text(
            'iPhone Continuity',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: peer != null
                    ? const Color(0xFF34C759).withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    peer != null ? CupertinoIcons.wifi : CupertinoIcons.wifi_slash,
                    size: 13,
                    color: peer != null ? const Color(0xFF34C759) : Colors.grey,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      peer != null ? 'Paired with ${peer.name}' : controller.statusLine,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: peer != null ? const Color(0xFF34C759) : Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacDot extends StatelessWidget {
  const _MacDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedTab,
    required this.onTabSelected,
    required this.controller,
  });

  final ContinuityTab selectedTab;
  final ValueChanged<ContinuityTab> onTabSelected;
  final LocalBridgeController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'CONTINUITY',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _SidebarTile(
            icon: CupertinoIcons.device_phone_portrait,
            label: 'iPhone Mirroring',
            selected: selectedTab == ContinuityTab.mirroring,
            onTap: () => onTabSelected(ContinuityTab.mirroring),
          ),
          _SidebarTile(
            icon: CupertinoIcons.share,
            label: 'AirDrop & Files',
            selected: selectedTab == ContinuityTab.airdrop,
            onTap: () => onTabSelected(ContinuityTab.airdrop),
            badgeCount: controller.transfers.length,
          ),
          _SidebarTile(
            icon: CupertinoIcons.doc_on_clipboard,
            label: 'Universal Clipboard',
            selected: selectedTab == ContinuityTab.clipboard,
            onTap: () => onTabSelected(ContinuityTab.clipboard),
          ),
          _SidebarTile(
            icon: CupertinoIcons.chat_bubble_2,
            label: 'Messages',
            selected: selectedTab == ContinuityTab.messages,
            onTap: () => onTabSelected(ContinuityTab.messages),
            badgeCount: controller.notes.length,
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              'DEVICES',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey,
                letterSpacing: 0.8,
              ),
            ),
          ),
          _SidebarTile(
            icon: CupertinoIcons.antenna_radiowaves_left_right,
            label: 'Nearby & Settings',
            selected: selectedTab == ContinuityTab.devices,
            onTap: () => onTabSelected(ContinuityTab.devices),
            badgeCount: controller.incomingConnectionRequests.length,
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  controller.localDeviceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'IP: ${controller.primaryAddress}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                const SizedBox(height: 2),
                Text(
                  'Code: ${controller.pairingCode}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF007AFF),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selectedColor = theme.colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? selectedColor.withValues(alpha: 0.15) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 18,
                  color: selected ? selectedColor : Colors.grey,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      color: selected ? selectedColor : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (badgeCount != null && badgeCount! > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: selectedColor,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$badgeCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomNavTabs extends StatelessWidget {
  const _BottomNavTabs({
    required this.selectedTab,
    required this.onTabSelected,
  });

  final ContinuityTab selectedTab;
  final ValueChanged<ContinuityTab> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButton(
            icon: const Icon(CupertinoIcons.device_phone_portrait),
            color: selectedTab == ContinuityTab.mirroring
                ? const Color(0xFF007AFF)
                : Colors.grey,
            onPressed: () => onTabSelected(ContinuityTab.mirroring),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.share),
            color: selectedTab == ContinuityTab.airdrop
                ? const Color(0xFF007AFF)
                : Colors.grey,
            onPressed: () => onTabSelected(ContinuityTab.airdrop),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.doc_on_clipboard),
            color: selectedTab == ContinuityTab.clipboard
                ? const Color(0xFF007AFF)
                : Colors.grey,
            onPressed: () => onTabSelected(ContinuityTab.clipboard),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.chat_bubble_2),
            color: selectedTab == ContinuityTab.messages
                ? const Color(0xFF007AFF)
                : Colors.grey,
            onPressed: () => onTabSelected(ContinuityTab.messages),
          ),
          IconButton(
            icon: const Icon(CupertinoIcons.antenna_radiowaves_left_right),
            color: selectedTab == ContinuityTab.devices
                ? const Color(0xFF007AFF)
                : Colors.grey,
            onPressed: () => onTabSelected(ContinuityTab.devices),
          ),
        ],
      ),
    );
  }
}

class _IPhoneMirroringView extends StatelessWidget {
  const _IPhoneMirroringView({required this.controller});

  final LocalBridgeController controller;

  @override
  Widget build(BuildContext context) {
    final status = controller.mirroringStatus;
    final isDesktop = controller.snapshot?.platformRole == 'desktop';

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(CupertinoIcons.device_phone_portrait, size: 22, color: Color(0xFF007AFF)),
                const SizedBox(width: 8),
                Text(
                  'iPhone Mirroring',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Control and view your Android phone with macOS Continuity experience.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Quick Direct USB Connect button
            FilledButton.icon(
              onPressed: controller.isConnecting ? null : controller.connectViaUsbLoopback,
              icon: const Icon(CupertinoIcons.link),
              label: const Text('Connect via USB Cable (No Wi-Fi needed)'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
              ),
            ),
            const SizedBox(height: 20),
            // Realistic iPhone Frame Mockup
            Container(
              width: 300,
              height: 580,
              decoration: BoxDecoration(
                color: const Color(0xFF101014),
                borderRadius: BorderRadius.circular(44),
                border: Border.all(
                  color: const Color(0xFF383842),
                  width: 4,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 30,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(40),
                child: Stack(
                  children: [
                    // Screen Background / Stream Canvas
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF1c2a38),
                              Color(0xFF0f171e),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (controller.isConnected) ...[
                              Icon(
                                CupertinoIcons.device_phone_portrait,
                                size: 64,
                                color: const Color(0xFF007AFF).withValues(alpha: 0.8),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                controller.connectedPeer?.name ?? 'Phone Connected',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Low-Latency Mirroring Stream Active',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF34C759),
                                ),
                              ),
                              const SizedBox(height: 24),
                              const Wrap(
                                spacing: 8,
                                children: [
                                  _AppSimTile(icon: CupertinoIcons.camera_fill, name: 'Camera'),
                                  _AppSimTile(icon: CupertinoIcons.photo_fill, name: 'Photos'),
                                  _AppSimTile(icon: CupertinoIcons.chat_bubble_fill, name: 'Messages'),
                                  _AppSimTile(icon: CupertinoIcons.gear_alt_fill, name: 'Settings'),
                                ],
                              ),
                            ] else ...[
                              const Icon(
                                CupertinoIcons.wifi_slash,
                                size: 48,
                                color: Colors.grey,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'iPhone Disconnected',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white70,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Text(
                                  'Connect via USB Cable or pair under Devices tab to begin screen mirroring.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade500,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Dynamic Island Notch at Top
                    Align(
                      alignment: Alignment.topCenter,
                      child: Container(
                        margin: const EdgeInsets.only(top: 10),
                        width: 90,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Container(
                              margin: const EdgeInsets.only(right: 12),
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF007AFF),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Status Bar Header
                    const Positioned(
                      top: 12,
                      left: 20,
                      right: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '9:41',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              Icon(CupertinoIcons.wifi, size: 12, color: Colors.white),
                              SizedBox(width: 4),
                              Icon(CupertinoIcons.battery_100, size: 14, color: Colors.white),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Home Bar Indicator at Bottom
                    Align(
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        width: 110,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Actions Row
            Wrap(
              spacing: 12,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (isDesktop) ...[
                  FilledButton.icon(
                    onPressed: controller.isBusyWithMirroring
                        ? null
                        : controller.openMirrorReceiverWindow,
                    icon: const Icon(CupertinoIcons.rectangle_expand_vertical),
                    label: const Text('Open Native Receiver Window'),
                  ),
                ] else ...[
                  FilledButton.icon(
                    onPressed: controller.isBusyWithMirroring
                        ? null
                        : controller.requestMirroringPermission,
                    icon: const Icon(CupertinoIcons.tv),
                    label: const Text('Request Screen Capture Permission'),
                  ),
                ],
                OutlinedButton.icon(
                  onPressed: controller.isBusyWithMirroring
                      ? null
                      : controller.stopMirroringSession,
                  icon: const Icon(CupertinoIcons.stop_circle),
                  label: const Text('Reset Session'),
                ),
              ],
            ),
            if (status.message.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                status.message,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _AppSimTile extends StatelessWidget {
  const _AppSimTile({required this.icon, required this.name});

  final IconData icon;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: const TextStyle(fontSize: 10, color: Colors.white70),
        ),
      ],
    );
  }
}

class _AirDropView extends StatelessWidget {
  const _AirDropView({required this.controller});

  final LocalBridgeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.share, color: Color(0xFF007AFF), size: 22),
            const SizedBox(width: 8),
            Text(
              'AirDrop & File Transfer',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Wirelessly drop files between your phone and Mac instantly on local network or direct USB.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
        const SizedBox(height: 20),
        // Drop target card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFF007AFF).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    CupertinoIcons.arrow_up_doc,
                    size: 32,
                    color: Color(0xFF007AFF),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  controller.isConnected
                      ? 'Ready to send files to ${controller.connectedPeer?.name}'
                      : 'Pair a device to enable AirDrop transfers',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: controller.isConnected ? controller.pickAndSendFile : null,
                  icon: const Icon(CupertinoIcons.plus),
                  label: const Text('Choose File to AirDrop'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Transfer History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (controller.transfers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text(
              'No recent AirDrop file transfers.',
              style: TextStyle(color: Colors.grey),
            ),
          )
        else
          for (final record in controller.transfers) ...[
            _TransferCardTile(record: record),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _TransferCardTile extends StatelessWidget {
  const _TransferCardTile({required this.record});

  final TransferRecord record;

  @override
  Widget build(BuildContext context) {
    final outgoing = record.direction == TransferDirection.outgoing;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Icon(
            outgoing ? CupertinoIcons.arrow_up_circle : CupertinoIcons.arrow_down_circle,
            color: outgoing ? const Color(0xFF007AFF) : const Color(0xFF34C759),
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.name,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.summary} • ${_formatBytes(record.sizeBytes)}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UniversalClipboardView extends StatelessWidget {
  const _UniversalClipboardView({required this.controller});

  final LocalBridgeController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.doc_on_clipboard, color: Color(0xFF007AFF), size: 22),
            const SizedBox(width: 8),
            Text(
              'Universal Clipboard',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Copy on one device, paste on another seamlessly.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Auto-Sync Clipboard',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                    Switch(
                      value: controller.autoSyncClipboard,
                      onChanged: controller.toggleAutoSyncClipboard,
                      activeTrackColor: const Color(0xFF007AFF),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0x1F2C2C35)),
                Text(
                  'Remote Clipboard Content:',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    controller.remoteClipboardText?.isNotEmpty == true
                        ? controller.remoteClipboardText!
                        : 'No clipboard text received yet.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      onPressed: controller.isConnected ? () => controller.sendClipboard() : null,
                      icon: const Icon(CupertinoIcons.arrow_right_arrow_left),
                      label: const Text('Send Local Clipboard'),
                    ),
                    OutlinedButton.icon(
                      onPressed: controller.remoteClipboardText != null
                          ? controller.applyRemoteClipboard
                          : null,
                      icon: const Icon(CupertinoIcons.doc_on_doc),
                      label: const Text('Copy to System Clipboard'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Clipboard History',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (controller.clipboardHistory.isEmpty)
          const Text('No recent clipboard items.', style: TextStyle(color: Colors.grey))
        else
          for (final item in controller.clipboardHistory) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SelectableText(
                item,
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
      ],
    );
  }
}

class _MessagesView extends StatelessWidget {
  const _MessagesView({
    required this.controller,
    required this.messageController,
  });

  final LocalBridgeController controller;
  final TextEditingController messageController;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              const Icon(CupertinoIcons.chat_bubble_2, color: Color(0xFF007AFF), size: 22),
              const SizedBox(width: 8),
              Text(
                'Continuity Messaging',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, color: Color(0x1F2C2C35)),
        Expanded(
          child: controller.notes.isEmpty
              ? const Center(
                  child: Text(
                    'No messages exchanged yet.',
                    style: TextStyle(color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  reverse: true,
                  itemCount: controller.notes.length,
                  itemBuilder: (context, index) {
                    final note = controller.notes[index];
                    return _MessageBubbleTile(note: note);
                  },
                ),
        ),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E24),
            border: Border(top: BorderSide(color: Color(0x1F2C2C35))),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: messageController,
                  decoration: const InputDecoration(
                    hintText: 'iMessage / Quick note...',
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 12),
                  ),
                  onSubmitted: (_) => _send(context),
                ),
              ),
              IconButton(
                icon: const Icon(CupertinoIcons.arrow_up_circle_fill, color: Color(0xFF007AFF), size: 30),
                onPressed: controller.isConnected ? () => _send(context) : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _send(BuildContext context) async {
    final text = messageController.text;
    if (text.trim().isEmpty) return;
    messageController.clear();
    await controller.sendNote(text);
  }
}

class _MessageBubbleTile extends StatelessWidget {
  const _MessageBubbleTile({required this.note});

  final ShareNote note;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: note.isLocal ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: note.isLocal ? const Color(0xFF007AFF) : const Color(0xFF3A3A3C),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment:
              note.isLocal ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              note.message,
              style: const TextStyle(color: Colors.white, fontSize: 13),
            ),
            const SizedBox(height: 2),
            Text(
              note.author,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.6),
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesView extends StatelessWidget {
  const _DevicesView({
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

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Icon(CupertinoIcons.antenna_radiowaves_left_right, color: Color(0xFF007AFF), size: 22),
            const SizedBox(width: 8),
            Text(
              'Nearby Devices & Connection',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'AirDrop style nearby device discovery, USB direct cable, and manual pairing.',
          style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        ),
        const SizedBox(height: 20),
        // Transport Mode Selector
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connection Transport Mode',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                SegmentedButton<TransportMode>(
                  segments: const [
                    ButtonSegment(
                      value: TransportMode.usbDirect,
                      label: Text('USB Direct'),
                      icon: Icon(CupertinoIcons.link),
                    ),
                    ButtonSegment(
                      value: TransportMode.localNetwork,
                      label: Text('Local Wi-Fi'),
                      icon: Icon(CupertinoIcons.wifi),
                    ),
                    ButtonSegment(
                      value: TransportMode.wifiP2p,
                      label: Text('Wi-Fi Direct'),
                      icon: Icon(CupertinoIcons.radiowaves_right),
                    ),
                  ],
                  selected: {controller.selectedTransportMode},
                  onSelectionChanged: (set) {
                    controller.setTransportMode(set.first);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Discovered Devices Section
        Text(
          'Discovered Nearby Devices',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (controller.discoveredDevices.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Scanning network for nearby Continuity devices...',
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          )
        else
          for (final device in controller.discoveredDevices) ...[
            _DiscoveredDeviceCard(
              device: device,
              onRequest: () => controller.sendConnectionRequest(device),
              isRequested: controller.outgoingConnectionRequestHosts.contains(device.host),
            ),
            const SizedBox(height: 8),
          ],
        const SizedBox(height: 20),
        // Incoming Requests Section
        if (controller.incomingConnectionRequests.isNotEmpty) ...[
          Text(
            'Incoming Pairing Requests',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: const Color(0xFFFEBC2E),
            ),
          ),
          const SizedBox(height: 8),
          for (final req in controller.incomingConnectionRequests) ...[
            _IncomingRequestCard(
              request: req,
              onAccept: () => controller.acceptConnectionRequest(req),
              onDecline: () => controller.declineConnectionRequest(req),
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 20),
        ],
        // Manual Pairing Section
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manual Connection',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: hostController,
                  decoration: const InputDecoration(
                    labelText: 'Device IP Address',
                    hintText: '192.168.1.15',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '6-digit Pairing Code',
                    hintText: '123456',
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 12,
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
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Feature Catalog / Continuity Readiness
        Text(
          'Continuity Capabilities',
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final feature in featureCatalog) ...[
          _FeatureStatusTile(feature: feature),
          const SizedBox(height: 6),
        ],
      ],
    );
  }
}

class _DiscoveredDeviceCard extends StatelessWidget {
  const _DiscoveredDeviceCard({
    required this.device,
    required this.onRequest,
    required this.isRequested,
  });

  final DiscoveredDevice device;
  final VoidCallback onRequest;
  final bool isRequested;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(CupertinoIcons.device_phone_portrait, size: 24, color: Color(0xFF007AFF)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  device.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  '${device.host}:${device.port}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: isRequested ? null : onRequest,
            child: Text(isRequested ? 'Requested' : 'Pair Request'),
          ),
        ],
      ),
    );
  }
}

class _IncomingRequestCard extends StatelessWidget {
  const _IncomingRequestCard({
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final ConnectionRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFEBC2E)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.deviceName,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                Text(
                  'IP: ${request.host}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: onDecline,
            child: const Text('Decline'),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: onAccept,
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }
}

class _FeatureStatusTile extends StatelessWidget {
  const _FeatureStatusTile({required this.feature});

  final dynamic feature;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(CupertinoIcons.checkmark_seal_fill, size: 16, color: Color(0xFF34C759)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
                Text(
                  feature.summary,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
