import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/guide_data.dart';

final guideDataProvider = FutureProvider<GuideData>((ref) async {
  final jsonStr = await rootBundle.loadString('assets/data/guide_steps.json');
  final json = jsonDecode(jsonStr) as Map<String, dynamic>;
  return GuideData.fromJson(json);
});

final ddayProvider = Provider<int>((ref) {
  final deadline = DateTime(2026, 6, 13);
  return deadline.difference(DateTime.now()).inDays;
});
