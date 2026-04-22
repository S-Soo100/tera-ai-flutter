import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer 기반 스켈레톤 위젯 공통 라이브러리.
///
/// 다크모드 대응: brightness 체크 후 색상 분기.
/// 용도:
///   - [SkeletonLoading] : 임의 크기 회색 박스
///   - [SkeletonCard]    : 카드 형태 (여러 줄 placeholder)
///   - [SkeletonListTile]: 리스트 아이템 형태 (원형 + 줄 2개)

class SkeletonLoading extends StatelessWidget {
  const SkeletonLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

/// 카드 형태 스켈레톤.
/// [lineCount]개의 텍스트 줄 placeholder를 포함.
class SkeletonCard extends StatelessWidget {
  const SkeletonCard({
    super.key,
    this.lineCount = 3,
    this.height,
  });

  final int lineCount;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 16,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 12),
            ...List.generate(lineCount - 1, (i) {
              final isLast = i == lineCount - 2;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  height: 12,
                  width: isLast
                      ? MediaQuery.sizeOf(context).width * 0.6
                      : double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// 리스트 아이템 형태 스켈레톤.
/// 왼쪽 원형 + 오른쪽 텍스트 줄 2개.
class SkeletonListTile extends StatelessWidget {
  const SkeletonListTile({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: MediaQuery.sizeOf(context).width * 0.5,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 화면 전체 로딩용: SkeletonCard 여러 개를 세로로 나열.
class SkeletonPageLoading extends StatelessWidget {
  const SkeletonPageLoading({
    super.key,
    this.cardCount = 3,
  });

  final int cardCount;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: List.generate(cardCount, (i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SkeletonCard(lineCount: i == 0 ? 4 : 3),
          );
        }),
      ),
    );
  }
}

/// 리스트 로딩용: SkeletonListTile 여러 개.
class SkeletonListLoading extends StatelessWidget {
  const SkeletonListLoading({
    super.key,
    this.itemCount = 5,
  });

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, __) => const SkeletonListTile(),
    );
  }
}
