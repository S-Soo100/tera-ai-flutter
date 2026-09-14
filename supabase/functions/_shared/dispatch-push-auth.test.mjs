import test from 'node:test';
import assert from 'node:assert/strict';
import { isServiceRoleRequest } from './dispatch-push-auth.mjs';

test('accepts only the exact service-role bearer credential', () => {
  const headers = new Headers({ authorization: 'Bearer service-role-secret' });
  assert.equal(isServiceRoleRequest(headers, 'service-role-secret'), true);
  assert.equal(isServiceRoleRequest(headers, 'different-secret'), false);
  assert.equal(isServiceRoleRequest(new Headers(), 'service-role-secret'), false);
  assert.equal(isServiceRoleRequest(headers, ''), false);
});
