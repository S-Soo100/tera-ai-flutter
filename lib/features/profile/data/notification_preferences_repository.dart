import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

/// 알림 설정(Figma PushAlarm 1142:9613) — 종류별 on/off + 수신 동의.
///
/// **저장처는 아직 로컬(Hive)이다**(2026-09-16 계획 C4 "저장처 결정 필요").
/// 서버 `notification_preferences` 테이블과 `dispatch-push`의 사전 조회는
/// 앱 팀 마이그레이션·서버 배포 뒤에 붙는다 — 그때까지 이 값은 기기 안에서만
/// 유지되고 발송을 막지 못한다(RESULTS §C4). [marketingAgreedAt]은 광고성
/// 정보 수신 동의 기록이라 켤 때마다 시각을 남긴다.
class NotificationPrefs {
  const NotificationPrefs({
    this.highlight = true,
    this.comment = true,
    this.like = true,
    this.news = true,
    this.marketing = false,
    this.marketingAgreedAt,
  });

  final bool highlight;
  final bool comment;
  final bool like;
  final bool news;
  final bool marketing;
  final DateTime? marketingAgreedAt;

  NotificationPrefs copyWith({
    bool? highlight,
    bool? comment,
    bool? like,
    bool? news,
    bool? marketing,
    DateTime? marketingAgreedAt,
    bool clearAgreedAt = false,
  }) =>
      NotificationPrefs(
        highlight: highlight ?? this.highlight,
        comment: comment ?? this.comment,
        like: like ?? this.like,
        news: news ?? this.news,
        marketing: marketing ?? this.marketing,
        marketingAgreedAt: clearAgreedAt
            ? null
            : (marketingAgreedAt ?? this.marketingAgreedAt),
      );
}

abstract class NotificationPreferencesRepository {
  NotificationPrefs load();
  Future<void> save(NotificationPrefs prefs);
}

/// Hive `app_settings` 박스, 키 `notif_pref_*`. 박스가 안 열려 있으면(테스트)
/// 기본값으로 동작하고 저장은 건너뛴다.
class HiveNotificationPreferencesRepository
    implements NotificationPreferencesRepository {
  const HiveNotificationPreferencesRepository();
  static const boxName = 'app_settings';
  Box<dynamic>? get _box => Hive.isBoxOpen(boxName) ? Hive.box(boxName) : null;

  @override
  NotificationPrefs load() {
    final b = _box;
    if (b == null) return const NotificationPrefs();
    bool flag(String k, bool d) => (b.get('notif_pref_$k') as bool?) ?? d;
    final agreed = b.get('notif_pref_marketing_agreed_at') as String?;
    return NotificationPrefs(
      highlight: flag('highlight', true),
      comment: flag('comment', true),
      like: flag('like', true),
      news: flag('news', true),
      marketing: flag('marketing', false),
      marketingAgreedAt: agreed == null ? null : DateTime.tryParse(agreed),
    );
  }

  @override
  Future<void> save(NotificationPrefs p) async {
    final b = _box;
    if (b == null) return;
    await b.putAll({
      'notif_pref_highlight': p.highlight,
      'notif_pref_comment': p.comment,
      'notif_pref_like': p.like,
      'notif_pref_news': p.news,
      'notif_pref_marketing': p.marketing,
      'notif_pref_marketing_agreed_at': p.marketingAgreedAt?.toIso8601String(),
    });
  }
}

final notificationPreferencesRepositoryProvider =
    Provider<NotificationPreferencesRepository>(
        (ref) => const HiveNotificationPreferencesRepository());

final notificationPrefsProvider =
    NotifierProvider<NotificationPrefsNotifier, NotificationPrefs>(
        NotificationPrefsNotifier.new);

class NotificationPrefsNotifier extends Notifier<NotificationPrefs> {
  @override
  NotificationPrefs build() =>
      ref.watch(notificationPreferencesRepositoryProvider).load();

  Future<void> update(NotificationPrefs next) async {
    state = next;
    await ref.read(notificationPreferencesRepositoryProvider).save(next);
  }

  Future<void> setMarketing(bool on) => update(on
      ? state.copyWith(marketing: true, marketingAgreedAt: DateTime.now())
      : state.copyWith(marketing: false, clearAgreedAt: true));
}
