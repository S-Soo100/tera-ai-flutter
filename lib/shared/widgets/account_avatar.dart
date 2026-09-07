import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_styles.dart';

/// 헤더 우측의 내 계정 아바타. 디자인 시스템 `Components / AccountAvatar`.
///
/// **아이콘 버튼이 아니라 사람이다.** 옆의 🔔·⚙️와 같은 크기의 IconButton으로
/// 만들면 세 번째 설정 아이콘처럼 읽힌다 — 원형 사진이라 한눈에 구분된다.
///
/// [Key] 설계상 주의 두 가지:
/// - **48px 터치 타깃을 유지하되 그림은 28px**이다. 이 헤더는 개체 이름이
///   `크랑이` → `크...`로 잘린 전력이 있는 자리라 폭이 빠듯하다.
/// - **알림 점(Red Dot)을 달지 않는다.** 바로 옆 🔔이 이미 그 역할이라,
///   점이 둘이면 어느 쪽을 봐야 하는지 매번 판단하게 된다.
class AccountAvatar extends StatelessWidget {
  const AccountAvatar({
    super.key,
    required this.onPressed,
    required this.tooltip,
    this.imageUrl,
    this.displayName,
  });

  final VoidCallback onPressed;
  final String tooltip;

  /// 프로필 사진. null이면 이니셜로 떨어진다 — **비어 있는 게 기본값**이라
  /// 폴백이 초라하면 대부분의 사용자가 그 상태를 본다.
  final String? imageUrl;

  /// 이니셜을 뽑을 이름. 비어 있으면 사람 아이콘.
  final String? displayName;

  static const double _size = 28;

  /// 표시명 첫 글자. 한글은 그대로, 영문은 대문자.
  static String? initialOf(String? name) {
    final t = name?.trim() ?? '';
    if (t.isEmpty) return null;
    return t.characters.first.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final url = imageUrl;
    final initial = initialOf(displayName);

    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 24,
        child: Padding(
          // 그림은 28이지만 눌리는 면적은 48을 채운다.
          padding: const EdgeInsets.all(AppStyles.spacing8),
          child: SizedBox(
            width: _size,
            height: _size,
            child: ClipOval(
              child: ColoredBox(
                color: scheme.surfaceContainerHighest,
                child: url != null
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        // 로딩·실패 모두 폴백으로 — 깨진 아이콘을 내지 않는다.
                        placeholder: (_, __) => _Fallback(initial: initial),
                        errorWidget: (_, __, ___) => _Fallback(initial: initial),
                      )
                    : _Fallback(initial: initial),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Fallback extends StatelessWidget {
  const _Fallback({this.initial});

  final String? initial;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (initial == null) {
      return Icon(Icons.person, size: 18, color: scheme.onSurfaceVariant);
    }
    return Center(
      child: Text(
        initial!,
        style: TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 13,
          fontWeight: FontWeight.w600,
          height: 1,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
