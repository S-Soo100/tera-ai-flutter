import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../core/theme/glass_palette.dart';
import '../../my_cage/domain/favorite_clip.dart';
import '../../my_cage/presentation/my_cage_providers.dart';

/// 글쓰기 1단계 — 즐겨찾기 클립 선택. 캡션 화면으로 전달하는 draft.
class ComposeDraft {
  const ComposeDraft(this.fav);
  final FavoriteClip fav;
}

class ClipSelectScreen extends ConsumerStatefulWidget {
  const ClipSelectScreen({super.key});

  @override
  ConsumerState<ClipSelectScreen> createState() => _ClipSelectScreenState();
}

class _ClipSelectScreenState extends ConsumerState<ClipSelectScreen> {
  String? _selectedId;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final favorites = ref.watch(favoriteClipRepositoryProvider).listAll();
    final selected = favorites.where((f) => f.clipId == _selectedId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('community_share_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('community_share_step1'.tr(), style: glass.labelCaps),
            ),
          ),
        ],
      ),
      body: favorites.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text('community_share_no_favorites'.tr(),
                    style: glass.tileStatus, textAlign: TextAlign.center),
              ),
            )
          : GridView.builder(
              padding: const EdgeInsets.all(AppStyles.spacing16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1 / 0.78,
              ),
              itemCount: favorites.length,
              itemBuilder: (context, i) {
                final fav = favorites[i];
                return _ClipTile(
                  fav: fav,
                  selected: fav.clipId == _selectedId,
                  onTap: () => setState(() => _selectedId = fav.clipId),
                );
              },
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppStyles.spacing16),
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: glass.activeTile,
              foregroundColor: glass.textOnActive,
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: selected.isEmpty
                ? null
                : () => context.push('/community-share/caption',
                    extra: ComposeDraft(selected.single)),
            child: Text('community_share_next'.tr()),
          ),
        ),
      ),
    );
  }
}

class _ClipTile extends ConsumerWidget {
  const _ClipTile(
      {required this.fav, required this.selected, required this.onTap});
  final FavoriteClip fav;
  final bool selected;
  final VoidCallback onTap;

  String _two(int v) => v.toString().padLeft(2, '0');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final glass = context.glass;
    // 썸네일 presigned URL — my_cage의 기존 provider 재사용(중복 정의 회피).
    final thumb = ref.watch(motionThumbnailProvider(fav.clipId)).valueOrNull;
    final t = fav.startedAt;
    final ts = '${t.month}/${t.day} ${_two(t.hour)}:${_two(t.minute)}';
    final s = fav.durationSec.round();
    final dur = '${s ~/ 60}:${_two(s % 60)}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? glass.activeTile : glass.border,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(fit: StackFit.expand, children: [
          if (thumb != null)
            Image.network(thumb,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: glass.overlayFaint))
          else
            ColoredBox(color: glass.overlayFaint),
          // 촬영 날짜·시각 — 시안 확정 요소
          Positioned(
            left: 6,
            bottom: 6,
            child: Text(ts,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 3)])),
          ),
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(dur,
                  style: const TextStyle(color: Colors.white, fontSize: 9)),
            ),
          ),
          if (selected)
            Center(
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: glass.activeTile),
                child: Icon(Icons.check, size: 16, color: glass.textOnActive),
              ),
            ),
        ]),
      ),
    );
  }
}
