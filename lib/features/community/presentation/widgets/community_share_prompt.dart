import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hive/hive.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/viva_check_row.dart';
import '../../../my_cage/domain/favorite_clip.dart';
import '../../../my_cage/presentation/my_cage_providers.dart';
import '../../../my_cage/presentation/widgets/management_widgets.dart';
import '../clip_select_screen.dart';

/// 북마크 저장 직후 "커뮤니티에도 공유할까요?"(2026-09-24 사용자 결정).
/// 커뮤니티 글은 북마크한 클립만 올릴 수 있으므로, 저장이 끝난 그 자리에서
/// 클립 선택 단계를 건너뛰고 캡션 화면으로 보낸다. "다시 묻지 않기"는 기기
/// 로컬(Hive `app_settings`)에만 남는다 — 계정·서버와 무관한 편의 설정.
abstract interface class CommunitySharePromptStore {
  bool get dismissed;
  Future<void> dismiss();
}

class HiveCommunitySharePromptStore implements CommunitySharePromptStore {
  static const boxName = 'app_settings';
  static const key = 'community_share_prompt_dismissed';
  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;
  @override
  bool get dismissed => _box?.get(key) == true;
  @override
  Future<void> dismiss() async => _box?.put(key, true);
}

final communitySharePromptStoreProvider =
    Provider<CommunitySharePromptStore>((ref) => HiveCommunitySharePromptStore());

/// 북마크 메타 조회 — 게시에는 로컬 mp4가 있는 [FavoriteClip]이 필요하다.
final communityShareClipLookupProvider =
    Provider<FavoriteClip? Function(String clipId)>(
        (ref) => ref.watch(favoriteClipRepositoryProvider).getMeta);

class CommunityShareChoice {
  const CommunityShareChoice({required this.share, required this.dontAskAgain});
  final bool share, dontAskAgain;
}

/// 북마크가 실제로 저장된 뒤 호출한다. 묻지 않기로 했거나 북마크 메타가 없으면
/// (저장 직후 계정 전환 등) 조용히 끝난다. [context]는 루트 내비게이터 아래.
Future<void> offerCommunityShare(
    BuildContext context, WidgetRef ref, String clipId) async {
  final store = ref.read(communitySharePromptStoreProvider);
  if (store.dismissed) return;
  final fav = ref.read(communityShareClipLookupProvider)(clipId);
  if (fav == null || !context.mounted) return;
  final choice = await showModalBottomSheet<CommunityShareChoice>(
      context: context,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CommunitySharePrompt());
  // 바깥 탭·뒤로 가기로 닫으면 답하지 않은 것 — 설정을 건드리지 않는다.
  if (choice == null) return;
  if (choice.dontAskAgain) await store.dismiss();
  if (choice.share && context.mounted) {
    context.push('/community-share/caption', extra: ComposeDraft(fav));
  }
}

class CommunitySharePrompt extends StatefulWidget {
  const CommunitySharePrompt({super.key});
  @override
  State<CommunitySharePrompt> createState() => _CommunitySharePromptState();
}

class _CommunitySharePromptState extends State<CommunitySharePrompt> {
  bool _dontAsk = false;

  void _close(bool share) => Navigator.pop(
      context, CommunityShareChoice(share: share, dontAskAgain: _dontAsk));

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return SafeArea(
        top: false,
        child: Container(
            key: const Key('community_share_prompt'),
            decoration: BoxDecoration(
                color: glass.surfaceHeader,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20))),
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                      child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: glass.border,
                              borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 20),
                  Text('community_share_prompt_title'.tr(),
                      textAlign: TextAlign.center,
                      style: managementStyle(context,
                          size: 18,
                          weight: FontWeight.w600,
                          color: glass.textPrimary)),
                  const SizedBox(height: 8),
                  Text('community_share_prompt_body'.tr(),
                      textAlign: TextAlign.center,
                      style: managementStyle(context,
                          color: glass.bodySecondary)),
                  const SizedBox(height: 20),
                  Center(
                      child: VivaCheckRow(
                          key: const Key('community_share_prompt_dont_ask'),
                          label: 'community_share_prompt_dont_ask'.tr(),
                          value: _dontAsk,
                          onChanged: (v) => setState(() => _dontAsk = v))),
                  const SizedBox(height: 20),
                  ManagementButton(
                      key: const Key('community_share_prompt_share'),
                      label: 'community_share_prompt_share'.tr(),
                      onPressed: () => _close(true)),
                  const SizedBox(height: 8),
                  TextButton(
                      key: const Key('community_share_prompt_later'),
                      onPressed: () => _close(false),
                      child: Text('community_share_prompt_later'.tr(),
                          style: managementStyle(context,
                              color: glass.textSecondary))),
                ])));
  }
}
