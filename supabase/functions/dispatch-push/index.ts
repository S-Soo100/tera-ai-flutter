import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { buildFirebaseMessage, classifyFcmFailure } from '../_shared/firebase-message.mjs';

const firebaseScope = 'https://www.googleapis.com/auth/firebase.messaging';
const firebaseTokenUrl = 'https://oauth2.googleapis.com/token';
const firebaseProjectId = 'vivanaut-app';
const claimLimit = 25;
const maxRetryDelaySeconds = 60 * 60;
const jsonHeaders = { 'content-type': 'application/json; charset=utf-8' };

type ServiceAccount = {
  client_email: string;
  private_key: string;
};

type ClaimedOutboxRow = {
  id: string;
  notification_id: string;
  user_id: string;
  attempts: number;
  kind: string;
  title: string;
  body: string;
  route: string;
};

type PushDevice = {
  id: string;
  fcm_token: string;
};

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

function base64Url(value: Uint8Array | string) {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll('+', '-').replaceAll('/', '_').replace(/=+$/, '');
}

function privateKeyBytes(pem: string) {
  const base64 = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s/g, '');
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

async function firebaseAccessToken(account: ServiceAccount) {
  const issuedAt = Math.floor(Date.now() / 1000);
  const unsignedToken = [
    base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' })),
    base64Url(JSON.stringify({
      iss: account.client_email,
      scope: firebaseScope,
      aud: firebaseTokenUrl,
      iat: issuedAt,
      exp: issuedAt + 60 * 60,
    })),
  ].join('.');
  const key = await crypto.subtle.importKey(
    'pkcs8',
    privateKeyBytes(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsignedToken),
  ));
  const assertion = `${unsignedToken}.${base64Url(signature)}`;
  const tokenResponse = await fetch(firebaseTokenUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!tokenResponse.ok) {
    throw new Error('firebase_oauth_failed');
  }
  const token = await tokenResponse.json();
  if (typeof token.access_token !== 'string' || token.access_token.length === 0) {
    throw new Error('firebase_oauth_invalid_response');
  }
  return token.access_token;
}

function safeErrorCode(status: number, code: unknown) {
  const normalizedCode = typeof code === 'string' && /^[A-Z_]{1,64}$/.test(code)
    ? code.toLowerCase()
    : `http_${status}`;
  return `fcm_${normalizedCode}`;
}

function retryDelaySeconds(attempts: number) {
  return Math.min(maxRetryDelaySeconds, 30 * (2 ** Math.max(0, attempts - 1)));
}

async function sendFirebaseMessage(accessToken: string, message: unknown) {
  const sendResponse = await fetch(
    `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
    {
      method: 'POST',
      headers: {
        authorization: `Bearer ${accessToken}`,
        'content-type': 'application/json',
      },
      body: JSON.stringify(message),
    },
  );
  if (sendResponse.ok) return { ok: true as const };

  let code: unknown;
  try {
    const payload = await sendResponse.json();
    code = payload?.error?.status;
  } catch (_) {
    // The HTTP status still determines a safe dispatcher decision.
  }
  return {
    ok: false as const,
    status: sendResponse.status,
    code,
  };
}

async function markOutbox(
  client: ReturnType<typeof createClient>,
  row: ClaimedOutboxRow,
  state: 'sent' | 'failed' | 'pending',
  errorCode?: string,
) {
  const updates: Record<string, unknown> = {
    status: state,
    updated_at: new Date().toISOString(),
    locked_at: null,
    last_error: errorCode ?? null,
  };
  if (state === 'sent') updates.sent_at = new Date().toISOString();
  if (state === 'pending') {
    updates.scheduled_at = new Date(Date.now() + retryDelaySeconds(row.attempts) * 1000).toISOString();
  }
  const { error } = await client.from('notification_outbox').update(updates).eq('id', row.id);
  if (error) throw new Error('outbox_update_failed');
}

async function dispatchRow(
  client: ReturnType<typeof createClient>,
  accessToken: string,
  row: ClaimedOutboxRow,
) {
  const { data, error } = await client
    .from('push_devices')
    .select('id, fcm_token')
    .eq('user_id', row.user_id)
    .eq('enabled', true);
  if (error) throw new Error('push_device_lookup_failed');
  const devices = (data ?? []) as PushDevice[];
  let shouldRetry = false;
  let shouldFail = false;
  let errorCode: string | undefined;

  for (const device of devices) {
    const result = await sendFirebaseMessage(accessToken, buildFirebaseMessage({
      token: device.fcm_token,
      notificationId: row.notification_id,
      kind: row.kind,
      title: row.title,
      body: row.body,
      route: row.route,
    }));
    if (result.ok) continue;

    const outcome = classifyFcmFailure(result.status, result.code);
    errorCode ??= safeErrorCode(result.status, result.code);
    if (outcome === 'disable-token') {
      const { error: disableError } = await client
        .from('push_devices')
        .update({ enabled: false, updated_at: new Date().toISOString() })
        .eq('id', device.id);
      if (disableError) throw new Error('push_device_disable_failed');
    } else if (outcome === 'retry') {
      shouldRetry = true;
    } else {
      shouldFail = true;
    }
  }

  if (shouldRetry) return markOutbox(client, row, 'pending', errorCode);
  if (shouldFail) return markOutbox(client, row, 'failed', errorCode);
  return markOutbox(client, row, 'sent');
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return response(400, { error: 'POST is required' });

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!supabaseUrl || !serviceRoleKey || !serviceAccountJson) {
    console.error('push dispatcher is missing required configuration');
    return response(500, { error: 'push dispatcher is unavailable' });
  }

  let serviceAccount: ServiceAccount;
  try {
    serviceAccount = JSON.parse(serviceAccountJson) as ServiceAccount;
    if (!serviceAccount.client_email || !serviceAccount.private_key) throw new Error('invalid');
  } catch (_) {
    console.error('push dispatcher has invalid Firebase configuration');
    return response(500, { error: 'push dispatcher is unavailable' });
  }

  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let accessToken: string;
  try {
    accessToken = await firebaseAccessToken(serviceAccount);
  } catch (_) {
    console.error('push dispatcher could not obtain Firebase access');
    return response(502, { error: 'push dispatcher is unavailable' });
  }

  const { data, error } = await client.rpc('claim_notification_outbox', { p_limit: claimLimit });
  if (error) {
    console.error('push dispatcher could not claim outbox rows', { code: error.code });
    return response(500, { error: 'push dispatcher is unavailable' });
  }

  let processed = 0;
  for (const row of (data ?? []) as ClaimedOutboxRow[]) {
    try {
      await dispatchRow(client, accessToken, row);
      processed += 1;
    } catch (_) {
      try {
        await markOutbox(client, row, 'pending', 'dispatcher_error');
      } catch (_) {
        console.error('push dispatcher could not restore an outbox row');
      }
    }
  }
  return response(200, { processed });
});
