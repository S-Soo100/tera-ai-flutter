import 'dart:isolate';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/skeleton_loading.dart';
import '../domain/lcd_photo_codec.dart';
import 'widgets/management_widgets.dart';

/// 사진 자르기 화면을 루트 Navigator에 띄우고 결과를 받는다(§3-6, D5).
/// 뒤로·닫기는 [LcdPhotoCancelled], 자르기·인코딩 실패는 [LcdPhotoUnreadable].
Future<LcdPhotoPick> showLcdPhotoCrop(
    BuildContext context, Uint8List source) async {
  final result = await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute<LcdPhotoPick>(
          builder: (_) => LcdPhotoCropScreen(source: source)));
  return result ?? const LcdPhotoCancelled();
}

/// 자르기 진행 — 사진 읽는 중 / 맞추는 중 / 자르고 인코딩하는 중.
enum _CropPhase { loading, ready, working }

final _cropPhaseProvider =
    NotifierProvider.autoDispose<_CropPhaseNotifier, _CropPhase>(
        _CropPhaseNotifier.new);

class _CropPhaseNotifier extends AutoDisposeNotifier<_CropPhase> {
  @override
  _CropPhase build() => _CropPhase.loading;

  void set(_CropPhase phase) => state = phase;
}

/// 사진 자르기(Figma 밖 — §3-6). 어두운 바탕 위 **5:4 고정 틀**, 사진을 끌고
/// 두 손가락으로 확대해 맞춘다(`crop_your_image` interactive + fixCropRect).
///
/// 공통 부품만 다른 화면과 같다: 상단 [ManagementTopBar](y62 h44, 뒤로 = 취소)와
/// 하단 플로팅 CTA x12 w369 h56 r12(안전영역 위 66). 어두운 바탕이라 헤더
/// 글자·아이콘은 밝게, CTA는 흰 면 + 검정 글자로 뒤집었다(사용자 확인 대상).
/// 틀은 본문 영역 가운데, 좌우 24 안쪽(393 기준 345×276).
class LcdPhotoCropScreen extends ConsumerStatefulWidget {
  const LcdPhotoCropScreen({super.key, required this.source});

  /// EXIF 회전을 굽고 긴 변 ≤2048로 정리된 사진([prepareLcdPhotoSource]).
  final Uint8List source;

  static const doneKey = Key('lcd_crop_done');
  static const cropKey = Key('lcd_crop_editor');

  @override
  ConsumerState<LcdPhotoCropScreen> createState() => _LcdPhotoCropScreenState();
}

class _LcdPhotoCropScreenState extends ConsumerState<LcdPhotoCropScreen> {
  final _controller = CropController();

  void _setPhase(_CropPhase phase) {
    if (mounted) ref.read(_cropPhaseProvider.notifier).set(phase);
  }

  void _done() {
    _setPhase(_CropPhase.working);
    _controller.crop();
  }

  Future<void> _onCropped(CropResult result) async {
    final navigator = Navigator.of(context);
    Uint8List? jpeg;
    if (result case CropSuccess(:final croppedImage)) {
      try {
        jpeg = await Isolate.run(() => encodeLcdPhoto(croppedImage));
      } catch (_) {
        jpeg = null;
      }
    }
    if (!mounted) return;
    navigator.pop<LcdPhotoPick>(
        jpeg == null ? const LcdPhotoUnreadable() : LcdPhotoPicked(jpeg));
  }

  /// 본문 안 가운데 5:4 틀 — 좌우(또는 위아래) 24 안쪽.
  static Rect _frameIn(Rect viewport) {
    const inset = 24.0;
    var w = viewport.width - inset * 2;
    var h = w * kLcdPhotoAspectH / kLcdPhotoAspectW;
    final maxH = viewport.height - inset * 2;
    if (h > maxH) {
      h = maxH;
      w = h * kLcdPhotoAspectW / kLcdPhotoAspectH;
    }
    return Rect.fromCenter(center: viewport.center, width: w, height: h);
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final phase = ref.watch(_cropPhaseProvider);
    final inset = MediaQuery.paddingOf(context).bottom;
    final ctaBottom = inset + 66;
    final theme = Theme.of(context);
    // 어두운 바탕 — 헤더 글자·아이콘을 밝게.
    final lightHeader = theme.copyWith(
        extensions: [glass.copyWith(textPrimary: glass.buttonForeground)]);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: glass.textPrimary,
        body: Stack(children: [
          Column(children: [
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Theme(
                  data: lightHeader,
                  child: ManagementTopBar(
                      title: 'lcd_crop_title'.tr(),
                      onBack: () => Navigator.of(context).maybePop()),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: ctaBottom + 56),
                child: AbsorbPointer(
                  absorbing: phase == _CropPhase.working,
                  child: Crop(
                    key: LcdPhotoCropScreen.cropKey,
                    image: widget.source,
                    controller: _controller,
                    aspectRatio: kLcdPhotoAspectW / kLcdPhotoAspectH,
                    interactive: true,
                    fixCropRect: true,
                    initialRectBuilder: InitialRectBuilder.withBuilder(
                        (viewport, _) => _frameIn(viewport)),
                    baseColor: glass.textPrimary,
                    maskColor: glass.textPrimary.withValues(alpha: 0.7),
                    cornerDotBuilder: (_, __) => const SizedBox.shrink(),
                    overlayBuilder: (context, _) => DecoratedBox(
                      decoration: BoxDecoration(
                          border: Border.all(
                              color: glass.buttonForeground, width: 1)),
                    ),
                    progressIndicator: LayoutBuilder(
                      builder: (context, c) {
                        final frame = _frameIn(Offset.zero & c.biggest);
                        return SkeletonLoading(
                            width: frame.width,
                            height: frame.height,
                            borderRadius: 0);
                      },
                    ),
                    onStatusChanged: (status) {
                      if (status == CropStatus.ready) {
                        _setPhase(_CropPhase.ready);
                      }
                    },
                    onCropped: _onCropped,
                  ),
                ),
              ),
            ),
          ]),
          Positioned(
            left: 12,
            right: 12,
            bottom: ctaBottom,
            child: SizedBox(
              height: 56,
              child: FilledButton(
                key: LcdPhotoCropScreen.doneKey,
                onPressed: phase == _CropPhase.ready ? _done : null,
                style: FilledButton.styleFrom(
                    backgroundColor: glass.surfaceHeader,
                    foregroundColor: glass.textPrimary,
                    disabledBackgroundColor: glass.textSecondary,
                    disabledForegroundColor: glass.textTertiary,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: managementStyle(context,
                            size: 18, weight: FontWeight.w600)
                        .copyWith(height: 28 / 18)),
                child: Text('lcd_done'.tr()),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}
