alter publication supabase_realtime add table public.project_chat_messages;

update storage.buckets
set allowed_mime_types = array(
  select distinct unnest(
    coalesce(allowed_mime_types, array[]::text[]) || array['audio/mp4', 'audio/mpeg']
  )
)
where id = 'project-documents';
