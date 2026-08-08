// Fonction serveur : création d'utilisateurs et réinitialisation de mot de
// passe pour l'équipe d'une entreprise. Tourne avec la clé service_role
// (jamais exposée au client) — seul un appelant authentifié dont le profil a
// le rôle "directeur" peut déclencher ces actions.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

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

    const { data: callerProfile, error: callerProfileError } = await admin
      .from('profiles')
      .select('id, company_id, role')
      .eq('id', callerAuth.user.id)
      .single();

    if (callerProfileError || !callerProfile) {
      return json({ error: 'Profil administrateur introuvable.' }, 403);
    }

    if (callerProfile.role !== 'directeur') {
      return json(
        { error: 'Seul un directeur peut gérer les utilisateurs.' },
        403,
      );
    }

    const body = await req.json();

    if (body.action === 'create') {
      const email = (body.email ?? '').trim();
      const password = (body.password ?? '').trim();
      const fullName = (body.fullName ?? '').trim();
      const role = (body.role ?? '').trim();

      if (!email || !password || !fullName || !role) {
        return json({ error: 'Champs manquants.' }, 400);
      }

      const { data: created, error: createError } =
        await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: true,
        });

      if (createError || !created.user) {
        return json(
          { error: createError?.message ?? 'Création impossible.' },
          400,
        );
      }

      const { error: profileError } = await admin.from('profiles').insert({
        id: created.user.id,
        company_id: callerProfile.company_id,
        full_name: fullName,
        email,
        role,
      });

      if (profileError) {
        // Ne pas laisser un compte auth orphelin sans profil derrière.
        await admin.auth.admin.deleteUser(created.user.id);
        return json({ error: profileError.message }, 400);
      }

      return json({ id: created.user.id, email });
    }

    if (body.action === 'reset_password') {
      const userId = (body.userId ?? '').trim();
      const newPassword = (body.newPassword ?? '').trim();

      if (!userId || !newPassword) {
        return json({ error: 'Champs manquants.' }, 400);
      }

      const { data: targetProfile, error: targetError } = await admin
        .from('profiles')
        .select('id, company_id')
        .eq('id', userId)
        .single();

      if (
        targetError ||
        !targetProfile ||
        targetProfile.company_id !== callerProfile.company_id
      ) {
        return json({ error: 'Utilisateur introuvable.' }, 404);
      }

      const { error: updateError } = await admin.auth.admin.updateUserById(
        userId,
        { password: newPassword },
      );

      if (updateError) {
        return json({ error: updateError.message }, 400);
      }

      return json({ success: true });
    }

    return json({ error: 'Action inconnue.' }, 400);
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
