import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { validateNotificationEvent } from '../_shared/notification-contract.mjs';

const jsonHeaders = { 'content-type': 'application/json; charset=utf-8' };

function response(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: jsonHeaders });
}

Deno.serve(async (request) => {
  if (request.method !== 'POST') {
    return response(400, { error: 'POST is required' });
  }

  const ingestSecret = Deno.env.get('PUSH_EVENT_INGEST_SECRET');
  if (!ingestSecret || request.headers.get('Authorization') !== `Bearer ${ingestSecret}`) {
    return response(401, { error: 'unauthorized' });
  }

  let body: unknown;
  try {
    body = await request.json();
  } catch (_) {
    return response(400, { error: 'request body must be JSON' });
  }

  const validation = validateNotificationEvent(body);
  if (!validation.ok) {
    return response(validation.status, { error: validation.error });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !serviceRoleKey) {
    console.error('notification ingest is missing Supabase service credentials');
    return response(500, { error: 'notification ingest is unavailable' });
  }

  const event = validation.value;
  const client = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { error } = await client.from('notification_events').insert({
    source: 'external',
    source_event_id: event.event_id,
    user_id: event.user_id,
    type: event.type,
    occurred_at: event.occurred_at,
    payload: event.payload,
  });

  if (error?.code === '23505') {
    return response(202, { accepted: true, duplicate: true });
  }
  if (error) {
    console.error('notification ingest insert failed', { code: error.code, message: error.message });
    return response(500, { error: 'notification ingest is unavailable' });
  }
  return response(202, { accepted: true, duplicate: false });
});
