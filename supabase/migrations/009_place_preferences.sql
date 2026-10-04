-- Bewaar de onderdelen uit scherm 14, met bestaande waarden als standaard.
alter table public.places add column if not exists address text;
alter table public.places add column if not exists notify_arrival boolean not null default true;
alter table public.places add column if not exists notify_departure boolean not null default true;

create or replace function public.evaluate_geofences()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  pl             record;
  pres           place_presence%rowtype;
  dist           double precision;
  new_count      integer;
  new_outside    timestamptz;
  watched        boolean;
begin
  if new.accuracy_m is not null and new.accuracy_m > 100 then
    return new;
  end if;

  for pl in select * from places where family_id = new.family_id loop
    dist := geo_distance_m(new.lat, new.lng, pl.lat, pl.lng);
    select * into pres from place_presence where user_id = new.user_id and place_id = pl.id;
    watched := pl.watched_members is null
      or array_length(pl.watched_members, 1) is null
      or new.user_id = any (pl.watched_members);

    if dist < pl.radius_m then
      -- Binnenzone.
      if pres.user_id is null or not pres.is_inside then
        insert into place_presence (user_id, place_id, family_id, is_inside, since, outside_since, outside_count, updated_at)
        values (new.user_id, pl.id, new.family_id, true, new.updated_at, null, 0, now())
        on conflict (user_id, place_id) do update
          set is_inside = true, since = excluded.since, outside_since = null, outside_count = 0, updated_at = now();
        if watched and pl.notify_arrival then
          insert into family_events (family_id, actor_user_id, type, place_id, lat, lng, created_at)
          values (new.family_id, new.user_id, 'arrival', pl.id, new.lat, new.lng, new.updated_at);
        end if;
      else
        update place_presence set outside_since = null, outside_count = 0, updated_at = now()
          where user_id = new.user_id and place_id = pl.id;
      end if;

    elsif dist > pl.radius_m + 50 then
      -- Buitenzone (voorbij de hysterese).
      if pres.user_id is not null and pres.is_inside then
        if pres.outside_since is null then
          new_outside := new.updated_at;
          new_count := 1;
        else
          new_outside := pres.outside_since;
          new_count := pres.outside_count + 1;
        end if;

        if new_count >= 2 or (new.updated_at - new_outside) >= interval '3 minutes' then
          update place_presence set is_inside = false, since = null, outside_since = null, outside_count = 0, updated_at = now()
            where user_id = new.user_id and place_id = pl.id;
          if watched and pl.notify_departure then
            insert into family_events (family_id, actor_user_id, type, place_id, lat, lng, created_at)
            values (new.family_id, new.user_id, 'departure', pl.id, new.lat, new.lng, new.updated_at);
          end if;
        else
          update place_presence set outside_since = new_outside, outside_count = new_count, updated_at = now()
            where user_id = new.user_id and place_id = pl.id;
        end if;
      end if;
    end if;
    -- Band (straal..straal+50): niets doen.
  end loop;

  return new;
end;
$$;
