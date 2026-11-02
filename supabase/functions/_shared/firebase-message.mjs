// 높은 중요도 채널(vivanaut_safety)을 쓰는 알림. 앱 로컬 표시도 같은 규칙
// (lib/features/notification/domain/app_notification.dart usesSafetyChannel).
export function usesSafetyChannel(kind) {
  const value = String(kind);
  return value.startsWith('safety.') || value === 'env.alert.triggered';
}

export function buildFirebaseMessage({
  token,
  notificationId,
  kind,
  title,
  body,
  route,
}) {
  return {
    message: {
      token: String(token),
      notification: {
        title: String(title),
        body: String(body),
      },
      data: {
        notification_id: String(notificationId),
        kind: String(kind),
        route: String(route),
      },
      android: {
        priority: 'high',
        notification: {
          channel_id: usesSafetyChannel(kind)
            ? 'vivanaut_safety'
            : 'vivanaut_default',
        },
      },
    },
  };
}

const maxRetryDelaySeconds = 60 * 60;
const maxDeliveryAttempts = 8;

export function canRetryDelivery(attempts) {
  return Number.isInteger(attempts) && attempts < maxDeliveryAttempts;
}

export function extractFcmFailure(payload) {
  const error = payload?.error;
  const details = Array.isArray(error?.details) ? error.details : [];
  const fcmDetail = details.find((detail) => (
    detail?.['@type'] === 'type.googleapis.com/google.firebase.fcm.v1.FcmError'
      && typeof detail.errorCode === 'string'
  ));
  return {
    status: typeof error?.status === 'string' ? error.status : undefined,
    fcmErrorCode: fcmDetail?.errorCode,
  };
}

export function classifyFcmFailure(status, failure = {}) {
  if (failure?.fcmErrorCode === 'UNREGISTERED' || failure?.fcmErrorCode === 'INVALID_ARGUMENT') {
    return 'disable-token';
  }
  if (status === 429 || status >= 500) {
    return 'retry';
  }
  if (status >= 400 && status < 500) {
    return 'fail';
  }
  return 'retry';
}

export function retryDelaySeconds(attempts, retryAfterSeconds = 0, status = 0) {
  const exponential = Math.min(
    maxRetryDelaySeconds,
    30 * (2 ** Math.max(0, attempts - 1)),
  );
  const firstQuotaRetry = attempts <= 1 && (status === 429 || status === 503) ? 60 : 0;
  const retryAfter = Number.isFinite(retryAfterSeconds) && retryAfterSeconds > 0
    ? Math.ceil(retryAfterSeconds)
    : 0;
  return Math.max(exponential, firstQuotaRetry, retryAfter);
}
