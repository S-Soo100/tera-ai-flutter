import 'dart:async';
import 'dart:typed_data';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/app_styles.dart';
import '../../data/mjpeg_stream_client.dart';

// ── 내부 상태 ──────────────────────────────────────────────────────────────

sealed class _StreamState {}

class _Connecting extends _StreamState {}

class _Playing extends _StreamState {
  _Playing(this.frame);
  final Uint8List frame;
}

class _StreamError extends _StreamState {
  _StreamError(this.message);
  final String message;
}

// ── 위젯 ──────────────────────────────────────────────────────────────────

/// MJPEG 라이브 스트림을 16:9 카드로 표시하는 위젯.
///
/// - [url]이 null이면 에러 메시지를 표시한다.
/// - connecting 상태: shimmer 스켈레톤 (CircularProgressIndicator 금지)
/// - playing 상태: Image.memory(gaplessPlayback: true)
/// - error 상태: 아이콘 + 메시지 + "다시 연결" 버튼
class LiveMjpegView extends StatefulWidget {
  const LiveMjpegView({
    super.key,
    required this.url,
    this.username,
    this.password,
  });

  final String? url;
  final String? username;
  final String? password;

  @override
  State<LiveMjpegView> createState() => _LiveMjpegViewState();
}

class _LiveMjpegViewState extends State<LiveMjpegView> {
  _StreamState _state = _Connecting();
  MjpegStreamClient? _client;
  StreamSubscription<Uint8List>? _subscription;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _client?.close();
    super.dispose();
  }

  void _connect() {
    final url = widget.url;
    if (url == null || url.isEmpty) {
      setState(() => _state = _StreamError('live_view_error'.tr()));
      return;
    }

    setState(() => _state = _Connecting());

    _subscription?.cancel();
    _client?.close();

    final client = MjpegStreamClient(
      url: url,
      username: widget.username,
      password: widget.password,
    );
    _client = client;

    _subscription = client.connect().listen(
      (frame) {
        if (!mounted) return;
        setState(() => _state = _Playing(frame));
      },
      onError: (Object e) {
        if (!mounted) return;
        setState(() => _state = _StreamError(e.toString()));
      },
      onDone: () {
        if (!mounted) return;
        // 스트림이 정상 종료되면 에러로 표시
        if (_state is! _Playing) return;
        setState(() => _state = _StreamError('live_view_error'.tr()));
      },
      cancelOnError: true,
    );
  }

  void _reconnect() {
    _subscription?.cancel();
    _client?.close();
    _connect();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing16,
        vertical: AppStyles.spacing8,
      ),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyles.cardRadius),
      ),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildContent(),
            Positioned(
              top: AppStyles.spacing8,
              right: AppStyles.spacing8,
              child: _LiveBadge(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final state = _state;

    if (state is _Connecting) {
      return _ConnectingShimmer();
    }

    if (state is _Playing) {
      return Image.memory(
        state.frame,
        gaplessPlayback: true,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _ConnectingShimmer(),
      );
    }

    if (state is _StreamError) {
      return _ErrorView(
        message: 'live_view_error'.tr(),
        onReconnect: _reconnect,
      );
    }

    return const SizedBox.shrink();
  }
}

// ── 서브 위젯 ──────────────────────────────────────────────────────────────

class _ConnectingShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(color: baseColor),
    );
  }
}

class _LiveBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppStyles.spacing8,
        vertical: AppStyles.spacing4,
      ),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(AppStyles.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'live_view_title'.tr(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onReconnect});

  final String message;
  final VoidCallback onReconnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_off_outlined,
              size: 32,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppStyles.spacing8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppStyles.spacing12),
            OutlinedButton(
              onPressed: onReconnect,
              child: Text('live_view_reconnect'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
