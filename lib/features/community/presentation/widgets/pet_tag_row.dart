import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';

/// 크레 표기 행 — 이름 강조 + "n살 모프 여아" 꼬리표 약화 (시안 확정).
/// [photoUrl] null이면 사진 없이 이름부터.
class PetTagRow extends StatelessWidget {
  const PetTagRow({
    super.key,
    required this.name,
    this.tag,
    this.photoUrl,
    this.photoSize = 24,
  });

  final String name;
  final String? tag; // CommunityPost.petTag
  final String? photoUrl;
  final double photoSize;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Row(
      children: [
        if (photoUrl != null) ...[
          ClipOval(
            child: Image.network(
              photoUrl!,
              width: photoSize,
              height: photoSize,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SizedBox.square(
                dimension: photoSize,
                child: ColoredBox(color: glass.overlayFaint),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(name, style: glass.tileTitle.copyWith(fontSize: 13, height: 1.2)),
        if (tag != null) ...[
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              tag!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: glass.tileStatus
                  .copyWith(fontSize: 11, color: glass.textTertiary),
            ),
          ),
        ],
      ],
    );
  }
}
