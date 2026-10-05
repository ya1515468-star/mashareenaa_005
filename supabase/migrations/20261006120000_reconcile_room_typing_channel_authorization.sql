-- Reconcile room typing Realtime authorization.
-- Public active rooms are readable/writable by authenticated users; private rooms
-- remain restricted to active, non-banned members.

drop policy if exists chat_room_typing_receive on realtime.messages;

create policy chat_room_typing_receive
on realtime.messages
as permissive
for select
to authenticated
using (
  extension = 'broadcast'
  and realtime.topic() like 'room:%:typing'
  and exists (
    select 1
    from public.chat_rooms cr
    where cr.id::text = split_part(realtime.topic(), ':', 2)
      and cr.is_active = true
      and (
        cr.is_public = true
        or exists (
          select 1
          from public.chat_room_members m
          where m.room_id = cr.id
            and m.user_id = (select auth.uid())
            and coalesce(m.is_banned, false) = false
        )
      )
  )
);

drop policy if exists chat_room_typing_send on realtime.messages;

create policy chat_room_typing_send
on realtime.messages
as permissive
for insert
to authenticated
with check (
  extension = 'broadcast'
  and realtime.topic() like 'room:%:typing'
  and exists (
    select 1
    from public.chat_rooms cr
    where cr.id::text = split_part(realtime.topic(), ':', 2)
      and cr.is_active = true
      and (
        cr.is_public = true
        or exists (
          select 1
          from public.chat_room_members m
          where m.room_id = cr.id
            and m.user_id = (select auth.uid())
            and coalesce(m.is_banned, false) = false
        )
      )
  )
);