import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../core/theme/viva_colors.dart';
import '../../../../shared/widgets/skeleton_loading.dart';
import '../../../community/presentation/widgets/community_share_prompt.dart';
import 'clip_toast.dart';
import '../../domain/clip_memo.dart';
import '../bookmark_controller.dart';
import '../clip_memo_providers.dart';
import '../clip_memo_colors.dart';

final _submissionProvider = StateProvider.autoDispose
    .family<AsyncValue<void>, Object>((ref, key) => const AsyncData(null));

/// Bookmark and memo have separate persistence. Only the two explicit dialog
/// actions add the bookmark; dismissing the prompt does not add it.
Future<void> toggleClipBookmark(
    BuildContext context, WidgetRef ref, String clipId,
    {bool canAdd = true}) async {
  final owner = ref.read(clipMemoAccountProvider);
  if (owner == null) return;
  final key = (ownerId: owner, clipId: clipId);
  final controller = ref.read(bookmarkControllerProvider(key).notifier);
  if (ref.read(bookmarkControllerProvider(key)).desired) {
    controller.setDesired(false);
    return;
  }
  if (!canAdd) return;
  var saved = false;
  await showClipMemoEditor(context, key: key, saveBookmark: () async {
    if (!context.mounted || ref.read(clipMemoAccountProvider) != owner) {
      return false;
    }
    final writer = ref.read(bookmarkControllerProvider(key).notifier);
    writer.setDesired(true);
    await writer.settled;
    if (!context.mounted || ref.read(clipMemoAccountProvider) != owner) {
      return false;
    }
    saved = ref.read(bookmarkControllerProvider(key)).persisted;
    return saved;
  });
  // Figma 1081:6803 — 북마크가 실제로 저장된 뒤에만 토스트. 메모만 고친
  // 경우(saveBookmark 없음)는 여기로 오지 않는다.
  if (saved && context.mounted && ref.read(clipMemoAccountProvider) == owner) {
    showClipToast(context, text: 'clip_bookmark_saved_toast'.tr());
    // 저장된 그 자리에서 커뮤니티 공유를 제안한다(2026-09-24).
    await offerCommunityShare(context, ref, clipId);
  }
}

Future<void> showClipMemoEditor(
  BuildContext context, {
  required ClipMemoKey key,
  Future<bool> Function()? saveBookmark,
}) async {
  if (ProviderScope.containerOf(context, listen: false)
          .read(clipMemoAccountProvider) !=
      key.ownerId) {
    return;
  }
  await showDialog<void>(
      context: context,
      builder: (_) => ClipMemoEditor(
            memoKey: key,
            saveBookmark: saveBookmark,
          ));
}

class ClipMemoEditor extends ConsumerWidget {
  const ClipMemoEditor({super.key, required this.memoKey, this.saveBookmark});
  final ClipMemoKey memoKey;
  final Future<bool> Function()? saveBookmark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(clipMemoAccountProvider, (_, account) {
      if (account != memoKey.ownerId) {
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      }
    });
    if (ref.watch(clipMemoAccountProvider) != memoKey.ownerId) {
      return const SizedBox.shrink();
    }
    final memo = ref.watch(clipMemoProvider(memoKey));
    return _MemoDialog(
        child: memo.when(
      loading: () => const SkeletonLoading(width: double.infinity, height: 250),
      error: (_, __) => Column(mainAxisSize: MainAxisSize.min, children: [
        Text('clip_memo_load_failed'.tr()),
        TextButton(
            onPressed: () => ref.invalidate(clipMemoProvider(memoKey)),
            child: Text('common_retry'.tr())),
      ]),
      data: (value) => _MemoForm(
        key: ValueKey(memoKey),
        memoKey: memoKey,
        initialMemo: value,
        saveBookmark: saveBookmark,
      ),
    ));
  }
}

class _MemoForm extends ConsumerStatefulWidget {
  const _MemoForm(
      {super.key, required this.memoKey, this.initialMemo, this.saveBookmark});
  final ClipMemoKey memoKey;
  final ClipMemo? initialMemo;
  final Future<bool> Function()? saveBookmark;
  @override
  ConsumerState<_MemoForm> createState() => _MemoFormState();
}

class _MemoFormState extends ConsumerState<_MemoForm> {
  final _submissionKey = Object();
  late final TextEditingController _text;
  @override
  void initState() {
    super.initState();
    _text = TextEditingController(text: widget.initialMemo?.text ?? '');
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit({bool skip = false}) async {
    if (ref.read(_submissionProvider(_submissionKey)).isLoading) return;
    ref.read(_submissionProvider(_submissionKey).notifier).state =
        const AsyncLoading();
    try {
      if (!skip) {
        final success = await ref
            .read(clipMemoControllerProvider(widget.memoKey).notifier)
            .save(_text.text);
        if (!success) throw StateError('Memo not saved');
      }
      if (!mounted ||
          ref.read(clipMemoAccountProvider) != widget.memoKey.ownerId) {
        return;
      }
      if (widget.saveBookmark case final save?) {
        if (!await save()) throw StateError('Bookmark not saved');
      }
      if (!mounted ||
          ref.read(clipMemoAccountProvider) != widget.memoKey.ownerId) {
        return;
      }
      Navigator.of(context).pop();
    } catch (error, stack) {
      if (mounted &&
          ref.read(clipMemoAccountProvider) == widget.memoKey.ownerId) {
        ref.read(_submissionProvider(_submissionKey).notifier).state =
            AsyncError(error, stack);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final submission = ref.watch(_submissionProvider(_submissionKey));
    ref.watch(clipMemoControllerProvider(widget.memoKey));
    final landscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final bookmark = widget.saveBookmark != null;
    return PopScope(
        canPop: !submission.isLoading,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Figma 1081:6727 — 북마크 흐름·새 메모는 '메모 추가', 기존 메모
            // 편집은 합의된 '메모 수정'.
            Text(
                (bookmark || widget.initialMemo == null
                        ? 'clip_memo_add'
                        : 'clip_memo_edit')
                    .tr(),
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontFamily: 'Pretendard',
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    height: 28 / 18,
                    letterSpacing: -.36,
                    color: glass.textPrimary)),
            SizedBox(height: landscape ? 16 : 24),
            SizedBox(
                height: landscape ? 53 : 130,
                child: TextField(
                  key: const Key('clip_memo_input'),
                  controller: _text,
                  enabled: !submission.isLoading,
                  expands: true,
                  minLines: null,
                  maxLines: null,
                  textAlignVertical: TextAlignVertical.top,
                  style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      height: 19.09375 / 16,
                      letterSpacing: -.32,
                      color: glass.textPrimary),
                  decoration: InputDecoration(
                      hintText: 'clip_memo_hint'.tr(),
                      filled: true,
                      fillColor: VivaColors.fillBack,
                      // Figma Field 297×130, 글자 x+17/y+17. 가로는
                      // OutlineInputBorder gapPadding(4)이 더해져 13으로 맞춘다
                      // (실측: 글상자 +17, 글리프 +18 = 원본 PNG).
                      contentPadding: const EdgeInsets.fromLTRB(13, 17, 13, 17),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: glass.border))),
                )),
            if (submission.hasError)
              Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('clip_memo_failed'.tr(),
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error))),
            SizedBox(height: landscape ? 16 : 24),
            ValueListenableBuilder<TextEditingValue>(
                valueListenable: _text,
                builder: (context, value, _) => _MemoButtons(
                      secondary:
                          (bookmark ? 'clip_memo_skip' : 'clip_memo_cancel')
                              .tr(),
                      primary: (bookmark
                              ? 'clip_memo_bookmark_save'
                              : 'clip_memo_save')
                          .tr(),
                      onSecondary: submission.isLoading
                          ? null
                          : () {
                              if (bookmark) {
                                _submit(skip: true);
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                      onPrimary:
                          submission.isLoading || value.text.trim().isEmpty
                              ? null
                              : _submit,
                    )),
          ],
        ));
  }
}

Future<void> deleteClipMemo(BuildContext context, ClipMemoKey key) async {
  if (ProviderScope.containerOf(context, listen: false)
          .read(clipMemoAccountProvider) !=
      key.ownerId) {
    return;
  }
  await showDialog<void>(
      context: context, builder: (_) => _DeleteMemoDialog(memoKey: key));
}

class _DeleteMemoDialog extends ConsumerWidget {
  const _DeleteMemoDialog({required this.memoKey});
  final ClipMemoKey memoKey;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(clipMemoAccountProvider, (_, account) {
      if (account != memoKey.ownerId) {
        final route = ModalRoute.of(context);
        if (route != null && route.isActive) {
          Navigator.of(context).removeRoute(route);
        }
      }
    });
    if (ref.watch(clipMemoAccountProvider) != memoKey.ownerId) {
      return const SizedBox.shrink();
    }
    final state = ref.watch(clipMemoControllerProvider(memoKey));
    return _MemoDialog(
        child: PopScope(
            canPop: !state.isLoading,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('clip_memo_delete_confirm'.tr(),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 18,
                        height: 28 / 18,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -.36,
                        color: context.glass.textPrimary)),
                if (state.hasError) Text('clip_memo_failed'.tr()),
                const SizedBox(height: 24),
                _MemoButtons(
                    secondary: 'clip_memo_cancel'.tr(),
                    primary: 'clip_memo_delete_action'.tr(),
                    onSecondary: state.isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    onPrimary: state.isLoading
                        ? null
                        : () async {
                            final success = await ref
                                .read(clipMemoControllerProvider(memoKey)
                                    .notifier)
                                .remove();
                            if (success && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          }),
              ],
            )));
  }
}

class _MemoDialog extends StatelessWidget {
  const _MemoDialog({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
        backgroundColor: context.glass.wallpaper,
        surfaceTintColor: context.glass.wallpaper,
        // 가로(1081:6962)는 키보드 위 공간이 모달(205)보다 좁아 세로 여백을
        // 없앤다. 그래도 모자라면 아래 SingleChildScrollView가 받는다.
        insetPadding: EdgeInsets.symmetric(
            horizontal: 24, vertical: size.width > size.height ? 0 : 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: size.width > size.height ? 595 : 345),
            child: SingleChildScrollView(
                padding: const EdgeInsets.all(24), child: child)));
  }
}

class _MemoButtons extends StatelessWidget {
  const _MemoButtons(
      {required this.secondary,
      required this.primary,
      this.onSecondary,
      this.onPrimary});
  final String secondary, primary;
  final VoidCallback? onSecondary, onPrimary;
  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    Widget button(String label, VoidCallback? onPressed, Color color) =>
        Expanded(
            child: FilledButton(
                onPressed: onPressed,
                style: FilledButton.styleFrom(
                    backgroundColor: color,
                    foregroundColor: ClipMemoColors.foreground,
                    // 비활성(빈 메모)은 관리 화면 버튼과 같은 회색 — 원본은
                    // 활성 상태만 그렸다.
                    disabledBackgroundColor: glass.border,
                    disabledForegroundColor: glass.textTertiary,
                    minimumSize: const Size(0, 44),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16,
                        height: 28 / 16,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.32)),
                child: Text(label, textAlign: TextAlign.center)));
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      button(secondary, onSecondary, glass.textPrimary),
      const SizedBox(width: 12),
      button(primary, onPrimary, VivaColors.mainDark),
    ]);
  }
}
