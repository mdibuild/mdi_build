// Point d'entrée notifications push déclenché par le client authentifié
// (chat, achats...). Contrairement à send-push (clé service_role uniquement,
// jamais exposée au client), cette fonction vérifie l'appelant via son propre
// token de session, calcule les destinataires et respecte les préférences
// par module de chacun avant d'envoyer.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { loadServiceAccount, sendToToken } from '../_shared/fcm.ts';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const VALID_MODULES = ['planning', 'chat', 'achats'];

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
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'Non authentifié.' }, 401);
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const admin = createClient(supabaseUrl, serviceRoleKey);

    const { data: callerAuth, error: callerAuthError } =
      await admin.auth.getUser(authHeader.replace('Bearer ', ''));

    if (callerAuthError || !callerAuth.user) {
      return json({ error: 'Session invalide.' }, 401);
    }

    const body = await req.json();
    const companyId = (body.companyId ?? '').trim();
    const module = (body.module ?? '').trim();
    const title = (body.title ?? '').trim();
    const message = (body.body ?? '').trim();
    const data = body.data ?? {};
    const recipientProfileId = (body.recipientProfileId ?? '').trim() || null;

    if (!companyId || !VALID_MODULES.includes(module) || !title || !message) {
      return json({ error: 'Champs manquants ou invalides.' }, 400);
    }

    let targetIds: string[];

    if (recipientProfileId) {
      const { data: recipient } = await admin
        .from('profiles')
        .select('id')
        .eq('id', recipientProfileId)
        .eq('company_id', companyId)
        .maybeSingle();

      targetIds = recipient ? [recipient.id as string] : [];
    } else {
      const { data: profiles, error: profilesError } = await admin
        .from('profiles')
        .select('id')
        .eq('company_id', companyId)
        .neq('id', callerAuth.user.id);

      if (profilesError) {
        return json({ error: profilesError.message }, 500);
      }

      targetIds = (profiles ?? []).map((row) => row.id as string);
    }

    if (targetIds.length === 0) {
      return json({ sent: 0, skipped: 0 });
    }

    const { data: prefs } = await admin
      .from('notification_preferences')
      .select('profile_id, enabled')
      .eq('module', module)
      .in('profile_id', targetIds);

    const disabled = new Set(
      (prefs ?? [])
        .filter((row) => row.enabled === false)
        .map((row) => row.profile_id as string),
    );

    const finalTargetIds = targetIds.filter((id) => !disabled.has(id));
    const skipped = targetIds.length - finalTargetIds.length;

    if (finalTargetIds.length === 0) {
      return json({ sent: 0, skipped });
    }

    const { data: tokens, error: tokensError } = await admin
      .from('device_tokens')
      .select('id, fcm_token')
      .in('profile_id', finalTargetIds);

    if (tokensError) {
      return json({ error: tokensError.message }, 500);
    }

    const serviceAccount = loadServiceAccount();
    let sent = 0;

    for (const row of tokens ?? []) {
      const ok = await sendToToken(serviceAccount, row.fcm_token, {
        title,
        body: message,
        data: { type: module, ...data },
      });

      if (ok) {
        sent++;
      } else {
        await admin.from('device_tokens').delete().eq('id', row.id);
      }
    }

    return json({ sent, skipped });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
