# 커뮤니티 클립 공유 피드 Implementation Plan

> **구현 방식 (CAOF):** Critical 트랙 — 이 계획을 task 단위로 구현한다. Implementer는 flutter-dev(GATE 4), 마이그레이션(Task 0)은 메인이 Supabase MCP로 직접 실행. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 커뮤니티 탭을 "즐겨찾기한 크레캠 클립을 공유하는 영상 피드"(피드·글쓰기·재생·좋아요·댓글 + 2차: 공지·신고·차단·모아보기)로 재구축한다.

**Architecture:** 클립 공유는 **스냅샷 복사** — 게시 시 앱이 영상(즐겨찾기 로컬 mp4)·썸네일(terra-api presigned)·크레 사진을 Supabase Storage `community-media`에 복사하고, `community_posts`는 복사본과 크레 스냅샷(name/morph/sex/birth_date)을 담는다. 작성자 표시는 `public_profiles` 뷰(별도 fetch 후 클라 병합 — PostgREST가 auth.users 경유 FK를 embed 못 하므로). 카운트는 embedded count, 내 좋아요는 별도 IN 쿼리.

**Tech Stack:** Flutter + Riverpod(AsyncNotifier) + supabase_flutter(직결 + Storage signed URL) + video_player + uuid + 기존 GlassPalette/GlassCard 문법.

**전제:**
- 스키마·RLS·버킷 DDL 원문: `docs/backend-handoff-2026-08-29-community-clip-feed.md` §3 (**SOT**). 백엔드 회신(§5 4건) 후 Task 0 실행.
- 확정 시안: https://claude.ai/code/artifact/540690a7-e2ab-4c02-a4ef-d0c1ea76d80b (2026-08-29 사용자 확정)
- 회신 전에 시작 가능한 것: **Task 1**(순수 모델·표기 함수)은 DB 없이 진행 가능. Task 2부터는 Task 0 선행.

**File Structure (신규/수정 지도):**

```
lib/features/community/
├── data/
│   ├── community_repository.dart        # 재작성 — Supabase 직결 CRUD
│   └── community_post_publisher.dart    # 신규 — 게시 파이프라인(복사 업로드)
├── domain/
│   ├── community_post.dart              # 재작성 — 새 스키마 모델 + petTagLabel
│   └── community_comment.dart           # 신규
└── presentation/
    ├── community_providers.dart         # 재작성 — feed/comments/compose
    ├── community_screen.dart            # 재작성 — 피드
    ├── community_player_screen.dart     # 신규 — 전체화면 가로 재생
    ├── clip_select_screen.dart          # 신규 — 글쓰기 1단계
    ├── compose_screen.dart              # 신규 — 글쓰기 2단계
    └── widgets/
        ├── post_card.dart               # 신규
        ├── pet_tag_row.dart             # 신규 — 이름 강조 + 꼬리표 약화
        └── comments_sheet.dart          # 신규
수정: lib/core/router/app_router.dart · assets/l10n/ko.json
     lib/features/my_cage/data/favorite_clip_repository.dart (listAll 추가)
     lib/features/my_cage/data/motion_clip_repository.dart (labelFor 공개 메서드)
테스트: test/features/community/{community_post_test,pet_tag_label_test,community_feed_merge_test}.dart
```

---

## Phase 0 — 마이그레이션

### Task 0: Supabase 마이그레이션 실행

**Context:**
- Depends on: 백엔드 회신 (§5-① 네임스페이스, §5-② R2 egress 최소 2건 OK)
- Inputs: `docs/backend-handoff-2026-08-29-community-clip-feed.md` §3.1~§3.5 DDL 전문
- Outputs: `community_posts/comments/likes/notices/reports/blocks` 6테이블 + `public_profiles` 뷰 + `community_is_admin()` 함수 + `community-media` 버킷 + `user_profiles.is_admin`
- Must know: **공유 프로덕션 DB. 사용자 최종 승인 후 실행.** 마이그레이션은 §3.1→§3.2→§3.3→§3.4→§3.5 순서 그대로 하나의 migration으로 적용(§3.3의 정책이 §3.1 is_admin·§3.2 테이블을 참조). 버킷 INSERT는 이미 있으면 duplicate key — 실패 시 buckets 조회로 선확인.
- Acceptance: `mcp__supabase__list_tables`에 community_* 6종 표시. 앱 계정으로 `select * from community_posts limit 1` → 빈 결과(에러 아님). `select community_is_admin()` → false.

- [ ] **Step 1:** 핸드오프 문서 §3 SQL 전문을 `mcp__supabase__apply_migration`(name: `community_clip_feed`)으로 적용
- [ ] **Step 2:** 검증 쿼리 3종 실행 (Acceptance 항목) + `mcp__supabase__get_advisors`로 lint 확인 — `public_profiles` SECURITY DEFINER 경고는 **의도된 설계**(핸드오프 §3.4)라 무시 기록
- [ ] **Step 3:** `docs/supabase-schema.md`에 community 섹션 추가 커밋

```bash
git add docs/supabase-schema.md
git commit -m "docs: supabase-schema에 community_* 6테이블·뷰·버킷 반영"
```

---

## Phase 1 — MVP (피드 · 글쓰기 · 재생 · 좋아요 · 댓글 · 삭제)

### Task 1: 도메인 모델 + 크레 감성 표기 함수 (TDD)

**Context:**
- Depends on: 없음 (DB 불필요 — **회신 대기 중에도 진행 가능**)
- Inputs: 확정 시안의 표기 규칙 — 이름 강조 + "n살 모프 여아·남아·아가" 약화 표기. `pets.sex`('male'/'female'/'unknown')·`birth_date` 스냅샷
- Outputs: `CommunityPost`·`CommunityComment` 모델, `petTagLabel()` 순수 함수, `embeddedCount()` 헬퍼
- Must know: 기존 `community_post.dart`의 `CommunityCategory` enum·구 `CommunityPost`는 **삭제**한다(소비처는 community_screen/providers/repository뿐 — 전부 이번에 재작성). 날짜 파싱은 `shared/domain/num_format.dart`의 `parseLocalDateTime` 재사용(UTC→로컬, 타임라인 9시간 오차의 교훈). embedded count는 `[{count: n}]` 형태로 온다.
- Acceptance: `flutter test test/features/community/ -r compact` 전부 PASS, `flutter analyze` 에러 0

**Files:**
- Create: `test/features/community/pet_tag_label_test.dart`, `test/features/community/community_post_test.dart`
- Modify(재작성): `lib/features/community/domain/community_post.dart`
- Create: `lib/features/community/domain/community_comment.dart`

- [ ] **Step 1: 실패 테스트 작성 — petTagLabel**

```dart
// test/features/community/pet_tag_label_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/community/domain/community_post.dart';

void main() {
  final now = DateTime(2026, 8, 29);

  test('만 나이 + 모프 + 성별', () {
    expect(
      petTagLabel(morph: '릴리화이트', sex: 'female',
          birthDate: DateTime(2024, 5, 1), now: now),
      '2살 릴리화이트 여아',
    );
  });
  test('1살 미만은 개월 표기', () {
    expect(
      petTagLabel(morph: '달마시안', sex: 'male',
          birthDate: DateTime(2026, 3, 10), now: now),
      '5개월 달마시안 남아',
    );
  });
  test('성별 미구분은 아가', () {
    expect(petTagLabel(morph: '달마시안', sex: 'unknown',
            birthDate: DateTime(2025, 8, 1), now: now),
        '1살 달마시안 아가');
  });
  test('birthDate 없으면 나이 생략', () {
    expect(petTagLabel(morph: '릴리화이트', sex: 'female', now: now),
        '릴리화이트 여아');
  });
  test('모프 없으면 건너뛴다', () {
    expect(petTagLabel(sex: 'female',
            birthDate: DateTime(2024, 5, 1), now: now),
        '2살 여아');
  });
  test('전부 없으면 null', () {
    expect(petTagLabel(now: now), isNull);
    expect(petTagLabel(sex: null, now: now), isNull);
  });
  test('생후 0개월(당월)은 나이 생략', () {
    expect(petTagLabel(sex: 'unknown',
            birthDate: DateTime(2026, 8, 20), now: now),
        '아가');
  });
}
```

- [ ] **Step 2:** `flutter test test/features/community/pet_tag_label_test.dart` → FAIL (petTagLabel 미정의)

- [ ] **Step 3: 모델 + 함수 구현**

```dart
// lib/features/community/domain/community_post.dart  (전면 재작성)
import '../../../shared/domain/num_format.dart';

/// "n살 모프 여아·남아·아가" 감성 표기 (시안 확정 2026-08-29).
/// 빈 조각은 건너뛰고 이어 붙인다. 조각이 하나도 없으면 null.
/// 1살 미만은 "n개월", 생후 1개월 미만·birthDate null은 나이 생략.
/// sex는 pets.sex 값('female'/'male'/'unknown'). null/그 외 값 = 미구분(아가).
String? petTagLabel({
  String? morph,
  String? sex,
  DateTime? birthDate,
  DateTime? now,
}) {
  final ref = now ?? DateTime.now();
  String? age;
  if (birthDate != null && !birthDate.isAfter(ref)) {
    var months = (ref.year - birthDate.year) * 12 + ref.month - birthDate.month;
    if (ref.day < birthDate.day) months -= 1;
    if (months >= 12) {
      age = '${months ~/ 12}살';
    } else if (months >= 1) {
      age = '$months개월';
    }
  }
  final sexLabel = switch (sex) {
    'female' => '여아',
    'male' => '남아',
    'unknown' => '아가',
    _ => sex == null ? null : '아가',
  };
  final parts = [age, morph, sexLabel].whereType<String>().toList();
  return parts.isEmpty ? null : parts.join(' ');
}

/// PostgREST embedded count(`[{count: n}]`) → int. 형태가 다르면 0.
int embeddedCount(dynamic v) {
  if (v is List && v.isNotEmpty && v.first is Map) {
    return (v.first as Map)['count'] as int? ?? 0;
  }
  return 0;
}

/// community_posts row + 작성자(public_profiles) + 카운트 + 내 좋아요.
class CommunityPost {
  final String id;
  final String authorId;
  final String authorName; // public_profiles 병합. 미로드 시 ''(이니셜 폴백)
  final String? authorAvatarUrl;
  final String? caption;
  final String videoPath; // community-media 내 경로
  final String? thumbnailPath;
  final String? sourceClipId;
  final double? durationSec;
  final String? action; // 행동 분류 스냅샷
  final String? petName;
  final String? petMorph;
  final String? petSex;
  final DateTime? petBirthDate;
  final String? petPhotoPath;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;

  const CommunityPost({
    required this.id,
    required this.authorId,
    this.authorName = '',
    this.authorAvatarUrl,
    this.caption,
    required this.videoPath,
    this.thumbnailPath,
    this.sourceClipId,
    this.durationSec,
    this.action,
    this.petName,
    this.petMorph,
    this.petSex,
    this.petBirthDate,
    this.petPhotoPath,
    required this.createdAt,
    this.likeCount = 0,
    this.commentCount = 0,
    this.likedByMe = false,
  });

  /// 게시물의 크레 꼬리표. 크레 미연결 게시물이면 null.
  String? get petTag =>
      petTagLabel(morph: petMorph, sex: petSex, birthDate: petBirthDate);

  CommunityPost copyWith({
    String? authorName,
    String? authorAvatarUrl,
    int? likeCount,
    int? commentCount,
    bool? likedByMe,
  }) =>
      CommunityPost(
        id: id,
        authorId: authorId,
        authorName: authorName ?? this.authorName,
        authorAvatarUrl: authorAvatarUrl ?? this.authorAvatarUrl,
        caption: caption,
        videoPath: videoPath,
        thumbnailPath: thumbnailPath,
        sourceClipId: sourceClipId,
        durationSec: durationSec,
        action: action,
        petName: petName,
        petMorph: petMorph,
        petSex: petSex,
        petBirthDate: petBirthDate,
        petPhotoPath: petPhotoPath,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
      );

  factory CommunityPost.fromJson(Map<String, dynamic> j) {
    return CommunityPost(
      id: j['id'] as String,
      authorId: j['author_id'] as String,
      caption: j['caption'] as String?,
      videoPath: j['video_path'] as String,
      thumbnailPath: j['thumbnail_path'] as String?,
      sourceClipId: j['source_clip_id'] as String?,
      durationSec: (j['duration_sec'] as num?)?.toDouble(),
      action: j['action'] as String?,
      petName: j['pet_name'] as String?,
      petMorph: j['pet_morph'] as String?,
      petSex: j['pet_sex'] as String?,
      // DATE 컬럼은 'YYYY-MM-DD' — 시각 개념이 없어 로컬 변환 없이 파싱.
      petBirthDate: j['pet_birth_date'] != null
          ? DateTime.tryParse(j['pet_birth_date'] as String)
          : null,
      petPhotoPath: j['pet_photo_path'] as String?,
      createdAt:
          parseLocalDateTime(j['created_at']) ?? DateTime.now(),
      likeCount: embeddedCount(j['community_likes']),
      commentCount: embeddedCount(j['community_comments']),
    );
  }
}
```

```dart
// lib/features/community/domain/community_comment.dart  (신규)
import '../../../shared/domain/num_format.dart';

class CommunityComment {
  final String id;
  final String postId;
  final String authorId;
  final String authorName; // public_profiles 병합
  final String? authorAvatarUrl;
  final String body;
  final DateTime createdAt;

  const CommunityComment({
    required this.id,
    required this.postId,
    required this.authorId,
    this.authorName = '',
    this.authorAvatarUrl,
    required this.body,
    required this.createdAt,
  });

  CommunityComment withAuthor(String name, String? avatarUrl) =>
      CommunityComment(
        id: id, postId: postId, authorId: authorId,
        authorName: name, authorAvatarUrl: avatarUrl,
        body: body, createdAt: createdAt,
      );

  factory CommunityComment.fromJson(Map<String, dynamic> j) =>
      CommunityComment(
        id: j['id'] as String,
        postId: j['post_id'] as String,
        authorId: j['author_id'] as String,
        body: j['body'] as String,
        createdAt: parseLocalDateTime(j['created_at']) ?? DateTime.now(),
      );
}
```

- [ ] **Step 4: 실패 테스트 작성 — fromJson**

```dart
// test/features/community/community_post_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/community/domain/community_post.dart';

void main() {
  test('fromJson — 카운트·크레 스냅샷·UTC 변환', () {
    final p = CommunityPost.fromJson({
      'id': 'p1',
      'author_id': 'u1',
      'caption': '캡션',
      'video_path': 'u1/posts/p1.mp4',
      'thumbnail_path': 'u1/posts/p1.jpg',
      'source_clip_id': 'c1',
      'duration_sec': 24.0,
      'action': '탐색',
      'pet_name': '모카',
      'pet_morph': '릴리화이트',
      'pet_sex': 'female',
      'pet_birth_date': '2024-05-01',
      'pet_photo_path': 'u1/posts/p1_pet.jpg',
      'created_at': '2026-08-28T14:41:00Z', // UTC → 로컬(KST 23:41)
      'community_likes': [{'count': 12}],
      'community_comments': [{'count': 4}],
    });
    expect(p.likeCount, 12);
    expect(p.commentCount, 4);
    expect(p.petName, '모카');
    expect(p.createdAt.isUtc, false); // 로컬 변환 확인
    expect(p.petTag, isNotNull);
  });

  test('embeddedCount — 비정형 입력은 0', () {
    expect(embeddedCount(null), 0);
    expect(embeddedCount([]), 0);
    expect(embeddedCount('x'), 0);
  });
}
```

- [ ] **Step 5:** `flutter test test/features/community/ -r compact` → 전부 PASS. `flutter analyze` — 구 CommunityCategory 소비처(community_screen/providers/repository) 에러가 나면 **정상**(다음 task에서 재작성). 에러가 그 3파일 밖으로 번지면 여기서 수습.
- [ ] **Step 6:** 커밋은 Task 2와 묶는다 (이 시점은 소비처 미수정으로 analyze 에러 존재 — 깨진 상태 커밋 금지 규칙)

### Task 2: CommunityRepository 재작성

**Context:**
- Depends on: Task 0(테이블), Task 1(모델)
- Inputs: `community_posts` 스키마, `public_profiles` 뷰, `community-media` 버킷(비공개 → signed URL)
- Outputs: `CommunityRepository` — listPosts/getPost/toggleLike/listComments/addComment/deleteComment/deletePost/signedUrl
- Must know: ① **`public_profiles`는 embed 불가** — posts의 FK가 auth.users로 걸려 있어 PostgREST가 뷰 관계를 못 찾는다. 작성자·내 좋아요는 별도 쿼리 후 클라 병합. ② 버킷이 비공개라 `createSignedUrl` 필수(`getPublicUrl`은 403). 썸네일은 `createSignedUrls`(복수형)로 페이지당 1회. ③ 피드 병합 로직은 순수 함수 `mergeFeedRows`로 분리해 네트워크 없이 테스트.
- Acceptance: `flutter test test/features/community/ -r compact` PASS, `flutter analyze` 에러 0 (providers/screen은 Task 4~5에서 재작성되므로 이 시점 기준 컴파일만 맞추면 됨 — 구 화면이 아직 구 API를 부르면 Task 4 전까지 임시로 화면 빌드를 깨지 않는 최소 수정 허용 안 함: **Task 2~5는 한 push 단위로 묶는다**)

**Files:**
- Modify(재작성): `lib/features/community/data/community_repository.dart`
- Create: `test/features/community/community_feed_merge_test.dart`

- [ ] **Step 1: 실패 테스트 — 병합 순수 함수**

```dart
// test/features/community/community_feed_merge_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/community/data/community_repository.dart';
import 'package:vivnanaut/features/community/domain/community_post.dart';

void main() {
  final base = CommunityPost(
    id: 'p1', authorId: 'u1', videoPath: 'u1/posts/p1.mp4',
    createdAt: DateTime(2026, 8, 28),
  );

  test('작성자 프로필·내 좋아요 병합', () {
    final merged = mergeFeedRows(
      posts: [base],
      profiles: {'u1': (name: '게코집사', avatarUrl: null)},
      myLikedPostIds: {'p1'},
    );
    expect(merged.single.authorName, '게코집사');
    expect(merged.single.likedByMe, true);
  });

  test('프로필 없는 작성자는 빈 이름(이니셜 폴백)', () {
    final merged =
        mergeFeedRows(posts: [base], profiles: {}, myLikedPostIds: {});
    expect(merged.single.authorName, '');
    expect(merged.single.likedByMe, false);
  });
}
```

- [ ] **Step 2:** `flutter test test/features/community/community_feed_merge_test.dart` → FAIL

- [ ] **Step 3: 구현**

```dart
// lib/features/community/data/community_repository.dart  (전면 재작성)
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/community_comment.dart';
import '../domain/community_post.dart';

typedef PublicProfile = ({String name, String? avatarUrl});

/// posts row + 별도 조회한 프로필/내 좋아요를 화면 모델로 병합.
/// public_profiles는 FK가 auth.users 경유라 PostgREST embed가 안 돼
/// 병합을 클라에서 한다 — 네트워크 없는 순수 함수로 분리해 테스트.
List<CommunityPost> mergeFeedRows({
  required List<CommunityPost> posts,
  required Map<String, PublicProfile> profiles,
  required Set<String> myLikedPostIds,
}) {
  return [
    for (final p in posts)
      p.copyWith(
        authorName: profiles[p.authorId]?.name ?? '',
        authorAvatarUrl: profiles[p.authorId]?.avatarUrl,
        likedByMe: myLikedPostIds.contains(p.id),
      ),
  ];
}

/// 커뮤니티 피드/댓글/좋아요 — Supabase 직결(RLS: 읽기 전체·쓰기 본인).
class CommunityRepository {
  CommunityRepository({required SupabaseClient supabase})
      : _supabase = supabase;

  final SupabaseClient _supabase;
  static const _bucket = 'community-media';
  static const signedUrlTtlSec = 3600;

  String? get _uid => _supabase.auth.currentUser?.id;

  /// 피드 한 페이지 (최신순). offset 기반 range 페이지네이션.
  Future<List<CommunityPost>> listPosts({int offset = 0, int limit = 20}) async {
    final rows = await _supabase
        .from('community_posts')
        .select('*, community_likes(count), community_comments(count)')
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final posts = (rows as List)
        .map((r) => CommunityPost.fromJson(r as Map<String, dynamic>))
        .toList();
    if (posts.isEmpty) return posts;

    final authorIds = posts.map((p) => p.authorId).toSet().toList();
    final postIds = posts.map((p) => p.id).toList();
    final results = await Future.wait([
      _fetchProfiles(authorIds),
      _fetchMyLikes(postIds),
    ]);
    return mergeFeedRows(
      posts: posts,
      profiles: results[0] as Map<String, PublicProfile>,
      myLikedPostIds: results[1] as Set<String>,
    );
  }

  Future<CommunityPost?> getPost(String id) async {
    final rows = await _supabase
        .from('community_posts')
        .select('*, community_likes(count), community_comments(count)')
        .eq('id', id)
        .limit(1);
    final list = rows as List;
    if (list.isEmpty) return null;
    final post = CommunityPost.fromJson(list.first as Map<String, dynamic>);
    final profiles = await _fetchProfiles([post.authorId]);
    final likes = await _fetchMyLikes([post.id]);
    return mergeFeedRows(
        posts: [post], profiles: profiles, myLikedPostIds: likes).single;
  }

  Future<Map<String, PublicProfile>> _fetchProfiles(List<String> ids) async {
    try {
      final rows = await _supabase
          .from('public_profiles')
          .select('id, display_name, avatar_url')
          .inFilter('id', ids);
      return {
        for (final r in rows as List)
          (r as Map)['id'] as String: (
            name: (r['display_name'] as String?) ?? '',
            avatarUrl: r['avatar_url'] as String?,
          ),
      };
    } catch (_) {
      return {}; // 프로필 조회 실패는 피드를 막지 않는다 — 이니셜 폴백
    }
  }

  Future<Set<String>> _fetchMyLikes(List<String> postIds) async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final rows = await _supabase
          .from('community_likes')
          .select('post_id')
          .eq('user_id', uid)
          .inFilter('post_id', postIds);
      return {for (final r in rows as List) (r as Map)['post_id'] as String};
    } catch (_) {
      return {};
    }
  }

  /// like=true면 좋아요, false면 해제. upsert/조건 delete라 중복 탭에 안전.
  Future<void> setLike(String postId, bool like) async {
    final uid = _uid;
    if (uid == null) return;
    if (like) {
      await _supabase
          .from('community_likes')
          .upsert({'post_id': postId, 'user_id': uid});
    } else {
      await _supabase
          .from('community_likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', uid);
    }
  }

  Future<List<CommunityComment>> listComments(String postId) async {
    final rows = await _supabase
        .from('community_comments')
        .select()
        .eq('post_id', postId)
        .order('created_at', ascending: true);
    final comments = (rows as List)
        .map((r) => CommunityComment.fromJson(r as Map<String, dynamic>))
        .toList();
    if (comments.isEmpty) return comments;
    final profiles =
        await _fetchProfiles(comments.map((c) => c.authorId).toSet().toList());
    return [
      for (final c in comments)
        c.withAuthor(
            profiles[c.authorId]?.name ?? '', profiles[c.authorId]?.avatarUrl),
    ];
  }

  Future<void> addComment(String postId, String body) async {
    final uid = _uid;
    if (uid == null) return;
    await _supabase.from('community_comments').insert({
      'post_id': postId,
      'author_id': uid,
      'body': body,
    });
  }

  Future<void> deleteComment(String commentId) async {
    await _supabase.from('community_comments').delete().eq('id', commentId);
  }

  /// 게시물 삭제 = row 삭제(likes/comments는 FK CASCADE) + Storage 복사본 정리.
  /// Storage 삭제는 best-effort — row가 지워지면 파일은 접근 불가 고아일 뿐.
  Future<void> deletePost(CommunityPost post) async {
    await _supabase.from('community_posts').delete().eq('id', post.id);
    final paths = [
      post.videoPath,
      if (post.thumbnailPath != null) post.thumbnailPath!,
      if (post.petPhotoPath != null) post.petPhotoPath!,
    ];
    try {
      await _supabase.storage.from(_bucket).remove(paths);
    } catch (_) {}
  }

  /// 피드 한 페이지의 썸네일·크레 사진 signed URL 일괄 발급. path → url.
  Future<Map<String, String>> signedImageUrls(List<CommunityPost> posts) async {
    final paths = <String>{
      for (final p in posts) ...[
        if (p.thumbnailPath != null) p.thumbnailPath!,
        if (p.petPhotoPath != null) p.petPhotoPath!,
      ],
    }.toList();
    if (paths.isEmpty) return {};
    try {
      final signed = await _supabase.storage
          .from(_bucket)
          .createSignedUrls(paths, signedUrlTtlSec);
      return {
        for (final s in signed)
          if (s.path != null) s.path!: s.signedUrl,
      };
    } catch (_) {
      return {};
    }
  }

  Future<String> signedVideoUrl(String videoPath) async {
    return _supabase.storage
        .from(_bucket)
        .createSignedUrl(videoPath, signedUrlTtlSec);
  }
}
```

- [ ] **Step 4:** `flutter test test/features/community/ -r compact` → PASS
- [ ] **Step 5:** 커밋은 Task 5 끝에서 (Phase 1 화면까지가 한 컴파일 단위)

### Task 3: 게시 파이프라인 — CommunityPostPublisher

**Context:**
- Depends on: Task 0, Task 1
- Inputs: `FavoriteClip`(로컬 mp4 경로 보유 — `filePath`), `MotionClipRepository.getThumbnailUrl`(presigned, 404 가능), `Pet.photoPath`(로컬 사진, null 가능), 행동 라벨
- Outputs: `CommunityPostPublisher.publish()` — 업로드 3종 + row INSERT + 실패 롤백. `MotionClipRepository.labelFor()` 공개 메서드, `FavoriteClipRepository.listAll()` 메서드
- Must know: ① 영상은 **즐겨찾기 로컬 mp4를 그대로 업로드**한다(다운로드 불필요 — 즐겨찾기가 이미 영구 보관본). 로컬 파일이 유실됐으면 `getPlaybackUrl`로 다운로드 폴백. ② 썸네일은 terra-api presigned를 http GET — 404면 null로 계속(피드는 아이콘 폴백). ③ INSERT 실패 시 업로드한 객체를 remove(고아 방지). ④ postId는 앱에서 `Uuid().v4()`로 선발급(경로 규약 `{uid}/posts/{postId}.*`에 필요).
- Acceptance: `flutter analyze` 에러 0. 실동작은 Task 7 수동 검증에서(실기기 게시 1건).

**Files:**
- Create: `lib/features/community/data/community_post_publisher.dart`
- Modify: `lib/features/my_cage/data/motion_clip_repository.dart` (labelFor 추가)
- Modify: `lib/features/my_cage/data/favorite_clip_repository.dart` (listAll 추가)

- [ ] **Step 1: my_cage 쪽 메서드 2개 추가**

```dart
// motion_clip_repository.dart — _fetchLabels 아래에 추가
  /// 단일 클립의 대표 행동 라벨(게시 스냅샷용). 없거나 실패 시 null.
  Future<String?> labelFor(String clipId) async {
    final labels = await _fetchLabels([clipId]);
    return labels[clipId];
  }
```

```dart
// favorite_clip_repository.dart — listByCamera 아래에 추가
  /// 전체 즐겨찾기(현재 계정, 최근 저장순) — 커뮤니티 글쓰기 클립 선택용.
  List<FavoriteClip> listAll() {
    final uid = _uid;
    return _box.values.where((f) => f.ownerId == uid).toList()
      ..sort((a, b) => b.favoritedAt.compareTo(a.favoritedAt));
  }
```

- [ ] **Step 2: Publisher 구현**

```dart
// lib/features/community/data/community_post_publisher.dart  (신규)
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../my_cage/data/favorite_clip_repository.dart';
import '../../my_cage/data/motion_clip_repository.dart';
import '../../my_cage/domain/favorite_clip.dart';
import '../../my_pets/domain/pet.dart';

/// 게시 = 스냅샷 복사 파이프라인.
/// 영상(로컬 mp4 우선) + 썸네일(terra presigned) + 크레 사진(로컬)을
/// community-media로 올리고 community_posts에 INSERT.
/// INSERT 실패 시 올린 객체를 지운다(고아 방지). 진행률은 0~1.
class CommunityPostPublisher {
  CommunityPostPublisher({
    required SupabaseClient supabase,
    required MotionClipRepository motionRepo,
    required FavoriteClipRepository favoriteRepo,
  })  : _supabase = supabase,
        _motionRepo = motionRepo,
        _favoriteRepo = favoriteRepo;

  final SupabaseClient _supabase;
  final MotionClipRepository _motionRepo;
  final FavoriteClipRepository _favoriteRepo;
  static const _bucket = 'community-media';

  Future<void> publish({
    required FavoriteClip fav,
    String? caption,
    Pet? pet,
    void Function(double progress)? onProgress,
  }) async {
    final uid = _supabase.auth.currentUser?.id;
    if (uid == null) throw StateError('not signed in');
    final postId = const Uuid().v4();
    final uploaded = <String>[];
    void report(double v) => onProgress?.call(v.clamp(0, 1));

    try {
      // 1) 영상 — 로컬 즐겨찾기 파일 우선, 유실 시 presigned 다운로드 폴백
      report(0.05);
      final local = _favoriteRepo.getLocalFile(fav.clipId);
      final Uint8List videoBytes;
      if (local != null) {
        videoBytes = await local.readAsBytes();
      } else {
        final url = await _motionRepo.getPlaybackUrl(fav.clipId);
        final resp = await http.get(Uri.parse(url));
        if (resp.statusCode != 200) {
          throw Exception('clip download failed: ${resp.statusCode}');
        }
        videoBytes = resp.bodyBytes;
      }
      final videoPath = '$uid/posts/$postId.mp4';
      await _supabase.storage.from(_bucket).uploadBinary(
            videoPath, videoBytes,
            fileOptions: const FileOptions(contentType: 'video/mp4'),
          );
      uploaded.add(videoPath);
      report(0.6);

      // 2) 썸네일 — presigned GET, 404면 없이 진행
      String? thumbnailPath;
      final thumbUrl = await _motionRepo.getThumbnailUrl(fav.clipId);
      if (thumbUrl != null) {
        final resp = await http.get(Uri.parse(thumbUrl));
        if (resp.statusCode == 200) {
          thumbnailPath = '$uid/posts/$postId.jpg';
          await _supabase.storage.from(_bucket).uploadBinary(
                thumbnailPath, resp.bodyBytes,
                fileOptions: const FileOptions(contentType: 'image/jpeg'),
              );
          uploaded.add(thumbnailPath);
        }
      }
      report(0.75);

      // 3) 크레 사진 — 로컬 파일이 있을 때만
      String? petPhotoPath;
      final photo = pet?.photoPath;
      if (photo != null && File(photo).existsSync()) {
        petPhotoPath = '$uid/posts/${postId}_pet.jpg';
        await _supabase.storage.from(_bucket).uploadBinary(
              petPhotoPath, await File(photo).readAsBytes(),
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        uploaded.add(petPhotoPath);
      }
      report(0.85);

      // 4) 행동 라벨 스냅샷 (실패해도 게시는 계속)
      String? action;
      try {
        action = await _motionRepo.labelFor(fav.clipId);
      } catch (_) {}

      // 5) row INSERT
      await _supabase.from('community_posts').insert({
        'id': postId,
        'author_id': uid,
        'caption': (caption?.trim().isEmpty ?? true) ? null : caption!.trim(),
        'video_path': videoPath,
        'thumbnail_path': thumbnailPath,
        'source_clip_id': fav.clipId,
        'duration_sec': fav.durationSec,
        'action': action,
        'pet_name': pet?.name,
        'pet_morph': pet?.morph,
        'pet_sex': pet?.sex,
        'pet_birth_date':
            pet?.birthDate?.toIso8601String().substring(0, 10), // DATE
        'pet_photo_path': petPhotoPath,
      });
      report(1.0);
    } catch (e) {
      if (uploaded.isNotEmpty) {
        try {
          await _supabase.storage.from(_bucket).remove(uploaded);
        } catch (_) {}
      }
      rethrow;
    }
  }
}
```

- [ ] **Step 3:** `flutter analyze` → 에러 0 (community_screen의 구 API 에러는 Task 5까지 유예 — Phase 1은 한 push 단위)

### Task 4: Providers 재작성

**Context:**
- Depends on: Task 2, Task 3
- Inputs: `CommunityRepository`, `CommunityPostPublisher`, `motionClipRepositoryProvider`·`favoriteClipRepositoryProvider`(my_cage_providers — export 여부 확인: favorite repo provider가 private면 public getter 추가), `currentUserProvider`
- Outputs: `communityRepositoryProvider` / `communityFeedProvider`(페이지네이션 AsyncNotifier) / `commentsProvider.family` / `feedImageUrlsProvider` / `communityPublisherProvider`
- Must know: **인증 의존 non-autoDispose provider는 `currentUserProvider.select((u) => u?.id)` watch 필수**(계정 전환 stale 방지 — CLAUDE.md 3층 격리 규칙). 좋아요는 낙관적 갱신: state 먼저 바꾸고 setLike 실패 시 되돌린다. 비동기 콜백에서 `mounted`/`ref` 생존 확인.
- Acceptance: `flutter analyze` 에러 0 (Task 5와 함께)

**Files:**
- Modify(재작성): `lib/features/community/presentation/community_providers.dart`

- [ ] **Step 1: 구현**

```dart
// lib/features/community/presentation/community_providers.dart  (전면 재작성)
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/presentation/auth_providers.dart';
import '../../my_cage/presentation/my_cage_providers.dart';
import '../data/community_post_publisher.dart';
import '../data/community_repository.dart';
import '../domain/community_comment.dart';
import '../domain/community_post.dart';

final communityRepositoryProvider = Provider<CommunityRepository>(
  (ref) => CommunityRepository(supabase: Supabase.instance.client),
);

final communityPublisherProvider = Provider<CommunityPostPublisher>(
  (ref) => CommunityPostPublisher(
    supabase: Supabase.instance.client,
    motionRepo: ref.watch(motionClipRepositoryProvider),
    favoriteRepo: ref.watch(favoriteClipRepositoryProvider),
  ),
);

const _pageSize = 20;

/// 피드 — offset 페이지네이션 + 낙관적 좋아요. 계정 전환 시 자동 리셋(userId watch).
class CommunityFeed extends AsyncNotifier<List<CommunityPost>> {
  bool _hasMore = true;
  bool get hasMore => _hasMore;

  @override
  Future<List<CommunityPost>> build() async {
    ref.watch(currentUserProvider.select((u) => u?.id)); // 3층 격리 ①
    _hasMore = true;
    final page =
        await ref.read(communityRepositoryProvider).listPosts(limit: _pageSize);
    _hasMore = page.length == _pageSize;
    return page;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || !_hasMore || state.isLoading) return;
    final next = await ref
        .read(communityRepositoryProvider)
        .listPosts(offset: current.length, limit: _pageSize);
    _hasMore = next.length == _pageSize;
    state = AsyncData([...current, ...next]);
  }

  /// 낙관적 좋아요 — UI 먼저, 서버 실패 시 롤백.
  Future<void> toggleLike(String postId) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final idx = current.indexWhere((p) => p.id == postId);
    if (idx < 0) return;
    final post = current[idx];
    final liked = !post.likedByMe;
    CommunityPost apply(CommunityPost p, bool v) => p.copyWith(
        likedByMe: v, likeCount: p.likeCount + (v ? 1 : -1));
    state = AsyncData([...current]..[idx] = apply(post, liked));
    try {
      await ref.read(communityRepositoryProvider).setLike(postId, liked);
    } catch (_) {
      final rolled = state.valueOrNull;
      if (rolled == null) return;
      final i = rolled.indexWhere((p) => p.id == postId);
      if (i >= 0) state = AsyncData([...rolled]..[i] = apply(rolled[i], !liked));
    }
  }

  Future<void> deletePost(CommunityPost post) async {
    await ref.read(communityRepositoryProvider).deletePost(post);
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncData(current.where((p) => p.id != post.id).toList());
    }
  }
}

final communityFeedProvider =
    AsyncNotifierProvider<CommunityFeed, List<CommunityPost>>(CommunityFeed.new);

/// 피드 이미지(썸네일·크레 사진) signed URL. 피드 데이터에 종속.
final feedImageUrlsProvider = FutureProvider<Map<String, String>>((ref) async {
  final posts = await ref.watch(communityFeedProvider.future);
  return ref.read(communityRepositoryProvider).signedImageUrls(posts);
});

final commentsProvider = FutureProvider.autoDispose
    .family<List<CommunityComment>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).listComments(postId);
});
```

- [ ] **Step 2:** `my_cage_providers.dart`에서 `favoriteClipRepositoryProvider`가 없거나 private이면 public provider 추가:

```dart
// my_cage_providers.dart — Repository Provider 구역에 (이미 있으면 생략)
final favoriteClipRepositoryProvider = Provider<FavoriteClipRepository>(
  (ref) => FavoriteClipRepository(supabase: ref.watch(_supabaseClientProvider)),
);
```

- [ ] **Step 3:** `flutter analyze` — community_screen만 에러 남았는지 확인 (Task 5에서 소거)

### Task 5: 피드 화면 재작성 (CommunityScreen + PostCard + PetTagRow)

**Context:**
- Depends on: Task 4
- Inputs: 확정 시안 ① — 헤더 + 공지 배너 자리(2차, 이번엔 미표시) + 위키 카드 + 피드 카드(작성자/썸네일/행동칩/**크레 행**/캡션/좋아요·댓글) + FAB. B안 문법: `GlassCard`(radius 16)·`context.glass` 토큰·`labelCaps`
- Outputs: 새 `CommunityScreen`, `PostCard`, `PetTagRow`, empty state. 구 `_CategoryChips`·`PendingSection`·`_seedPosts` 흔적 완전 제거
- Must know: ① **CircularProgressIndicator 금지** — 로딩은 shimmer 스켈레톤. ② 하단 패딩은 `glassDockListPadding(context)`. ③ 크레 행 위계: 이름 = `tileTitle`(15 SemiBold → 13은 카드 맥락상 `tileTitle.copyWith(fontSize: 13)`), 꼬리표 = `textTertiary` 10~11. ④ 무한 스크롤: `ScrollController` extent 80% 도달 시 `loadMore()`. ⑤ 문자열 전부 ko.json 키(Task 9에서 일괄 추가 — 키 이름은 여기 코드에 확정 표기). ⑥ ⋯ 메뉴는 이번엔 내 글일 때 '삭제'만(신고·차단은 Task 11~12에서 채움).
- Acceptance: `flutter analyze` 에러 0, `flutter test` 전체 PASS 후 **Phase 1 push 단위 1차 커밋**. 실기기: 피드 로드·빈 상태·당겨서 새로고침 확인.

**Files:**
- Modify(재작성): `lib/features/community/presentation/community_screen.dart`
- Create: `lib/features/community/presentation/widgets/post_card.dart`, `lib/features/community/presentation/widgets/pet_tag_row.dart`

- [ ] **Step 1: PetTagRow (독립 위젯 — 피드·캡션 화면 공용)**

```dart
// lib/features/community/presentation/widgets/pet_tag_row.dart  (신규)
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
              width: photoSize, height: photoSize, fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => SizedBox.square(
                dimension: photoSize,
                child: ColoredBox(color: glass.overlayFaint),
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
        Text(name,
            style: glass.tileTitle.copyWith(fontSize: 13, height: 1.2)),
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
```

- [ ] **Step 2: PostCard**

```dart
// lib/features/community/presentation/widgets/post_card.dart  (신규)
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/account_avatar.dart';
import '../../../../shared/widgets/glass_card.dart';
import '../../domain/community_post.dart';
import 'pet_tag_row.dart';

/// 피드 카드 — 작성자 / 썸네일(탭=재생) / 행동 칩 / 크레 행 / 캡션 / 좋아요·댓글.
class PostCard extends StatelessWidget {
  const PostCard({
    super.key,
    required this.post,
    this.thumbnailUrl,
    this.petPhotoUrl,
    required this.onPlay,
    required this.onToggleLike,
    required this.onOpenComments,
    this.onDelete, // 내 글일 때만 non-null
  });

  final CommunityPost post;
  final String? thumbnailUrl;
  final String? petPhotoUrl;
  final VoidCallback onPlay;
  final VoidCallback onToggleLike;
  final VoidCallback onOpenComments;
  final VoidCallback? onDelete;

  String _relativeTime(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'time_just_now'.tr();
    if (diff.inMinutes < 60) {
      return 'time_minutes_ago'.tr(namedArgs: {'n': '${diff.inMinutes}'});
    }
    if (diff.inHours < 24) {
      return 'time_hours_ago'.tr(namedArgs: {'n': '${diff.inHours}'});
    }
    return 'time_days_ago'.tr(namedArgs: {'n': '${diff.inDays}'});
  }

  String _duration(double? sec) {
    if (sec == null) return '';
    final s = sec.round();
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return GlassCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
            child: Row(children: [
              AccountAvatar(
                displayName: post.authorName,
                imageUrl: post.authorAvatarUrl,
                size: 30,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(post.authorName.isEmpty
                            ? 'community_author_unknown'.tr()
                            : post.authorName,
                        style: glass.tileTitle.copyWith(fontSize: 12.5)),
                    Text(_relativeTime(post.createdAt),
                        style: glass.tileStatus.copyWith(fontSize: 10.5)),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  icon: Icon(Icons.more_horiz, color: glass.textTertiary),
                  onPressed: () => _showMenu(context),
                ),
            ]),
          ),
          GestureDetector(
            onTap: onPlay,
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(fit: StackFit.expand, children: [
                if (thumbnailUrl != null)
                  Image.network(thumbnailUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _thumbFallback(glass))
                else
                  _thumbFallback(glass),
                Center(
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.45),
                      border: Border.all(color: Colors.white70, width: 1.5),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 28),
                  ),
                ),
                if (post.action != null)
                  Positioned(
                    left: 8, top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: glass.activeTile,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(post.action!,
                          style: glass.tileTitleActive
                              .copyWith(fontSize: 10)),
                    ),
                  ),
                Positioned(
                  right: 8, bottom: 8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(_duration(post.durationSec),
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontFeatures: [FontFeature.tabularFigures()])),
                  ),
                ),
              ]),
            ),
          ),
          if (post.petName != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: PetTagRow(
                  name: post.petName!,
                  tag: post.petTag,
                  photoUrl: petPhotoUrl),
            ),
          if (post.caption != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(post.caption!,
                  style: glass.tileStatus
                      .copyWith(fontSize: 12, color: glass.textPrimary)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 11),
            child: Row(children: [
              _ActionChip(
                icon: post.likedByMe ? Icons.favorite : Icons.favorite_border,
                color: post.likedByMe ? glass.signalAlert : glass.textSecondary,
                label: '${post.likeCount}',
                onTap: onToggleLike,
              ),
              const SizedBox(width: 16),
              _ActionChip(
                icon: Icons.chat_bubble_outline,
                color: glass.textSecondary,
                label: '${post.commentCount}',
                onTap: onOpenComments,
              ),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _thumbFallback(GlassPalette glass) => ColoredBox(
        color: glass.overlayFaint,
        child: Icon(Icons.videocam_off_outlined,
            color: glass.textTertiary, size: 32),
      );

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListTile(
          leading: const Icon(Icons.delete_outline),
          title: Text('community_delete_post'.tr()),
          onTap: () {
            Navigator.pop(ctx);
            onDelete?.call();
          },
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Row(children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: glass.tileStatus.copyWith(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()])),
        ]),
      ),
    );
  }
}
```

> `dart:ui`의 `FontFeature`는 `flutter/material.dart` 재수출로 충분 — import 추가 불필요.

- [ ] **Step 3: CommunityScreen 재작성**

```dart
// lib/features/community/presentation/community_screen.dart  (전면 재작성)
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme/app_styles.dart';
import '../../../core/theme/glass_palette.dart';
import '../../../shared/widgets/account_avatar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/glass_chip.dart';
import '../../../shared/widgets/glass_dock.dart';
import '../../../shared/widgets/glass_tab_header.dart';
import '../../../shared/widgets/glass_tab_shell.dart';
import '../../auth/presentation/auth_providers.dart';
import '../../profile/presentation/profile_providers.dart';
import '../domain/community_post.dart';
import 'community_providers.dart';
import 'widgets/comments_sheet.dart';
import 'widgets/post_card.dart';

/// 커뮤니티 탭 = 크레캠 클립 공유 피드 (2026-08-29 리뉴얼).
/// 구 카테고리 게시판(공지/QnA/자유)은 폐기 — 위키 진입 카드만 유지(§4.5).
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels >
          _scroll.position.maxScrollExtent * 0.8) {
        ref.read(communityFeedProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(communityFeedProvider);
    final imageUrls = ref.watch(feedImageUrlsProvider).valueOrNull ?? const {};
    final profile = ref.watch(profileNotifierProvider).valueOrNull;
    final myId = ref.watch(currentUserProvider.select((u) => u?.id));
    final glass = context.glass;

    return GlassTabShell(
      child: Stack(children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlassTabHeader(
            title: 'community_title'.tr(),
            actions: [
              AccountAvatar(
                tooltip: 'home_account'.tr(),
                imageUrl: profile?.avatarUrl,
                displayName: profile?.displayName,
                onPressed: () => context.push('/profile'),
              ),
            ],
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () =>
                  ref.read(communityFeedProvider.notifier).refresh(),
              child: feed.when(
                loading: () => _FeedSkeleton(glass: glass),
                error: (e, _) => _ErrorState(
                    onRetry: () =>
                        ref.read(communityFeedProvider.notifier).refresh()),
                data: (posts) => ListView(
                  controller: _scroll,
                  padding: glassDockListPadding(context),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppStyles.spacing16),
                      child: _WikiShortcutCard(),
                    ),
                    if (posts.isEmpty)
                      _EmptyFeed()
                    else
                      for (final post in posts)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(
                              AppStyles.spacing16,
                              AppStyles.spacing12,
                              AppStyles.spacing16,
                              0),
                          child: PostCard(
                            post: post,
                            thumbnailUrl: post.thumbnailPath == null
                                ? null
                                : imageUrls[post.thumbnailPath],
                            petPhotoUrl: post.petPhotoPath == null
                                ? null
                                : imageUrls[post.petPhotoPath],
                            onPlay: () => context
                                .push('/community-player/${post.id}'),
                            onToggleLike: () => ref
                                .read(communityFeedProvider.notifier)
                                .toggleLike(post.id),
                            onOpenComments: () =>
                                showCommentsSheet(context, ref, post),
                            onDelete: post.authorId == myId
                                ? () => _confirmDelete(post)
                                : null,
                          ),
                        ),
                  ],
                ),
              ),
            ),
          ),
        ]),
        Positioned(
          right: 16,
          bottom: glassDockListPadding(context).bottom + 8,
          child: FloatingActionButton(
            backgroundColor: glass.activeTile,
            foregroundColor: glass.textOnActive,
            onPressed: () => context.push('/community-share'),
            child: const Icon(Icons.add),
          ),
        ),
      ]),
    );
  }

  Future<void> _confirmDelete(CommunityPost post) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('community_delete_post'.tr()),
        content: Text('community_delete_confirm'.tr()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('common_cancel'.tr())),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('common_delete'.tr())),
        ],
      ),
    );
    if (ok == true && mounted) {
      await ref.read(communityFeedProvider.notifier).deletePost(post);
    }
  }
}

/// 빈 피드 — "준비 중"이 아니라 첫 공유 유도 (시안 확정).
class _EmptyFeed extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Padding(
      padding: const EdgeInsets.fromLTRB(32, 64, 32, 0),
      child: Column(children: [
        Icon(Icons.video_library_outlined,
            size: 40, color: glass.textTertiary),
        const SizedBox(height: 12),
        Text('community_empty_title'.tr(),
            style: glass.tileTitle, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text('community_empty_body'.tr(),
            style: glass.tileStatus, textAlign: TextAlign.center),
      ]),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text('community_feed_error'.tr(), style: context.glass.tileStatus),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: Text('common_retry'.tr())),
      ]),
    );
  }
}

/// 로딩 스켈레톤 — CircularProgressIndicator 금지 규칙.
class _FeedSkeleton extends StatelessWidget {
  const _FeedSkeleton({required this.glass});
  final GlassPalette glass;

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: glass.skeletonBase,
      highlightColor: glass.skeletonHighlight,
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.all(AppStyles.spacing16),
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: AppStyles.spacing12),
              child: Container(
                height: 280,
                decoration: BoxDecoration(
                  color: glass.overlay,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 위키 진입 카드 — 기존 화면에서 그대로 이식 (§4.5 위키는 커뮤니티 하위).
class _WikiShortcutCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Row(children: [
        Icon(Icons.menu_book_rounded,
            color: context.glass.textPrimary, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text('community_wiki_shortcut_title'.tr(),
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
        ),
        GlassChip(
          onTap: () => context.push('/search'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text('community_wiki_action_search'.tr(),
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 6),
        GlassChip(
          onTap: () => context.push('/wiki'),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text('community_wiki_action_info'.tr(),
              style: theme.textTheme.labelMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 4:** 구 도메인 잔재 제거 — `community_post.dart`의 `CommunityCategory` 참조가 프로젝트 전체에서 0인지 `grep -rn "CommunityCategory" lib test`로 확인, 남았으면 제거
- [ ] **Step 5:** `flutter analyze` 에러 0 (comments_sheet가 아직 없어 에러면 Task 8 위젯 파일을 먼저 만든 뒤 재확인 — Task 8 Step 1은 독립 파일이라 선행 가능)
- [ ] **Step 6: Phase 1 골격 커밋** (Task 1~5 + Task 8 위젯 파일)

```bash
flutter analyze && flutter test -r compact
git add lib/features/community lib/features/my_cage/data/favorite_clip_repository.dart lib/features/my_cage/data/motion_clip_repository.dart lib/features/my_cage/presentation/my_cage_providers.dart test/features/community assets/l10n/ko.json
git commit -m "feat(community): 클립 공유 피드 골격 — 모델·저장소·게시 파이프라인·피드 화면"
# pubspec: feat → minor +1, build +1 (예: 0.65.0+116)
```

### Task 6: 전체화면 재생 화면

**Context:**
- Depends on: Task 2 (signedVideoUrl), Task 9 라우트와 함께 컴파일됨
- Inputs: `CommunityPost.videoPath` → `signedVideoUrl`. 가로 전환·복원 패턴은 `motion_clip_player_screen.dart`가 선례(orientation·immersive·상태바 복원 — **화면 나갈 때 세로 복원 필수**, 홈은 세로 전제)
- Outputs: `CommunityPlayerScreen(postId)` — 라우트 `/community-player/:postId`
- Must know: ① video_player controller는 **initialize 실패 시 catch에서 dispose**(네이티브 누수 — 메모리 `project_video_player_controller_leak`). ② 상태바 스타일 복원은 MotionClipPlayerScreen 주석의 함정 그대로(어노테이션 제거 시 마지막 값 유지 → 직접 복원). ③ 저장/공유/즐겨찾기 버튼은 없음 — 남의 영상이다. 닫기 버튼만.
- Acceptance: 실기기 — 피드 카드 탭 → 가로 재생 → 닫기 → 세로 복귀·상태바 정상

**Files:**
- Create: `lib/features/community/presentation/community_player_screen.dart`

- [ ] **Step 1: 구현**

```dart
// lib/features/community/presentation/community_player_screen.dart  (신규)
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/glass_palette.dart';
import 'community_providers.dart';

/// 커뮤니티 게시물 재생 — 전체화면 가로 전용(클립 재생 결정 §6-B와 동일).
/// 저장·공유·즐겨찾기 없음(타인 소유 영상). 닫기만.
class CommunityPlayerScreen extends ConsumerStatefulWidget {
  const CommunityPlayerScreen({super.key, required this.postId});
  final String postId;

  @override
  ConsumerState<CommunityPlayerScreen> createState() =>
      _CommunityPlayerScreenState();
}

class _CommunityPlayerScreenState
    extends ConsumerState<CommunityPlayerScreen> {
  VideoPlayerController? _controller;
  String? _error;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _init();
  }

  Future<void> _init() async {
    try {
      final repo = ref.read(communityRepositoryProvider);
      final post = await repo.getPost(widget.postId);
      if (post == null) throw StateError('post not found');
      final url = await repo.signedVideoUrl(post.videoPath);
      // hoist — initialize 실패 시에도 dispose 가능하게 (controller leak 교훈)
      final controller =
          VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      try {
        await controller.initialize();
      } catch (e) {
        await controller.dispose();
        _controller = null;
        rethrow;
      }
      controller.setLooping(true);
      await controller.play();
      if (mounted) setState(() => _initialized = true);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Center(
          child: _error != null
              ? Text('community_play_error'.tr(),
                  style: const TextStyle(color: Colors.white70))
              : _initialized && _controller != null
                  ? AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    )
                  : Shimmer.fromColors(
                      baseColor: glass.skeletonBase,
                      highlightColor: glass.skeletonHighlight,
                      child: const SizedBox.expand(),
                    ),
        ),
        SafeArea(
          child: Align(
            alignment: Alignment.topLeft,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => context.pop(),
            ),
          ),
        ),
      ]),
    );
  }
}
```

- [ ] **Step 2:** `flutter analyze` 에러 0

### Task 7: 글쓰기 플로우 (클립 선택 → 캡션 → 게시)

**Context:**
- Depends on: Task 3(publisher), Task 4(providers), Task 6과 함께 Task 9에서 라우트 등록
- Inputs: `FavoriteClipRepository.listAll()`, 썸네일 = `motionClipRepositoryProvider.getThumbnailUrl(clipId)`(FutureProvider.family 캐시), 크레 자동 연결 = `enclosureSetsProvider`에서 `set.camera?.id == fav.cameraId`인 세트의 pet, 변경 시트 = `petListProvider`
- Outputs: `ClipSelectScreen`·`ComposeScreen`, 게시 성공 → 피드 refresh + pop
- Must know: ① 클립 타일에 **촬영 날짜·시각 표기 필수**(시안 확정 — `fav.startedAt`은 로컬 DateTime으로 저장돼 있어 추가 변환 불필요; 형식 `M/d HH:mm`). ② 캡션 300자 제한. ③ 게시 중 뒤로가기 방지(PopScope). ④ 진행률 표시(0~1). ⑤ 화면 간 전달은 `state.extra`(ComposeDraft).
- Acceptance: 실기기 — 즐겨찾기 1건 게시 성공 → 피드 최상단 노출, 크레 행 "이름 + n살 모프 성별" 표기 확인. 즐겨찾기 0건이면 빈 상태 안내.

**Files:**
- Create: `lib/features/community/presentation/clip_select_screen.dart`, `lib/features/community/presentation/compose_screen.dart`

- [ ] **Step 1: 클립 선택 화면**

```dart
// lib/features/community/presentation/clip_select_screen.dart  (신규)
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

/// 클립별 썸네일 presigned URL (404 = null → 아이콘 폴백).
final clipThumbUrlProvider = FutureProvider.autoDispose
    .family<String?, String>((ref, clipId) {
  return ref.watch(motionClipRepositoryProvider).getThumbnailUrl(clipId);
});

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
    final favorites =
        ref.watch(favoriteClipRepositoryProvider).listAll();
    final selected = favorites.where((f) => f.clipId == _selectedId).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('community_share_title'.tr()),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text('community_share_step1'.tr(),
                  style: glass.labelCaps),
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
    final thumb = ref.watch(clipThumbUrlProvider(fav.clipId)).valueOrNull;
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
            Image.network(thumb, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) =>
                    ColoredBox(color: glass.overlayFaint))
          else
            ColoredBox(color: glass.overlayFaint),
          // 촬영 날짜·시각 — 시안 확정 요소
          Positioned(
            left: 6, bottom: 6,
            child: Text(ts,
                style: const TextStyle(
                    color: Colors.white, fontSize: 10,
                    fontWeight: FontWeight.w500,
                    shadows: [Shadow(blurRadius: 3)])),
          ),
          Positioned(
            right: 6, bottom: 6,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
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
                width: 28, height: 28,
                decoration: BoxDecoration(
                    shape: BoxShape.circle, color: glass.activeTile),
                child: Icon(Icons.check,
                    size: 16, color: glass.textOnActive),
              ),
            ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2: 캡션 화면**

```dart
// lib/features/community/presentation/compose_screen.dart  (신규)
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
                      Text('community_publishing'.tr(namedArgs: {
                        'pct': '${((_progress ?? 0) * 100).round()}',
                      }), style: glass.labelCaps),
                    ]),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: AppStyles.spacing8),
              Text(_error!,
                  style:
                      glass.tileStatus.copyWith(color: glass.signalAlert)),
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
```

> `LinearProgressIndicator`는 결정형 진행률(0~1)이라 CircularProgressIndicator 금지 규칙(불확정 스피너 배제 취지)과 충돌하지 않는다 — 시안의 진행 바와 동일.

- [ ] **Step 3:** `flutter analyze` 에러 0

### Task 8: 댓글 바텀시트

**Context:**
- Depends on: Task 2, Task 4 (Task 5보다 먼저 파일만 생성해도 됨 — 독립 컴파일)
- Inputs: `commentsProvider.family`, `communityRepositoryProvider.addComment/deleteComment`
- Outputs: `showCommentsSheet(context, ref, post)` — DraggableScrollableSheet, 목록+입력, 내 댓글 삭제
- Must know: 등록 후 `ref.invalidate(commentsProvider(postId))` + 피드 카운트는 `communityFeedProvider.notifier.refresh()`가 아니라 **로컬 증가 없이 다음 refresh에 맡긴다**(카운트 1 차이는 시트 닫을 때 refresh로 수렴 — 피드 전체 재조회를 댓글마다 하지 않기). 시트 안 입력은 `viewInsets` 패딩으로 키보드 회피.
- Acceptance: 실기기 — 댓글 등록·삭제 즉시 반영, 키보드에 입력창 가림 없음

**Files:**
- Create: `lib/features/community/presentation/widgets/comments_sheet.dart`

- [ ] **Step 1: 구현**

```dart
// lib/features/community/presentation/widgets/comments_sheet.dart  (신규)
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../../../core/theme/glass_palette.dart';
import '../../../../shared/widgets/account_avatar.dart';
import '../../../auth/presentation/auth_providers.dart';
import '../../domain/community_post.dart';
import '../community_providers.dart';

/// 댓글 시트 — 피드 위에 떠서 맥락 유지 (시안 ④). 닫히면 피드 refresh로 카운트 수렴.
Future<void> showCommentsSheet(
    BuildContext context, WidgetRef ref, CommunityPost post) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _CommentsSheet(postId: post.id),
  );
  ref.read(communityFeedProvider.notifier).refresh();
}

class _CommentsSheet extends ConsumerStatefulWidget {
  const _CommentsSheet({required this.postId});
  final String postId;

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _input = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await ref
          .read(communityRepositoryProvider)
          .addComment(widget.postId, body);
      _input.clear();
      ref.invalidate(commentsProvider(widget.postId));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final glass = context.glass;
    final comments = ref.watch(commentsProvider(widget.postId));
    final myId = ref.watch(currentUserProvider.select((u) => u?.id));

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.9,
        builder: (context, scroll) => Column(children: [
          Container(
            width: 36, height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: glass.textTertiary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Text(
            'community_comments_title'
                .tr(namedArgs: {'n': '${comments.valueOrNull?.length ?? ''}'}),
            style: glass.tileTitle,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: comments.when(
              loading: () => Shimmer.fromColors(
                baseColor: glass.skeletonBase,
                highlightColor: glass.skeletonHighlight,
                child: ListView(
                  controller: scroll,
                  children: [
                    for (var i = 0; i < 3; i++)
                      const ListTile(
                          title: SizedBox(height: 14),
                          subtitle: SizedBox(height: 12)),
                  ],
                ),
              ),
              error: (e, _) => Center(
                  child: Text('community_comments_error'.tr(),
                      style: glass.tileStatus)),
              data: (list) => list.isEmpty
                  ? Center(
                      child: Text('community_comments_empty'.tr(),
                          style: glass.tileStatus))
                  : ListView.builder(
                      controller: scroll,
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return ListTile(
                          leading: AccountAvatar(
                              displayName: c.authorName,
                              imageUrl: c.authorAvatarUrl,
                              size: 30),
                          title: Text(
                              c.authorName.isEmpty
                                  ? 'community_author_unknown'.tr()
                                  : c.authorName,
                              style:
                                  glass.tileTitle.copyWith(fontSize: 12)),
                          subtitle: Text(c.body,
                              style: glass.tileStatus
                                  .copyWith(color: glass.textPrimary)),
                          trailing: c.authorId == myId
                              ? IconButton(
                                  icon: Icon(Icons.delete_outline,
                                      size: 18, color: glass.textTertiary),
                                  onPressed: () async {
                                    await ref
                                        .read(communityRepositoryProvider)
                                        .deleteComment(c.id);
                                    ref.invalidate(
                                        commentsProvider(widget.postId));
                                  },
                                )
                              : null,
                        );
                      },
                    ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
              child: Row(children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    decoration: InputDecoration(
                      hintText: 'community_comment_hint'.tr(),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.send_rounded, color: glass.activeTile),
                  onPressed: _sending ? null : _send,
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}
```

- [ ] **Step 2:** `flutter analyze` 에러 0

### Task 9: 라우터·l10n·마무리 커밋

**Context:**
- Depends on: Task 5~8
- Inputs: 신규 화면 3종(전체화면 플로우 — 독 없는 최상위 라우트, 크레캠 패턴)
- Outputs: 라우트 `/community-share`, `/community-share/caption`, `/community-player/:postId` + ko.json 키 전부 + Phase 1 완료 커밋·push
- Must know: 루트 navigator key가 없어 shell 탈출은 **최상위 GoRoute**로 한다(`/community/...` 하위로 넣으면 shell branch가 물어 독이 남는다 — `/crecam` 선례). ko.json 기존 키 재사용: `community_title`·`community_wiki_shortcut_title`·`community_wiki_action_search`·`community_wiki_action_info`·`home_account`·`time_*`. 구 키(`community_cat_*`·`community_pending_*`·`community_board_title`)는 삭제.
- Acceptance: `flutter analyze` 0 + `flutter test` PASS + 실기기 4탭 왕복·글쓰기 왕복에서 독/세로 복원 정상 → 커밋·push

**Files:**
- Modify: `lib/core/router/app_router.dart`, `assets/l10n/ko.json`

- [ ] **Step 1: 라우트 등록** — `/crecam` GoRoute 앞에 추가

```dart
      // 커뮤니티 전체화면 플로우 (독 없는 최상위 — shell 탈출)
      GoRoute(
        path: '/community-share',
        builder: (context, state) => const ClipSelectScreen(),
        routes: [
          GoRoute(
            path: 'caption',
            builder: (context, state) =>
                ComposeScreen(draft: state.extra! as ComposeDraft),
          ),
        ],
      ),
      GoRoute(
        path: '/community-player/:postId',
        builder: (context, state) => CommunityPlayerScreen(
            postId: state.pathParameters['postId']!),
      ),
```

- [ ] **Step 2: ko.json 키 추가** (기존 키 밑 community 구역에)

```json
{
  "community_author_unknown": "집사",
  "community_delete_post": "게시물 삭제",
  "community_delete_confirm": "이 게시물과 댓글·좋아요가 함께 삭제됩니다.",
  "community_empty_title": "아직 공유된 클립이 없어요",
  "community_empty_body": "크레캠에서 즐겨찾기한 클립을 첫 번째로 공유해보세요",
  "community_feed_error": "피드를 불러오지 못했어요",
  "community_share_title": "클립 공유",
  "community_share_step1": "1 / 2 단계",
  "community_share_step2": "2 / 2 단계",
  "community_share_no_favorites": "즐겨찾기한 클립이 없어요.\n크레캠에서 마음에 드는 클립에 ★을 눌러보세요",
  "community_share_next": "다음 — 캡션 작성",
  "community_compose_title": "캡션 작성",
  "community_caption_hint": "이 순간에 대해 들려주세요",
  "community_copy_note": "영상은 커뮤니티 저장소로 복사돼요. 원본 클립을 지워도 게시물은 유지됩니다.",
  "community_pet_unlinked": "크레 미연결 — 탭해서 선택",
  "community_pet_none": "크레 연결 안 함",
  "community_publish": "게시하기",
  "community_publishing": "영상 복사 중 {pct}%",
  "community_publishing_short": "게시 중…",
  "community_publish_error": "게시에 실패했어요. 네트워크를 확인하고 다시 시도해주세요.",
  "community_play_error": "영상을 재생할 수 없어요",
  "community_comments_title": "댓글 {n}",
  "community_comments_empty": "첫 댓글을 남겨보세요",
  "community_comments_error": "댓글을 불러오지 못했어요",
  "community_comment_hint": "댓글을 남겨보세요",
  "common_cancel": "취소",
  "common_delete": "삭제",
  "common_retry": "다시 시도"
}
```

> `common_cancel`/`common_delete`/`common_retry`는 기존 ko.json에 동일 키가 이미 있으면 추가하지 말 것 (`grep '"common_' assets/l10n/ko.json`로 선확인).

- [ ] **Step 3:** 구 키 삭제 — `community_cat_all/notice/wiki/qna/free`, `community_pending_*`, `community_board_title` (grep으로 코드 참조 0 확인 후)
- [ ] **Step 4:** `flutter analyze` → 0, `flutter test -r compact` → PASS
- [ ] **Step 5: Phase 1 완료 커밋 + push**

```bash
git add lib/core/router/app_router.dart assets/l10n/ko.json lib/features/community
git commit -m "feat(community): 재생·글쓰기·댓글 화면 + 라우트·l10n — 클립 피드 MVP 완성"
# pubspec build +1 후 push
git push origin feat/prd-redesign
```

- [ ] **Step 6:** 실기기 검증 시나리오 — ① 게시(즐겨찾기→캡션→진행률→피드 노출) ② 타 계정에서 피드·재생·좋아요·댓글 ③ 내 글 삭제 ④ 계정 전환 시 피드 리셋 ⑤ 오프라인에서 피드 에러 상태
- [ ] **Step 7:** 사용자에게 `/code-review` 실행 요청 (Claude가 대신 실행 불가 — 몰아구현 후 리뷰 규칙)

---

## Phase 2 — 공지 · 신고 · 차단 · 모아보기 · 자동재생

### Task 10: 운영자 공지 배너

**Context:**
- Depends on: Task 0(`community_notices`), Task 5
- Inputs: 공지 작성은 **앱 UI 없음** — 운영자가 Supabase 대시보드에서 INSERT(is_admin 계정). 앱은 읽기 전용 배너
- Outputs: `noticesProvider` + 피드 최상단 배너(최신 1건, 탭하면 본문 다이얼로그)
- Must know: 공지 0건이면 배너 자체를 그리지 않는다(빈 카드 금지)
- Acceptance: 대시보드에서 공지 1건 INSERT → 앱 피드 상단 노출

**Files:**
- Modify: `lib/features/community/presentation/community_providers.dart`, `community_screen.dart`
- Modify: `assets/l10n/ko.json` (`"community_notice_label": "공지"`)

- [ ] **Step 1: provider + 모델(간이 record)**

```dart
// community_providers.dart 에 추가
typedef CommunityNotice = ({String id, String title, String? body});

final latestNoticeProvider =
    FutureProvider.autoDispose<CommunityNotice?>((ref) async {
  final rows = await Supabase.instance.client
      .from('community_notices')
      .select('id, title, body')
      .order('created_at', ascending: false)
      .limit(1);
  final list = rows as List;
  if (list.isEmpty) return null;
  final r = list.first as Map<String, dynamic>;
  return (
    id: r['id'] as String,
    title: r['title'] as String,
    body: r['body'] as String?,
  );
});
```

- [ ] **Step 2: 배너 위젯** — community_screen의 위키 카드 위에

```dart
// community_screen.dart — ListView children 최상단(위키 카드 위)에 추가
Consumer(builder: (context, ref, _) {
  final notice = ref.watch(latestNoticeProvider).valueOrNull;
  if (notice == null) return const SizedBox.shrink();
  final glass = context.glass;
  return Padding(
    padding: const EdgeInsets.fromLTRB(AppStyles.spacing16, 0,
        AppStyles.spacing16, AppStyles.spacing12),
    child: GlassCard(
      padding: const EdgeInsets.all(12),
      child: InkWell(
        onTap: notice.body == null
            ? null
            : () => showDialog<void>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(notice.title),
                    content: Text(notice.body!),
                  ),
                ),
        child: Row(children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
                shape: BoxShape.circle, color: glass.activeTile),
          ),
          const SizedBox(width: 10),
          Text('community_notice_label'.tr(),
              style: glass.labelCaps),
          const SizedBox(width: 8),
          Expanded(
            child: Text(notice.title,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: glass.tileTitle.copyWith(fontSize: 12.5)),
          ),
          Icon(Icons.chevron_right, size: 16, color: glass.textTertiary),
        ]),
      ),
    ),
  );
}),
```

- [ ] **Step 3:** analyze·커밋 `feat(community): 운영자 공지 배너`

### Task 11: 신고 (Apple 1.2 — 스토어 제출 전 필수)

**Context:**
- Depends on: Task 0(`community_reports`), Task 5·8
- Inputs: 게시물 ⋯ 메뉴(타인 글에도 항상 노출로 변경) + 댓글 길게 누르기
- Outputs: 신고 사유 시트(스팸/부적절/동물학대/기타) → `community_reports` INSERT → "접수됨" 스낵바
- Must know: PostCard의 ⋯ 메뉴를 내 글 전용에서 전체 노출로 바꾼다 — 내 글은 [삭제], 타인 글은 [신고]·[차단]. `onDelete` null 분기 대신 `isMine` bool + 콜백 3종(onDelete/onReport/onBlock)으로 시그니처 변경.
- Acceptance: 타 계정 글 신고 → reports에 row, status='open'

**Files:**
- Modify: `lib/features/community/data/community_repository.dart`, `widgets/post_card.dart`, `community_screen.dart`, `widgets/comments_sheet.dart`, `assets/l10n/ko.json`

- [ ] **Step 1: repository 메서드**

```dart
// community_repository.dart 에 추가
  /// 신고 접수. targetKind: 'post' | 'comment'.
  Future<void> report({
    required String targetKind,
    required String targetId,
    required String reason,
    String? detail,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _supabase.from('community_reports').insert({
      'reporter_id': uid,
      'target_kind': targetKind,
      'target_id': targetId,
      'reason': reason,
      'detail': detail,
    });
  }
```

- [ ] **Step 2: 사유 시트 + PostCard 메뉴 개편**

```dart
// post_card.dart — 시그니처 변경
  const PostCard({
    ...기존...
    required this.isMine,
    this.onDelete,
    this.onReport, // (String reason) 선택 후 호출
    this.onBlock,
  });
  final bool isMine;
  final void Function(String reason)? onReport;
  final VoidCallback? onBlock;

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (isMine)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text('community_delete_post'.tr()),
              onTap: () { Navigator.pop(ctx); onDelete?.call(); },
            )
          else ...[
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text('community_report'.tr()),
              onTap: () { Navigator.pop(ctx); _showReportReasons(context); },
            ),
            ListTile(
              leading: const Icon(Icons.block),
              title: Text('community_block_user'.tr()),
              onTap: () { Navigator.pop(ctx); onBlock?.call(); },
            ),
          ],
        ]),
      ),
    );
  }

  void _showReportReasons(BuildContext context) {
    const reasons = ['spam', 'inappropriate', 'animal_abuse', 'other'];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (final r in reasons)
            ListTile(
              title: Text('community_report_$r'.tr()),
              onTap: () { Navigator.pop(ctx); onReport?.call(r); },
            ),
        ]),
      ),
    );
  }
```

- [ ] **Step 3:** community_screen 배선 — `onReport: (reason) async { await ref.read(communityRepositoryProvider).report(targetKind: 'post', targetId: post.id, reason: reason); messenger.showSnackBar(...'community_report_done'.tr()); }` (async gap 전에 `final messenger = ScaffoldMessenger.of(context)` 캡처). ⋯ 아이콘은 항상 노출로 변경.
- [ ] **Step 4:** ko.json — `community_report`(신고), `community_report_spam`(스팸·광고), `community_report_inappropriate`(부적절한 콘텐츠), `community_report_animal_abuse`(동물 학대 의심), `community_report_other`(기타), `community_report_done`(신고가 접수됐어요), `community_block_user`(이 사용자 차단)
- [ ] **Step 5:** analyze·test·커밋 `feat(community): 게시물·댓글 신고 (Apple 1.2)`

### Task 12: 차단

**Context:**
- Depends on: Task 0(`community_blocks`), Task 11(⋯ 메뉴)
- Inputs: 차단 목록은 앱 필터(핸드오프 §3.3 — RLS 서브쿼리는 2차 성능 검토로 보류한 결정)
- Outputs: 차단 INSERT + 피드·댓글에서 차단 유저 숨김 + 프로필 화면 차단 해제 목록
- Must know: 피드 필터는 **repository가 아니라 feed notifier에서** — `_blockedIds`를 build에서 병행 로드하고 `where`로 거른다(페이지네이션 offset은 서버 기준이라 필터 후 화면 개수가 페이지보다 적을 수 있음 — 허용).
- Acceptance: 차단 → 해당 유저 글·댓글 즉시 사라짐, 프로필 > 차단 관리에서 해제 → 복귀

**Files:**
- Modify: `community_repository.dart`, `community_providers.dart`, `widgets/comments_sheet.dart`, `lib/features/profile/presentation/profile_screen.dart`(차단 관리 진입), ko.json

- [ ] **Step 1: repository**

```dart
// community_repository.dart 에 추가
  Future<Set<String>> blockedUserIds() async {
    final uid = _uid;
    if (uid == null) return {};
    try {
      final rows = await _supabase
          .from('community_blocks')
          .select('blocked_id')
          .eq('blocker_id', uid);
      return {
        for (final r in rows as List) (r as Map)['blocked_id'] as String
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> blockUser(String userId) async {
    final uid = _uid;
    if (uid == null) return;
    await _supabase
        .from('community_blocks')
        .upsert({'blocker_id': uid, 'blocked_id': userId});
  }

  Future<void> unblockUser(String userId) async {
    final uid = _uid;
    if (uid == null) return;
    await _supabase
        .from('community_blocks')
        .delete()
        .eq('blocker_id', uid)
        .eq('blocked_id', userId);
  }
```

- [ ] **Step 2: feed notifier 필터** — `build()`에서 `final blocked = await repo.blockedUserIds();` 후 `page.where((p) => !blocked.contains(p.authorId))`, `loadMore()`도 동일 필터. `blockUser(userId)` 액션 메서드 추가(차단 후 `refresh()`). comments_sheet도 `blockedUserIds` FutureProvider로 거른다.
- [ ] **Step 3:** 프로필 화면에 "차단한 사용자" 타일 → 차단 목록 화면(public_profiles로 이름 표시 + 해제 버튼). 라우트 `/profile/blocked`.
- [ ] **Step 4:** ko.json — `community_block_confirm`(이 사용자의 글과 댓글이 보이지 않게 됩니다), `community_blocked_users`(차단한 사용자), `community_unblock`(차단 해제)
- [ ] **Step 5:** analyze·test·커밋 `feat(community): 사용자 차단 + 피드·댓글 필터 (Apple 1.2)`

### Task 13: 유저별 글 모아보기

**Context:**
- Depends on: Task 5
- Inputs: PostCard 작성자 영역 탭 → `/community-user/:userId` (최상위 라우트 — 독 유지가 자연스러우면 shell 하위 `/community/users/:userId`도 가능하나, 일관성 위해 최상위)
- Outputs: `UserPostsScreen` — 해당 유저 게시물 그리드(썸네일 3열) + 상단에 public_profiles 이름·아바타
- Must know: repository에 `listPostsByAuthor(String authorId, {offset, limit})` 추가 — `listPosts`와 같은 쿼리에 `.eq('author_id', authorId)`만 추가(병합 로직 재사용). 그리드 타일 탭 → `/community-player/:postId`.
- Acceptance: 작성자 탭 → 그 유저 글만 그리드로, 재생 진입 정상

**Files:**
- Create: `lib/features/community/presentation/user_posts_screen.dart`
- Modify: `community_repository.dart`, `widgets/post_card.dart`(작성자 행 onTap), `app_router.dart`, ko.json(`community_user_posts_title`: "{name}의 클립")

- [ ] **Step 1:** repository 메서드 — `listPosts` 본문을 `_listPostsQuery({String? authorId})`로 추출해 재사용:

```dart
  Future<List<CommunityPost>> listPostsByAuthor(String authorId,
      {int offset = 0, int limit = 30}) async {
    final rows = await _supabase
        .from('community_posts')
        .select('*, community_likes(count), community_comments(count)')
        .eq('author_id', authorId)
        .order('created_at', ascending: false)
        .range(offset, offset + limit - 1);
    final posts = (rows as List)
        .map((r) => CommunityPost.fromJson(r as Map<String, dynamic>))
        .toList();
    if (posts.isEmpty) return posts;
    final profiles = await _fetchProfiles([authorId]);
    final likes = await _fetchMyLikes(posts.map((p) => p.id).toList());
    return mergeFeedRows(
        posts: posts, profiles: profiles, myLikedPostIds: likes);
  }
```

- [ ] **Step 2:** `UserPostsScreen` — `FutureProvider.family<List<CommunityPost>, String>` + `GridView.builder`(3열, 썸네일 `signedImageUrls` 재사용) + AppBar 제목 `community_user_posts_title`. 코드 구조는 ClipSelectScreen 그리드와 동일 패턴(썸네일 URL만 storage signed로).
- [ ] **Step 3:** PostCard 작성자 Row를 `GestureDetector(onTap: onOpenAuthor)`로 감싸고 screen에서 `context.push('/community-user/${post.authorId}')` 배선. 라우트 등록.
- [ ] **Step 4:** analyze·커밋 `feat(community): 유저별 클립 모아보기`

### Task 14: 피드 자동재생 (후순위 — 나머지 완료 후)

**Context:**
- Depends on: Task 5, Task 9
- Inputs: `visibility_detector` 패키지 신규 도입(패키지 재량 규칙 — 커밋에 도입 사유 기록)
- Outputs: 피드에서 화면 60% 이상 보이는 카드 1개만 muted 자동재생, 나머지는 썸네일
- Must know: **동시 재생 controller는 1개** — `activeAutoplayPostId` StateProvider로 전역 단일화, 카드가 비가시로 전환되면 즉시 dispose(수십 개 controller 누적 = OOM). 재생 URL은 signed URL 캐시(TTL 1h) 재사용. 스크롤 성능이 나빠지면 이 task는 되돌린다(단독 커밋).
- Acceptance: 실기기 스크롤 — 보이는 카드만 재생, 프레임 드랍 없음, 데이터 사용량 이상 없음

**Files:**
- Modify: `pubspec.yaml`(+visibility_detector), `widgets/post_card.dart`, `community_providers.dart`

- [ ] **Step 1:** `flutter pub add visibility_detector`
- [ ] **Step 2:** PostCard 썸네일 Stack을 `VisibilityDetector(key: Key('post-${post.id}'), onVisibilityChanged: ...)`로 감싸고, `info.visibleFraction > 0.6`이면 `ref.read(activeAutoplayPostIdProvider.notifier).state = post.id`, 0.4 미만이면 자기 id일 때 null로. 자기 id가 활성일 때만 내부 `_InlinePlayer`(muted, loop, controls 없음) 마운트 — 아니면 즉시 dispose되는 StatefulWidget.
- [ ] **Step 3:** 프레임 계측(devtools timeline) 후 문제 없으면 **단독 커밋** `feat(community): 피드 자동재생(visibility 기반 단일 컨트롤러)`

### Task 15: 문서 갱신 + 최종 리뷰

**Context:**
- Depends on: Phase 1 완료(최소), Phase 2 진행분
- Inputs: 이 계획서의 실제 구현 결과
- Outputs: SOT 문서 5곳 갱신 + `/code-review` 요청
- Must know: PRD는 SOT — 구현이 끝나면 §4.5를 클립 피드 기획으로 **사용자 승인 하에** 갱신(임의 수정 금지, 초안 제시 → 승인 → 반영)
- Acceptance: 문서-코드 불일치 0 (doc-sync 스킬 기준)

- [ ] **Step 1:** `docs/prd-vivnanaut-app.md` §4.5 개정 초안 제시 → 사용자 승인 → 반영
- [ ] **Step 2:** `docs/prd-implementation-gap.md` 커뮤니티 항목 갱신 (🟡 위키만 실물 → 구현 현황)
- [ ] **Step 3:** `CLAUDE.md` 탭 테이블의 커뮤니티 행 갱신 (로컬 seed 하드코딩 경고 제거 → 클립 피드 + community_* 테이블)
- [ ] **Step 4:** `docs/supabase-setup.md` RLS 표에 community 정책 추가
- [ ] **Step 5:** 커밋 `docs: 커뮤니티 클립 피드 반영 — PRD·대조표·CLAUDE.md·supabase 문서` + push
- [ ] **Step 6:** 사용자에게 **`/code-review` 실행 요청** — 특히 계정 격리(3층)·controller 누수·RLS 우회 여부 관점

---

## Self-Review 결과 (작성 시점)

1. **Spec coverage**: 확정 시안 ①~⑤ ↔ Task 5(피드)·7(선택+날짜시각/캡션)·8(댓글)·6(재생)·다크는 GlassPalette 자동. 2차 4종 ↔ Task 10~14. 핸드오프 §3 ↔ Task 0. Apple 1.2 ↔ Task 11~12. 누락 없음.
2. **Placeholder scan**: Task 12 Step 2·Task 13 Step 2·Task 14 Step 2는 수정 지시가 산문이지만 대상 파일·조건값·상태 흐름을 수치로 명시 — 실행 모호성 없음 판단. 나머지는 전부 실코드.
3. **Type consistency**: `petTagLabel`(T1↔T7), `ComposeDraft`(T7↔T9), `mergeFeedRows`(T2 테스트↔구현), `setLike`(T2↔T4 toggleLike 내부 호출), `favoriteClipRepositoryProvider`(T4↔T7), `PostCard` 시그니처는 T11에서 의도적 변경(명시됨). 일치 확인.

**리스크 메모**: ① `createSignedUrls`의 응답 필드(`path` nullable)는 supabase_flutter 버전에 따라 다를 수 있음 — 구현 시 실제 타입 확인. ② `AccountAvatar`에 `size` 파라미터가 없으면 기존 시그니처에 맞춰 조정. ③ `enclosureSetsProvider`의 camera 필드명(`camera?.id`)은 `EnclosureSet` 실물 기준 — 구현 시 재확인. 이 3건은 컴파일 시점에 드러나는 수준이라 계획 리스크 낮음.
