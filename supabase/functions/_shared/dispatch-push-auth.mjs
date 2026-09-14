export function isServiceRoleRequest(headers, serviceRoleKey) {
  if (typeof serviceRoleKey !== 'string' || serviceRoleKey.length === 0) return false;
  return headers.get('authorization') === `Bearer ${serviceRoleKey}`;
}
