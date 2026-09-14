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
          channel_id: String(kind).startsWith('safety.')
            ? 'vivanaut_safety'
            : 'vivanaut_default',
        },
      },
    },
  };
}

export function classifyFcmFailure(status, code) {
  if (code === 'UNREGISTERED' || code === 'INVALID_ARGUMENT') {
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
