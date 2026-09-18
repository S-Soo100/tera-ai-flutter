import 'package:flutter/material.dart';
import '../../domain/pair_target_kind.dart';
import '../device_add_flow_route.dart';

/// Source-compatible entry point. WIFI_OK no longer implies account registration.
class WifiProvisioningView extends StatelessWidget {
  const WifiProvisioningView(
      {super.key,
      required this.kind,
      required this.doneSubtitleKey,
      this.onProvisioned});
  final PairTargetKind kind;
  final String doneSubtitleKey;
  final VoidCallback? onProvisioned;
  @override
  Widget build(BuildContext context) =>
      DeviceAddFlowRoute(initialKind: kind, onProvisioned: onProvisioned);
}
