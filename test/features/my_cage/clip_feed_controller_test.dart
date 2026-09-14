import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:vivnanaut/features/my_cage/domain/motion_clip.dart';
import 'package:vivnanaut/features/my_cage/domain/motion_clip_page.dart';
import 'package:vivnanaut/features/my_cage/presentation/clip_feed_controller.dart';

MotionClip clip(String id) => MotionClip(id:id,cameraId:'c',startedAt:DateTime.utc(2026,9,12),durationSec:8);
MotionClipPage page(List<String> ids, {bool more=false}) => (
  items:ids.map(clip).toList(),hasMore:more,
  nextCursor:more ? (startedAt:clip(ids.last).startedAt,id:ids.last) : null);
void main() {
  test('추가 로드 중 기존 항목 유지·중복 요청 방지·ID 중복 제거', () async {
    final pending=Completer<MotionClipPage>(); var calls=0;
    final controller=ClipFeedController((cursor) async {
      calls++; return cursor==null ? page(['3','2'],more:true) : pending.future;
    });
    addTearDown(controller.dispose);
    await controller.refresh();
    final load=controller.loadMore();
    await controller.loadMore();
    expect(calls,2);
    expect(controller.state.items.map((c)=>c.id),['3','2']);
    expect(controller.state.loadingMore,true);
    pending.complete(page(['2','1'])); await load;
    expect(controller.state.items.map((c)=>c.id),['3','2','1']);
    await controller.loadMore(); expect(calls,2);
  });
  test('갱신 실패에도 이전 목록을 유지하고 다시 시도할 수 있다', () async {
    var calls=0;
    final controller=ClipFeedController((cursor) async {
      if (++calls==2) throw StateError('offline');
      return page(['1']);
    });
    addTearDown(controller.dispose);
    await controller.refresh(); await controller.refresh();
    expect(controller.state.items.map((c)=>c.id),['1']);
    expect(controller.state.pageError,isNotNull);
    await controller.refresh(); expect(controller.state.pageError,isNull);
  });
  test('갱신 이전에 시작한 추가 페이지 응답은 새 목록에 섞이지 않는다', () async {
    final pending=Completer<MotionClipPage>(); var initial=0;
    final controller=ClipFeedController((cursor) async {
      if(cursor!=null) return pending.future;
      return ++initial==1 ? page(['old'],more:true) : page(['new']);
    });
    addTearDown(controller.dispose);
    await controller.refresh(); final old=controller.loadMore();
    await controller.refresh(); pending.complete(page(['late'])); await old;
    expect(controller.state.items.map((c)=>c.id),['new']);
  });
  test('화면/계정 수명 종료 후 완료된 응답을 적용하지 않는다', () async {
    final pending=Completer<MotionClipPage>();
    final controller=ClipFeedController((cursor)=>pending.future);
    final load=controller.refresh(); controller.dispose();
    pending.complete(page(['late'])); await load;
  });
}
