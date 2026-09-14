export function secretKeyFromEnvironment(environment, name) {
  if (typeof environment !== 'string' || environment.length === 0) return null;
  try {
    const value = JSON.parse(environment)?.[name];
    return typeof value === 'string' && value.length > 0 ? value : null;
  } catch (_) {
    return null;
  }
}

export function isSecretKeyRequest(headers, secretKey) {
  if (typeof secretKey !== 'string' || secretKey.length === 0) return false;
  return headers.get('apikey') === secretKey;
}
