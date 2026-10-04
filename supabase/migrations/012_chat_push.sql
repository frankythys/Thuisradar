-- Push for all chat message types; never send to the author.
-- Old installations retain their existing channels until the new app is opened.
alter table public.device_tokens
  add column if not exists notification_version integer not null default 1;

create or replace function public.notify_chat_push()
returns trigger
language plpgsql
security definer
set search_path = public, private
as $$
begin
  perform private.call_push('send-chat-push', jsonb_build_object('record', to_jsonb(new)));
  return new;
end;
$$;

drop trigger if exists messages_push on public.messages;
create trigger messages_push
  after insert on public.messages
  for each row execute function public.notify_chat_push();

revoke execute on function public.notify_chat_push() from public, anon, authenticated;
