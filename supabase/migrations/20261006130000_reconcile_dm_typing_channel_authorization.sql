-- Reconcile private DM typing channel authorization.
-- The client uses a private Realtime Broadcast channel named
-- chat:thread:<thread_id>. Only participants in that thread may receive/send
-- typing events.

drop policy if exists chat_dm_typing_receive on realtime.messages;

create policy chat_dm_typing_receive
on realtime.messages
as permissive
for select
to authenticated
using (
  extension = 'broadcast'
  and realtime.topic() like 'chat:thread:%'
  and exists (
    select 1
    from public.chat_threads t
    where t.id = split_part(realtime.topic(), ':', 3)
      and (select auth.uid())::text = any(t.participant_uids)
  )
);

drop policy if exists chat_dm_typing_send on realtime.messages;

create policy chat_dm_typing_send
on realtime.messages
as permissive
for insert
to authenticated
with check (
  extension = 'broadcast'
  and realtime.topic() like 'chat:thread:%'
  and exists (
    select 1
    from public.chat_threads t
    where t.id = split_part(realtime.topic(), ':', 3)
      and (select auth.uid())::text = any(t.participant_uids)
  )
);
