class TestConnectionResult {
  final bool success;
  final String? detail;
  final int? elapsedMs;
  final String? frameSize;

  const TestConnectionResult({
    required this.success,
    this.detail,
    this.elapsedMs,
    this.frameSize,
  });

  factory TestConnectionResult.fromJson(Map<String, dynamic> json) {
    return TestConnectionResult(
      success: json['success'] as bool,
      detail: json['detail'] as String?,
      elapsedMs: json['elapsed_ms'] as int?,
      frameSize: json['frame_size'] as String?,
    );
  }
}
