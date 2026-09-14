import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import {
  buildFirebaseMessage,
  canRetryDelivery,
  classifyFcmFailure,
  extractFcmFailure,
  retryDelaySeconds,
} from '../_shared/firebase-message.mjs';
import {
  isSecretKeyRequest,
  secretKeyFromEnvironment,
} from '../_shared/dispatch-push-auth.mjs';

const firebaseScope = 'https://www.googleapis.com/auth/firebase.messaging';
const firebaseTokenUrl = 'https://oauth2.googleapis.com/token';
const firebaseProjectId = 'vivanaut-app';
const dispatchSecretKeyName = 'dispatch_push';
const deliveryClaimLimit = 10;
const maxOutboxRows = 10;
const maxFcmSends = 10;
const invocationBudgetMs = 180_000;
const requestTimeoutMs = 15_000;
const jsonHeaders = { 'content-type': 'application/json; charset=utf-8' };

type ServiceAccount = { client_email: string; private_key: string };
type ClaimedOutboxRow = {
  id: string;
  notification_id: string;
  user_id: string;
  attempts: number;
  lock_token: string;
  kind: string;
  title: string;
  body: string;
  route: string;
};
type ClaimedDelivery = {
  id: string;
  push_device_id: string;
  attempts: number;
  lock_token: string;
};

type SendBudget = { sends: number };
type DeliveryToken = { fcm_token: string };

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
  for (let index = 0; index < binary.length; index += 1) bytes[index] = binary.charCodeAt(index);
  return bytes.buffer;
}

async function withTimeout<T>(operation: (signal: AbortSignal) => PromiseLike<T>) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), requestTimeoutMs);
  try {
    return await operation(controller.signal);
  } finally {
    clearTimeout(timeout);
  }
}

async function fetchWithTimeout<T>(
  url: string,
  init: RequestInit,
  consume: (response: Response) => Promise<T>,
) {
  return withTimeout(async (signal) => {
    const response = await fetch(url, { ...init, signal });
    return await consume(response);
  });
}

function retryAfterSeconds(value: string | null) {
  if (!value) return 0;
  const seconds = Number(value);
  if (Number.isFinite(seconds) && seconds >= 0) return seconds;
  const retryAt = Date.parse(value);
  return Number.isNaN(retryAt) ? 0 : Math.max(0, (retryAt - Date.now()) / 1000);
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
    'pkcs8', privateKeyBytes(account.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'],
  );
  const signature = new Uint8Array(await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5', key, new TextEncoder().encode(unsignedToken),
  ));
  const token = await fetchWithTimeout(firebaseTokenUrl, {
    method: 'POST',
    headers: { 'content-type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsignedToken}.${base64Url(signature)}`,
    }),
  }, async (tokenResponse) => {
    if (!tokenResponse.ok) throw new Error('firebase_oauth_failed');
    return tokenResponse.json();
  });
  if (typeof token.access_token !== 'string' || token.access_token.length === 0) {
    throw new Error('firebase_oauth_invalid_response');
  }
  return token.access_token;
}

function safeErrorCode(status: number, failure: { status?: string; fcmErrorCode?: string }) {
  const code = failure.fcmErrorCode ?? failure.status;
  const normalized = typeof code === 'string' && /^[A-Z_]{1,64}$/.test(code)
    ? code.toLowerCase()
    : `http_${status}`;
  return `fcm_${normalized}`;
}

async function sendFirebaseMessage(accessToken: string, message: unknown) {
  return fetchWithTimeout(
    `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`,
    {
      method: 'POST',
      headers: { authorization: `Bearer ${accessToken}`, 'content-type': 'application/json' },
      body: JSON.stringify(message),
    }, async (sendResponse) => {
      if (sendResponse.ok) {
        await sendResponse.json();
        return { ok: true as const };
      }

      let failure = {};
      try {
        failure = extractFcmFailure(await sendResponse.json());
      } catch (_) {
        // The HTTP status remains sufficient for a safe retry/failure decision.
      }
      return {
        ok: false as const,
        status: sendResponse.status,
        failure,
        retryAfterSeconds: retryAfterSeconds(sendResponse.headers.get('retry-after')),
      };
    },
  );
}

async function completeDelivery(
  client: ReturnType<typeof createClient>,
  delivery: ClaimedDelivery,
  status: 'pending' | 'sent' | 'failed' | 'cancelled',
  scheduledAt: string | null,
  errorCode: string | null,
) {
  const { error } = await withTimeout((signal) => client.rpc('complete_notification_delivery', {
    p_delivery_id: delivery.id,
    p_lock_token: delivery.lock_token,
    p_status: status,
    p_scheduled_at: scheduledAt,
    p_last_error: errorCode,
  }).abortSignal(signal));
  if (error) throw new Error('delivery_update_failed');
}

async function eligibleDeliveryToken(
  client: ReturnType<typeof createClient>,
  row: ClaimedOutboxRow,
  delivery: ClaimedDelivery,
) {
  const { data, error } = await withTimeout((signal) => client.rpc('get_notification_delivery_token', {
    p_delivery_id: delivery.id,
    p_delivery_lock_token: delivery.lock_token,
    p_outbox_lock_token: row.lock_token,
  }).abortSignal(signal));
  if (error) throw new Error('delivery_eligibility_failed');
  return ((data ?? []) as DeliveryToken[])[0]?.fcm_token;
}

async function dispatchRow(
  client: ReturnType<typeof createClient>,
  accessToken: string,
  row: ClaimedOutboxRow,
  budget: SendBudget,
  deadline: number,
) {
  const remainingSends = maxFcmSends - budget.sends;
  if (remainingSends <= 0) return 0;
  const { data, error } = await withTimeout((signal) => client.rpc('claim_notification_deliveries', {
    p_outbox_id: row.id,
    p_lock_token: row.lock_token,
    p_limit: Math.min(deliveryClaimLimit, remainingSends),
  }).abortSignal(signal));
  if (error) throw new Error('delivery_claim_failed');

  for (const delivery of (data ?? []) as ClaimedDelivery[]) {
    if (!canRetryDelivery(delivery.attempts)) {
      await completeDelivery(client, delivery, 'failed', null, 'retry_exhausted');
      continue;
    }
    if (Date.now() >= deadline || budget.sends >= maxFcmSends) {
      await completeDelivery(
        client, delivery, 'pending', new Date().toISOString(), 'budget_exhausted',
      );
      continue;
    }
    try {
      const token = await eligibleDeliveryToken(client, row, delivery);
      if (!token) {
        await completeDelivery(client, delivery, 'cancelled', null, 'delivery_ineligible');
        continue;
      }
      budget.sends += 1;
      const result = await sendFirebaseMessage(accessToken, buildFirebaseMessage({
        token,
        notificationId: row.notification_id,
        kind: row.kind,
        title: row.title,
        body: row.body,
        route: row.route,
      }));
      if (result.ok) {
        await completeDelivery(client, delivery, 'sent', null, null);
        continue;
      }

      const outcome = classifyFcmFailure(result.status, result.failure);
      const errorCode = safeErrorCode(result.status, result.failure);
      if (outcome === 'disable-token') {
        const { error: disableError } = await withTimeout((signal) => client
          .from('push_devices')
          .update({ enabled: false, updated_at: new Date().toISOString() })
          .eq('id', delivery.push_device_id)
          .eq('fcm_token', token)
          .abortSignal(signal));
        if (disableError) throw new Error('push_device_disable_failed');
        await completeDelivery(client, delivery, 'failed', null, errorCode);
      } else if (outcome === 'retry') {
        const delay = retryDelaySeconds(delivery.attempts, result.retryAfterSeconds, result.status);
        await completeDelivery(
          client, delivery, 'pending',
          new Date(Date.now() + delay * 1000).toISOString(), errorCode,
        );
      } else {
        await completeDelivery(client, delivery, 'failed', null, errorCode);
      }
    } catch (_) {
      const delay = retryDelaySeconds(delivery.attempts);
      await completeDelivery(
        client, delivery, 'pending',
        new Date(Date.now() + delay * 1000).toISOString(), 'dispatcher_error',
      );
    }
  }

  const { error: finalizeError } = await withTimeout((signal) => client.rpc('finalize_notification_outbox', {
    p_outbox_id: row.id,
    p_lock_token: row.lock_token,
  }).abortSignal(signal));
  if (finalizeError) throw new Error('outbox_finalize_failed');
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') return response(400, { error: 'POST is required' });
  const deadline = Date.now() + invocationBudgetMs;

  const secretKey = secretKeyFromEnvironment(
    Deno.env.get('SUPABASE_SECRET_KEYS'),
    dispatchSecretKeyName,
  );
  if (!secretKey || !isSecretKeyRequest(request.headers, secretKey)) {
    return response(401, { error: 'unauthorized' });
  }
  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceAccountJson = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
  if (!supabaseUrl || !serviceAccountJson) {
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

  const client = createClient(supabaseUrl, secretKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  let accessToken: string;
  try {
    accessToken = await firebaseAccessToken(serviceAccount);
  } catch (_) {
    console.error('push dispatcher could not obtain Firebase access');
    return response(502, { error: 'push dispatcher is unavailable' });
  }

  let processed = 0;
  const budget: SendBudget = { sends: 0 };
  for (
    let outboxCount = 0;
    outboxCount < maxOutboxRows && budget.sends < maxFcmSends && Date.now() < deadline;
    outboxCount += 1
  ) {
    const { data, error } = await withTimeout((signal) => client
      .rpc('claim_notification_outbox', { p_limit: 1 })
      .abortSignal(signal));
    if (error) {
      console.error('push dispatcher could not claim outbox rows', { code: error.code });
      return response(500, { error: 'push dispatcher is unavailable' });
    }
    const row = (data ?? []) as ClaimedOutboxRow[];
    if (row.length === 0) break;
    try {
      await dispatchRow(client, accessToken, row[0], budget, deadline);
      processed += 1;
    } catch (_) {
      // A stale fence is deliberately left for lease recovery; no older worker
      // can overwrite a newer claim's state.
      console.error('push dispatcher could not finish an outbox row');
    }
  }
  return response(200, { processed, sends: budget.sends });
});
