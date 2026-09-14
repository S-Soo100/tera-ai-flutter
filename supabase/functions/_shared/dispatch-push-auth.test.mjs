import test from 'node:test';
import assert from 'node:assert/strict';
import {
  isSecretKeyRequest,
  secretKeyFromEnvironment,
} from './dispatch-push-auth.mjs';

test('accepts only the exact secret key in the apikey header', () => {
  const headers = new Headers({ apikey: 'sb_secret_dispatch' });
  assert.equal(isSecretKeyRequest(headers, 'sb_secret_dispatch'), true);
  assert.equal(isSecretKeyRequest(headers, 'sb_secret_other'), false);
  assert.equal(isSecretKeyRequest(new Headers(), 'sb_secret_dispatch'), false);
  assert.equal(isSecretKeyRequest(headers, ''), false);
});

test('does not accept a secret key sent as bearer authorization', () => {
  const headers = new Headers({ authorization: 'Bearer sb_secret_dispatch' });
  assert.equal(isSecretKeyRequest(headers, 'sb_secret_dispatch'), false);
});

test('reads the named secret key from the Supabase environment map', () => {
  const environment = JSON.stringify({
    default: 'sb_secret_default',
    dispatch_push: 'sb_secret_dispatch',
  });
  assert.equal(
    secretKeyFromEnvironment(environment, 'dispatch_push'),
    'sb_secret_dispatch',
  );
});

test('rejects missing or malformed Supabase secret-key environments', () => {
  assert.equal(secretKeyFromEnvironment(undefined, 'default'), null);
  assert.equal(secretKeyFromEnvironment('{not-json', 'default'), null);
  assert.equal(secretKeyFromEnvironment('{}', 'default'), null);
  assert.equal(secretKeyFromEnvironment('{"default":42}', 'default'), null);
});
