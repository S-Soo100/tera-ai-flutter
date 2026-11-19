import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// 두 손가락으로 벌려 확대하고, 확대한 채 한 손가락으로 옮겨 보는 영상 면
/// (2026-11-19 사용자 요청 — 확대 라이브·세로 재생목록 플레이어).
///
/// - 1배 아래로는 줄지 않는다. 최대 [maxScale]배.
/// - [onSwipe]: **1배에서** 한 손가락으로 좌우로 휙 넘기면 방향(+1=다음, -1=이전)을
///   알린다. 판정은 손가락이 닿고 모두 뗄 때까지(한 번의 손짓) 기준이다 — 두
///   손가락으로 확대했다가 한 손가락을 떼고 남은 손가락을 밀어도 넘기지 않는다.
///   확대 인식기(36px)가 아니라 포인터를 직접 봐서 예전 가로 드래그와 같은 거리
///   (kTouchSlop)·속도(150px/s)로 판정한다. 바깥에서 가로 드래그를 따로 받으면
///   두 손가락 확대를 빼앗기므로 넘기기도 여기서 받는다.
/// - [onGestureLockChanged]: 두 손가락이 닿았거나 확대 중이면 true — 바깥 세로
///   스크롤을 잠가 확대·옮기기를 빼앗기지 않게 한다. 빌드·해체 중에 바뀌면
///   다음 프레임에 알린다(그때 바깥 상태를 바꾸면 트리 잠금 오류).
/// - [controller]: 바깥이 넘기면 이 위젯이 다시 만들어져도(라이브 재연결) 배율이
///   유지된다. 바깥이 만든 것은 여기서 해제하지 않는다.
/// - [doubleTapToReset]: 두 번 탭하면 1배로 돌아간다(두 번 탭에 다른 뜻이 없는
///   화면만).
class PinchZoomView extends StatefulWidget {
  const PinchZoomView({
    super.key,
    required this.child,
    this.controller,
    this.maxScale = 4,
    this.onSwipe,
    this.onGestureLockChanged,
    this.doubleTapToReset = false,
  });

  final Widget child;
  final TransformationController? controller;
  final double maxScale;
  final ValueChanged<int>? onSwipe;
  final ValueChanged<bool>? onGestureLockChanged;
  final bool doubleTapToReset;

  /// 넘기기로 보는 최소 가로 속도(px/s) — 예전 가로 드래그 판정과 같다.
  static const swipeVelocity = 150.0;

  @override
  State<PinchZoomView> createState() => PinchZoomViewState();
}

@visibleForTesting
class PinchZoomViewState extends State<PinchZoomView> {
  TransformationController? _own;
  TransformationController get _transform => widget.controller ?? _own!;

  final _pointers = <int>{};
  bool _locked = false;

  // 한 번의 손짓(첫 손가락이 닿고 모두 뗄 때까지) 동안의 기록.
  int _seqMaxPointers = 0;
  bool _seqStartedZoomed = false;
  Offset _seqStart = Offset.zero;
  VelocityTracker? _tracker;

  /// 지금 배율.
  @visibleForTesting
  double get scale => _transform.value.getMaxScaleOnAxis();

  bool get _zoomed => scale > 1.01;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) _own = TransformationController();
    _transform.addListener(_updateLock);
    // 바깥 컨트롤러가 이미 확대돼 있으면(재연결) 잠금을 다시 알린다.
    _updateLock();
  }

  @override
  void didUpdateWidget(PinchZoomView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      (oldWidget.controller ?? _own)!.removeListener(_updateLock);
      if (widget.controller == null) {
        _own ??= TransformationController();
      } else {
        _own?.dispose();
        _own = null;
      }
      _transform.addListener(_updateLock);
      _updateLock();
    }
  }

  @override
  void dispose() {
    _transform.removeListener(_updateLock);
    _own?.dispose();
    if (_locked) {
      final unlock = widget.onGestureLockChanged;
      if (unlock != null) {
        // 해체 중엔 트리가 잠겨 있어 바깥 상태를 바로 못 바꾼다.
        WidgetsBinding.instance.addPostFrameCallback((_) => unlock(false));
      }
    }
    super.dispose();
  }

  void _updateLock() {
    final locked = _pointers.length >= 2 || _zoomed;
    if (locked == _locked) return;
    _locked = locked;
    final notify = widget.onGestureLockChanged;
    if (notify == null) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      // 빌드 중 — 프레임이 끝난 뒤(마이크로태스크) 그때의 값으로 알린다. 해체된
      // 뒤에도 보낸다(바깥이 스스로 mounted를 본다) — 안 보내면 잠금이 안 풀린다.
      // 프레임 뒤 콜백(해체 시 false)보다 늦게 돌아, 재연결로 새 면이 만들어질 때
      // 옛 면의 해제가 새 면의 잠금을 덮지 않는다.
      scheduleMicrotask(() => notify(_locked));
    } else {
      notify(locked);
    }
  }

  void _reset() => _transform.value = Matrix4.identity();

  void _onDown(PointerDownEvent e) {
    if (_pointers.isEmpty) {
      _seqMaxPointers = 0;
      _seqStartedZoomed = _zoomed;
      _seqStart = e.position;
      _tracker = VelocityTracker.withKind(e.kind);
    }
    _pointers.add(e.pointer);
    if (_pointers.length > _seqMaxPointers) _seqMaxPointers = _pointers.length;
    if (_pointers.length == 1) _tracker?.addPosition(e.timeStamp, e.position);
    _updateLock();
  }

  void _onMove(PointerMoveEvent e) {
    if (_seqMaxPointers == 1) _tracker?.addPosition(e.timeStamp, e.position);
  }

  void _onUp(PointerUpEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) _maybeSwipe(e);
    _updateLock();
  }

  void _onCancel(PointerCancelEvent e) {
    _pointers.remove(e.pointer);
    if (_pointers.isEmpty) _tracker = null;
    _updateLock();
  }

  void _maybeSwipe(PointerUpEvent e) {
    final onSwipe = widget.onSwipe;
    final tracker = _tracker;
    _tracker = null;
    if (onSwipe == null || tracker == null) return;
    if (_seqMaxPointers != 1 || _seqStartedZoomed || _zoomed) return;
    tracker.addPosition(e.timeStamp, e.position);
    final dx = e.position.dx - _seqStart.dx;
    if (dx.abs() <= computeHitSlop(e.kind, null)) return;
    final v = tracker.getVelocity().pixelsPerSecond;
    if (v.dx.abs() > PinchZoomView.swipeVelocity && v.dx.abs() > v.dy.abs()) {
      onSwipe(v.dx < 0 ? 1 : -1);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget viewer = InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: widget.maxScale,
      child: widget.child,
    );
    if (widget.doubleTapToReset) {
      viewer = GestureDetector(onDoubleTap: _reset, child: viewer);
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onDown,
      onPointerMove: _onMove,
      onPointerUp: _onUp,
      onPointerCancel: _onCancel,
      child: viewer,
    );
  }
}
