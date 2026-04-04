import 'package:droid_bridge/core/models/bridge_feature.dart';

const featureCatalog = <BridgeFeature>[
  BridgeFeature(
    title: 'Screen mirroring',
    summary: 'Possible with an Android capture service and low-latency stream.',
    status: BridgeFeatureStatus.nativeRequired,
    details:
        'Requires Android MediaProjection, an always-on foreground service, '
        'and a transport such as WebRTC. macOS can render the stream inside '
        'Flutter or a native AppKit video surface.',
  ),
  BridgeFeature(
    title: 'Clipboard sync',
    summary: 'Very realistic for a first production milestone.',
    status: BridgeFeatureStatus.prototype,
    details:
        'Needs a trusted pairing flow, encrypted local transport, and per-app '
        'permissions on both platforms. This fits Flutter well with small native hooks.',
  ),
  BridgeFeature(
    title: 'File and photo sharing',
    summary: 'Good candidate for the first polished cross-device feature.',
    status: BridgeFeatureStatus.prototype,
    details:
        'Can be built with local network discovery plus a secure transfer '
        'channel. Native macOS share-sheet support can be exposed with a method channel.',
  ),
  BridgeFeature(
    title: 'Notification relay',
    summary: 'Possible, but Android requires a Notification Listener service.',
    status: BridgeFeatureStatus.nativeRequired,
    details:
        'This needs explicit Android system permission and a clear privacy '
        'story. macOS can display mirrored notifications through native APIs.',
  ),
  BridgeFeature(
    title: 'Native macOS handoff',
    summary: 'Flutter can cooperate with AppKit, but it will not become iPhone Mirroring.',
    status: BridgeFeatureStatus.ready,
    details:
        'Method channels let the Flutter UI call native macOS code for '
        'window management, share sheets, nearby networking, and local permissions.',
  ),
  BridgeFeature(
    title: 'True system-level iPhone parity',
    summary: 'Not feasible because Apple does not expose those Continuity APIs for Android.',
    status: BridgeFeatureStatus.blocked,
    details:
        'We can build a companion experience with similar goals, but not tap '
        'into Apple-private Continuity features or make Android appear as a native iPhone peer.',
  ),
];
