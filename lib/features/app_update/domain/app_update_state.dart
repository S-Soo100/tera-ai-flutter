import 'package:flutter/foundation.dart';

import 'update_policy.dart';

/// 복귀(resume) 때 다시 확인하는 간격 — 강제 상태가 아닐 때만(§1-D).
/// 강제 상태면 복귀마다 확인한다(운영자가 잘못 올린 값을 되돌리면 바로 풀리게).
const kUpdateRecheckInterval = Duration(hours: 6);

/// 업데이트 안내 상태.
@immutable
class AppUpdateState {
  const AppUpdateState(
      {this.status = AppUpdateStatus.none, this.policy, this.lastCheckedAt});

  final AppUpdateStatus status;

  /// 마지막으로 성공해 읽은 정책(버전 표시·스토어 주소). 없으면 null.
  final UpdatePolicy? policy;

  /// 마지막 **성공** 확인 시각. 조회 실패는 바꾸지 않는다.
  final DateTime? lastCheckedAt;

  bool get isRequired => status == AppUpdateStatus.required;

  AppUpdateState copyWith({AppUpdateStatus? status}) => AppUpdateState(
      status: status ?? this.status,
      policy: policy,
      lastCheckedAt: lastCheckedAt);
}
