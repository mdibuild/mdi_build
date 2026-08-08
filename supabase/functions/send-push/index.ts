// Point d'entrée générique des notifications push : appelé server-to-server
// par les triggers Postgres (achats, messagerie) avec la clé service_role en
// Authorization — jamais exposé aux clients de l'app.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { loadServiceAccount, sendToToken } from '../_shared/fcm.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const authHeader = req.headers.get('Authorization') ?? '';

    if (authHeader.replace('Bearer ', '') !== serviceRoleKey) {
      return json({ error: 'Non autorisé.' }, 401);
    }

    const body = await req.json();
    const userIds: string[] = Array.isArray(body.userIds) ? body.userIds : [];
    const title = (body.title ?? '').toString();
    const message = (body.body ?? '').toString();
    const data = body.data ?? {};

    if (userIds.length === 0 || !title || !message) {
      return json({ error: 'Champs manquants.' }, 400);
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      serviceRoleKey,
    );

    const { data: tokens, error } = await admin
      .from('device_tokens')
      .select('id, fcm_token')
      .in('profile_id', userIds);

    if (error) {
      return json({ error: error.message }, 500);
    }

    const serviceAccount = loadServiceAccount();
    let sent = 0;
    let removed = 0;

    for (const row of tokens ?? []) {
      const ok = await sendToToken(serviceAccount, row.fcm_token, {
        title,
        body: message,
        data,
      });

      if (ok) {
        sent++;
      } else {
        removed++;
        await admin.from('device_tokens').delete().eq('id', row.id);
      }
    }

    return json({ sent, removed });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
