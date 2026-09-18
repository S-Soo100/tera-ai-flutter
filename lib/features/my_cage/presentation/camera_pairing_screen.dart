import 'package:flutter/material.dart';
import '../domain/pair_target_kind.dart';
import 'device_add_flow_route.dart';

/// Legacy camera pairing deep link uses the integrated physical BLE flow.
class CameraPairingScreen extends StatelessWidget {
  const CameraPairingScreen({super.key});
  @override
  Widget build(BuildContext context) =>
      const DeviceAddFlowRoute(initialKind: PairTargetKind.camera);
}
