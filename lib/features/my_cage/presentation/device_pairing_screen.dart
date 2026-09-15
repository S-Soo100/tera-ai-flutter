import 'package:flutter/material.dart';
import '../domain/pair_target_kind.dart';
import 'device_add_flow_route.dart';

/// Legacy deep link preserved; all registration paths share the same flow.
class DevicePairingScreen extends StatelessWidget {
  const DevicePairingScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const DeviceAddFlowRoute(initialKind: PairTargetKind.device);
}
