-- Private family attachments and an optional number for deliberate call actions.
alter table public.profiles add column if not exists phone text
  check (phone is null or phone ~ '^\+?[0-9 ()-]{6,24}$');

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('family-media', 'family-media', false, 10485760,
  array['image/jpeg','image/png','image/webp','audio/mp4','audio/x-m4a'])
on conflict (id) do nothing;

create policy "family media read" on storage.objects for select to authenticated
using (bucket_id = 'family-media' and exists (
  select 1 from public.family_members fm
  where fm.user_id = auth.uid() and fm.family_id::text = (storage.foldername(name))[1]
));
create policy "family media upload" on storage.objects for insert to authenticated
with check (bucket_id = 'family-media'
  and (storage.foldername(name))[2] = auth.uid()::text
  and exists (select 1 from public.family_members fm
    where fm.user_id = auth.uid() and fm.family_id::text = (storage.foldername(name))[1]));
create policy "family media remove own" on storage.objects for delete to authenticated
using (bucket_id = 'family-media' and owner_id = auth.uid()::text);

create table public.sos_receipts (
  alert_id uuid not null references public.sos_alerts(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  seen_at timestamptz not null default now(),
  on_the_way boolean not null default false,
  primary key (alert_id, user_id)
);
alter table public.sos_receipts enable row level security;
create policy "family receipts read" on public.sos_receipts for select to authenticated
using (exists (select 1 from public.sos_alerts a where a.id = alert_id and public.is_family_member(a.family_id)));
create policy "own receipt insert" on public.sos_receipts for insert to authenticated
with check (user_id = auth.uid() and exists (select 1 from public.sos_alerts a where a.id = alert_id and public.is_family_member(a.family_id)));
create policy "own receipt update" on public.sos_receipts for update to authenticated
using (user_id = auth.uid())
with check (user_id = auth.uid() and exists (select 1 from public.sos_alerts a where a.id = alert_id and public.is_family_member(a.family_id)));
grant select, insert, update on public.sos_receipts to authenticated;
alter publication supabase_realtime add table public.sos_receipts;
