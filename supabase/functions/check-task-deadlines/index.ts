// Appelée une fois par jour par pg_cron : notifie l'utilisateur assigné à
// une tâche en retard, à échéance aujourd'hui, ou proche de l'échéance.
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';
import { loadServiceAccount, sendToToken } from '../_shared/fcm.ts';

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}

function dateOnly(value: string): Date {
  const [year, month, day] = value.split('T')[0].split('-').map(Number);
  return new Date(Date.UTC(year, month - 1, day));
}

function frDate(value: Date): string {
  const day = String(value.getUTCDate()).padStart(2, '0');
  const month = String(value.getUTCMonth() + 1).padStart(2, '0');
  return `${day}/${month}/${value.getUTCFullYear()}`;
}

Deno.serve(async (req) => {
  try {
    const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
    const authHeader = req.headers.get('Authorization') ?? '';

    if (authHeader.replace('Bearer ', '') !== serviceRoleKey) {
      return json({ error: 'Non autorisé.' }, 401);
    }

    const admin = createClient(Deno.env.get('SUPABASE_URL')!, serviceRoleKey);

    const { data: tasks, error } = await admin
      .from('project_tasks')
      .select('id, title, status, assigned_to, planned_end_date, projects(name)')
      .eq('is_archived', false)
      .not('assigned_to', 'is', null)
      .not('planned_end_date', 'is', null)
      .not('status', 'in', '(terminee,archivee)');

    if (error) {
      return json({ error: error.message }, 500);
    }

    const today = dateOnly(new Date().toISOString());
    const serviceAccount = loadServiceAccount();
    let sent = 0;

    for (const task of tasks ?? []) {
      const end = dateOnly(task.planned_end_date as string);
      const diffDays = Math.round(
        (end.getTime() - today.getTime()) / 86_400_000,
      );

      let title: string | null = null;
      let body: string | null = null;
      const projectName = (task as { projects?: { name?: string } }).projects
        ?.name ?? 'Projet';

      if (diffDays < 0) {
        title = 'Tâche en retard';
        body = `${projectName} • ${task.title} devait finir le ${frDate(end)}`;
      } else if (diffDays === 0) {
        title = 'Échéance aujourd’hui';
        body = `${projectName} • ${task.title} finit aujourd’hui`;
      } else if (diffDays <= 3) {
        title = 'Échéance proche';
        body = `${projectName} • ${task.title} finit le ${frDate(end)}`;
      }

      if (!title || !body) {
        continue;
      }

      const { data: pref } = await admin
        .from('notification_preferences')
        .select('enabled')
        .eq('profile_id', task.assigned_to as string)
        .eq('module', 'planning')
        .maybeSingle();

      if (pref?.enabled === false) {
        continue;
      }

      const { data: tokens } = await admin
        .from('device_tokens')
        .select('id, fcm_token')
        .eq('profile_id', task.assigned_to as string);

      for (const row of tokens ?? []) {
        const ok = await sendToToken(serviceAccount, row.fcm_token, {
          title,
          body,
          data: { type: 'task_deadline', taskId: task.id as string },
        });
        if (ok) {
          sent++;
        } else {
          await admin.from('device_tokens').delete().eq('id', row.id);
        }
      }
    }

    return json({ sent });
  } catch (error) {
    return json({ error: String(error) }, 500);
  }
});
