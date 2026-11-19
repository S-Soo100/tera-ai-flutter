import 'package:flutter/widgets.dart';

/// 두 손가락으로 벌려 확대하고, 확대한 채 한 손가락으로 옮겨 보는 영상 면
/// (2026-11-19 사용자 요청 — 확대 라이브·세로 재생목록 플레이어).
///
/// - 1배 아래로는 줄지 않는다. 최대 [maxScale]배.
/// - [onSwipe]: **1배에서** 한 손가락으로 좌우로 휙 넘기면 방향(+1=다음, -1=이전)을
///   알린다. 확대 중엔 같은 손짓이 화면 옮기기라 넘기지 않는다. 바깥에서
///   가로 드래그를 따로 받으면 두 손가락 확대를 빼앗기므로 넘기기도 여기서 받는다.
/// - [onGestureLockChanged]: 두 손가락이 닿았거나 확대 중이면 true — 바깥 세로
///   스크롤을 잠가 확대·옮기기를 빼앗기지 않게 한다.
/// - [doubleTapToReset]: 두 번 탭하면 1배로 돌아간다(두 번 탭에 다른 뜻이 없는
///   화면만).
///
/// 영상이 바뀌면 바깥에서 key를 바꿔 1배로 되돌린다.
class PinchZoomView extends StatefulWidget {
  const PinchZoomView({
    super.key,
    required this.child,
    this.maxScale = 4,
    this.onSwipe,
    this.onGestureLockChanged,
    this.doubleTapToReset = false,
  });

  final Widget child;
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
  final _transform = TransformationController();
  final _pointers = <int>{};
  int _maxPointers = 0;
  bool _startedZoomed = false;
  bool _locked = false;

  /// 지금 배율.
  @visibleForTesting
  double get scale => _transform.value.getMaxScaleOnAxis();

  bool get _zoomed => scale > 1.01;

  @override
  void initState() {
    super.initState();
    _transform.addListener(_updateLock);
  }

  @override
  void dispose() {
    _transform
      ..removeListener(_updateLock)
      ..dispose();
    // 해체 중엔 트리가 잠겨 있어 바깥 상태를 바로 못 바꾼다 — 다음 프레임에 푼다.
    final unlock = widget.onGestureLockChanged;
    if (_locked && unlock != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => unlock(false));
    }
    super.dispose();
  }

  void _updateLock() {
    final locked = _pointers.length >= 2 || _zoomed;
    if (locked == _locked) return;
    _locked = locked;
    widget.onGestureLockChanged?.call(locked);
  }

  void _reset() => _transform.value = Matrix4.identity();

  @override
  Widget build(BuildContext context) {
    Widget viewer = InteractiveViewer(
      transformationController: _transform,
      minScale: 1,
      maxScale: widget.maxScale,
      onInteractionStart: (d) {
        _maxPointers = d.pointerCount;
        _startedZoomed = _zoomed;
      },
      onInteractionUpdate: (d) {
        if (d.pointerCount > _maxPointers) _maxPointers = d.pointerCount;
      },
      onInteractionEnd: (d) {
        final onSwipe = widget.onSwipe;
        if (onSwipe == null || _maxPointers != 1) return;
        if (_startedZoomed || _zoomed) return;
        final v = d.velocity.pixelsPerSecond;
        if (v.dx.abs() > PinchZoomView.swipeVelocity &&
            v.dx.abs() > v.dy.abs()) {
          onSwipe(v.dx < 0 ? 1 : -1);
        }
      },
      child: widget.child,
    );
    if (widget.doubleTapToReset) {
      viewer = GestureDetector(onDoubleTap: _reset, child: viewer);
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _pointers.add(e.pointer);
        _updateLock();
      },
      onPointerUp: (e) {
        _pointers.remove(e.pointer);
        _updateLock();
      },
      onPointerCancel: (e) {
        _pointers.remove(e.pointer);
        _updateLock();
      },
      child: viewer,
    );
  }
}
