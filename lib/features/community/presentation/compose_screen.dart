import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_styles.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../home/presentation/home_set_providers.dart';
import '../../my_pets/domain/pet.dart';
import '../../my_pets/presentation/my_pets_providers.dart';
import '../data/community_post_publisher.dart' show ClipExpiredException;
import '../domain/community_post.dart';
import 'clip_select_screen.dart' show ComposeDraft;
import 'community_providers.dart';
import 'widgets/pet_tag_row.dart';

/// 글쓰기 2단계 — 크레 자동 연결 + 캡션 + 게시(복사 업로드, 진행률).
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, required this.draft});
  final ComposeDraft draft;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _caption = TextEditingController();
  Pet? _pet;
  bool _petResolved = false;
  double? _progress; // null = 대기, 0~1 = 게시 중
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolvePet();
  }

  /// 카메라→사육장→개체 1:1 자동 연결. 세트 미구성이면 null(수동 선택 가능).
  Future<void> _resolvePet() async {
    try {
      final sets = await ref.read(enclosureSetsProvider.future);
      if (!mounted) return;
      setState(() {
        _pet = sets
            .where((s) => s.camera?.id == widget.draft.fav.cameraId)
            .map((s) => s.pet)
            .whereType<Pet>()
            .firstOrNull;
        _petResolved = true;
      });
    } catch (_) {
      // 세트 로드 실패는 자동 연결만 포기 — 수동 선택으로 계속.
      if (mounted) setState(() => _petResolved = true);
    }
  }

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _publish() async {
    setState(() {
      _progress = 0;
      _error = null;
    });
    try {
      await ref.read(communityPublisherProvider).publish(
            fav: widget.draft.fav,
            caption: _caption.text,
            pet: _pet,
            onProgress: (v) {
              if (mounted) setState(() => _progress = v);
            },
          );
      if (!mounted) return;
      await ref.read(communityFeedProvider.notifier).refresh();
      if (mounted) context.go('/community');
    } on ClipExpiredException {
      // 회신 2026-08-31 §3 — 원본 만료는 정상 케이스: 실패가 아니라 안내
      if (mounted) {
        setState(() {
          _progress = null;
          _error = 'community_clip_expired'.tr();
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _progress = null;
          _error = 'community_publish_error'.tr();
        });
      }
    }
  }

  void _changePet() {
    final pets = ref.read(petListProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(shrinkWrap: true, children: [
          for (final p in pets)
            ListTile(
              title: Text(p.name),
              subtitle: Text(petTagLabel(
                      morph: p.morph, sex: p.sex, birthDate: p.birthDate) ??
                  ''),
              onTap: () {
                Navigator.pop(ctx);
                setState(() => _pet = p);
              },
            ),
          ListTile(
            title: Text('community_pet_none'.tr()),
            onTap: () {
              Navigator.pop(ctx);
              setState(() => _pet = null);
            },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final publishing = _progress != null;
    return PopScope(
      canPop: !publishing, // 게시 중 이탈 방지
      child: Scaffold(
        appBar: AppBar(
          title: Text('community_compose_title'.tr()),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child:
                    Text('community_share_step2'.tr(), style: glass.labelCaps),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.all(AppStyles.spacing16),
          children: [
            if (_petResolved)
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: InkWell(
                  onTap: publishing ? null : _changePet,
                  child: Row(children: [
                    Expanded(
                      child: _pet == null
                          ? Text('community_pet_unlinked'.tr(),
                              style: glass.tileStatus)
                          : PetTagRow(
                              name: _pet!.name,
                              tag: petTagLabel(
                                  morph: _pet!.morph,
                                  sex: _pet!.sex,
                                  birthDate: _pet!.birthDate),
                              photoSize: 30,
                            ),
                    ),
                    Icon(Icons.chevron_right, color: glass.textTertiary),
                  ]),
                ),
              ),
            const SizedBox(height: AppStyles.spacing12),
            GlassCard(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _caption,
                enabled: !publishing,
                maxLines: 5,
                maxLength: 300,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'community_caption_hint'.tr(),
                ),
              ),
            ),
            const SizedBox(height: AppStyles.spacing8),
            Text('community_copy_note'.tr(),
                style: glass.tileStatus.copyWith(fontSize: 11)),
            if (publishing) ...[
              const SizedBox(height: AppStyles.spacing16),
              GlassCard(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 6,
                          color: glass.activeTile,
                          backgroundColor: glass.overlayFaint,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                          'community_publishing'.tr(namedArgs: {
                            'pct': '${((_progress ?? 0) * 100).round()}',
                          }),
                          style: glass.labelCaps),
                    ]),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppStyles.spacing8),
              Text(_error!,
                  style: glass.tileStatus.copyWith(color: glass.signalAlert)),
            ],
          ],
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
              onPressed: publishing ? null : _publish,
              child: Text(publishing
                  ? 'community_publishing_short'.tr()
                  : 'community_publish'.tr()),
            ),
          ),
        ),
      ),
    );
  }
}
