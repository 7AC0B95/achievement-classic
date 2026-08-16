-- Public community aggregates for the /stats page.
-- SECURITY INVOKER so existing public SELECT policies still apply.

create or replace function public.get_community_stats()
returns jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with counts as (
    select
      (select count(*)::int from public.characters) as characters,
      (select count(*)::int from public.achievements) as catalog,
      (select count(*)::int from public.character_achievements) as unlocks
  ),
  labeled_chars as (
    select
      c.id,
      upper(c.class) as class,
      c.status,
      c.level,
      c.total_points,
      c.achievement_count,
      c.realm,
      c.last_synced_at,
      case lower(btrim(coalesce(c.race, '')))
        when 'human' then 'Human'
        when 'dwarf' then 'Dwarf'
        when 'night elf' then 'Night Elf'
        when 'nightelf' then 'Night Elf'
        when 'gnome' then 'Gnome'
        when 'orc' then 'Orc'
        when 'undead' then 'Undead'
        when 'scourge' then 'Undead'
        when 'tauren' then 'Tauren'
        when 'troll' then 'Troll'
        else 'Unknown'
      end as race,
      case
        when lower(btrim(coalesce(c.race, ''))) in (
          'human', 'dwarf', 'night elf', 'nightelf', 'gnome'
        ) then 'Alliance'
        when lower(btrim(coalesce(c.race, ''))) in (
          'orc', 'undead', 'scourge', 'tauren', 'troll'
        ) then 'Horde'
        else 'Unknown'
      end as faction
    from public.characters c
  ),
  class_list as (
    select * from (values
      ('WARRIOR', 1),
      ('PALADIN', 2),
      ('HUNTER', 3),
      ('ROGUE', 4),
      ('PRIEST', 5),
      ('SHAMAN', 6),
      ('MAGE', 7),
      ('WARLOCK', 8),
      ('DRUID', 9)
    ) as t(class, sort_order)
  ),
  race_list as (
    select * from (values
      ('Human', 'Alliance', 1),
      ('Dwarf', 'Alliance', 2),
      ('Night Elf', 'Alliance', 3),
      ('Gnome', 'Alliance', 4),
      ('Orc', 'Horde', 5),
      ('Undead', 'Horde', 6),
      ('Tauren', 'Horde', 7),
      ('Troll', 'Horde', 8)
    ) as t(race, faction, sort_order)
  ),
  faction_list as (
    select * from (values
      ('Alliance', 1),
      ('Horde', 2)
    ) as t(faction, sort_order)
  ),
  level_list as (
    select * from (values
      ('1–9', 1, 1, 9),
      ('10–19', 2, 10, 19),
      ('20–29', 3, 20, 29),
      ('30–39', 4, 30, 39),
      ('40–49', 5, 40, 49),
      ('50–59', 6, 50, 59),
      ('60', 7, 60, 60)
    ) as t(band, sort_order, lo, hi)
  ),
  category_list as (
    select * from (values
      ('General', 1),
      ('Quests', 2),
      ('Combat', 3),
      ('Exploration', 4),
      ('Wealth', 5),
      ('Professions', 6),
      ('Dungeons', 7),
      ('Player vs Player', 8),
      ('Hardcore', 9),
      ('Feats of Strength', 10)
    ) as t(category, sort_order)
  ),
  class_agg as (
    select
      class,
      count(*)::int as count,
      count(*) filter (where status = 'Alive')::int as alive,
      count(*) filter (where status = 'Dead')::int as dead,
      coalesce(round(avg(level)::numeric, 1), 0) as avg_level,
      coalesce(round(avg(total_points)::numeric, 1), 0) as avg_points,
      coalesce(round(avg(achievement_count)::numeric, 1), 0) as avg_unlocks
    from labeled_chars
    group by class
  ),
  race_agg as (
    select
      race,
      count(*)::int as count,
      count(*) filter (where status = 'Alive')::int as alive,
      coalesce(round(avg(total_points)::numeric, 1), 0) as avg_points
    from labeled_chars
    group by race
  ),
  faction_agg as (
    select
      faction,
      count(*)::int as count,
      count(*) filter (where status = 'Alive')::int as alive,
      count(*) filter (where status = 'Dead')::int as dead,
      coalesce(round(avg(total_points)::numeric, 1), 0) as avg_points
    from labeled_chars
    group by faction
  ),
  unlock_stats as (
    select
      a.id,
      a.name,
      a.category,
      a.points,
      count(ca.id)::int as unlocks
    from public.achievements a
    left join public.character_achievements ca on ca.achievement_id = a.id
    group by a.id, a.name, a.category, a.points
  )
  select jsonb_build_object(
    'overview', (
      select jsonb_build_object(
        'characters', counts.characters,
        'alive', (select count(*)::int from labeled_chars where status = 'Alive'),
        'dead', (select count(*)::int from labeled_chars where status = 'Dead'),
        'avgLevel', coalesce((select round(avg(level)::numeric, 1) from labeled_chars), 0),
        'avgPoints', coalesce((select round(avg(total_points)::numeric, 1) from labeled_chars), 0),
        'totalPoints', coalesce((select sum(total_points)::int from labeled_chars), 0),
        'totalUnlocks', counts.unlocks,
        'catalogSize', counts.catalog,
        'maxLevel', (select count(*)::int from labeled_chars where level = 60),
        'lastSyncedAt', (select max(last_synced_at) from labeled_chars)
      )
      from counts
    ),
    'classes', (
      select coalesce(jsonb_agg(row_obj order by sort_key desc, class), '[]'::jsonb)
      from (
        select
          jsonb_build_object(
            'class', cl.class,
            'count', coalesce(a.count, 0),
            'alive', coalesce(a.alive, 0),
            'dead', coalesce(a.dead, 0),
            'avgLevel', coalesce(a.avg_level, 0),
            'avgPoints', coalesce(a.avg_points, 0),
            'avgUnlocks', coalesce(a.avg_unlocks, 0)
          ) as row_obj,
          cl.class,
          coalesce(a.count, 0) as sort_key
        from class_list cl
        left join class_agg a on a.class = cl.class
        union all
        select
          jsonb_build_object(
            'class', a.class,
            'count', a.count,
            'alive', a.alive,
            'dead', a.dead,
            'avgLevel', a.avg_level,
            'avgPoints', a.avg_points,
            'avgUnlocks', a.avg_unlocks
          ),
          a.class,
          a.count
        from class_agg a
        where not exists (select 1 from class_list cl where cl.class = a.class)
      ) x
    ),
    'races', (
      select coalesce(jsonb_agg(row_obj order by sort_order), '[]'::jsonb)
      from (
        select
          jsonb_build_object(
            'race', rl.race,
            'faction', rl.faction,
            'count', coalesce(a.count, 0),
            'alive', coalesce(a.alive, 0),
            'avgPoints', coalesce(a.avg_points, 0)
          ) as row_obj,
          rl.sort_order
        from race_list rl
        left join race_agg a on a.race = rl.race
        union all
        select
          jsonb_build_object(
            'race', 'Unknown',
            'faction', 'Unknown',
            'count', a.count,
            'alive', a.alive,
            'avgPoints', a.avg_points
          ),
          99
        from race_agg a
        where a.race = 'Unknown' and a.count > 0
      ) x
    ),
    'factions', (
      select coalesce(jsonb_agg(row_obj order by sort_order), '[]'::jsonb)
      from (
        select
          jsonb_build_object(
            'faction', fl.faction,
            'count', coalesce(a.count, 0),
            'alive', coalesce(a.alive, 0),
            'dead', coalesce(a.dead, 0),
            'avgPoints', coalesce(a.avg_points, 0)
          ) as row_obj,
          fl.sort_order
        from faction_list fl
        left join faction_agg a on a.faction = fl.faction
        union all
        select
          jsonb_build_object(
            'faction', 'Unknown',
            'count', a.count,
            'alive', a.alive,
            'dead', a.dead,
            'avgPoints', a.avg_points
          ),
          99
        from faction_agg a
        where a.faction = 'Unknown' and a.count > 0
      ) x
    ),
    'levels', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'band', ll.band,
          'count', coalesce((
            select count(*)::int
            from labeled_chars c
            where c.level between ll.lo and ll.hi
          ), 0)
        )
        order by ll.sort_order
      ), '[]'::jsonb)
      from level_list ll
    ),
    'realms', (
      select coalesce(jsonb_agg(
        jsonb_build_object(
          'realm', realm,
          'count', count,
          'avgPoints', avg_points
        )
        order by count desc, realm
      ), '[]'::jsonb)
      from (
        select
          realm,
          count(*)::int as count,
          coalesce(round(avg(total_points)::numeric, 1), 0) as avg_points
        from labeled_chars
        group by realm
      ) r
    ),
    'categories', (
      select coalesce(jsonb_agg(row_obj order by sort_order), '[]'::jsonb)
      from (
        select
          jsonb_build_object(
            'category', cl.category,
            'catalog', coalesce(s.catalog, 0),
            'unlocks', coalesce(s.unlocks, 0),
            'earnedByAnyone', coalesce(s.earned_by_anyone, 0),
            'earnedPercent', case
              when coalesce(s.catalog, 0) = 0 then 0
              else round((s.earned_by_anyone::numeric * 100) / s.catalog, 1)
            end,
            'avgUnlocksPerCharacter', case
              when counts.characters = 0 then 0
              else round(coalesce(s.unlocks, 0)::numeric / counts.characters, 2)
            end
          ) as row_obj,
          cl.sort_order
        from category_list cl
        cross join counts
        left join (
          select
            a.category,
            count(distinct a.id)::int as catalog,
            count(ca.id)::int as unlocks,
            count(distinct a.id) filter (where ca.id is not null)::int as earned_by_anyone
          from public.achievements a
          left join public.character_achievements ca on ca.achievement_id = a.id
          group by a.category
        ) s on s.category = cl.category
      ) x
    ),
    'commonest', (
      select coalesce(jsonb_agg(to_jsonb(x) order by x.unlocks desc, x.points desc, x.name), '[]'::jsonb)
      from (
        select
          u.id,
          u.name,
          u.category,
          u.points,
          u.unlocks,
          case
            when counts.characters = 0 then 0
            else round((u.unlocks::numeric * 100) / counts.characters, 1)
          end as percent
        from unlock_stats u
        cross join counts
        order by u.unlocks desc, u.points desc, u.name
        limit 10
      ) x
    ),
    'rarest', (
      select coalesce(jsonb_agg(to_jsonb(x) order by x.unlocks, x.points desc, x.name), '[]'::jsonb)
      from (
        select
          u.id,
          u.name,
          u.category,
          u.points,
          u.unlocks,
          case
            when counts.characters = 0 then 0
            else round((u.unlocks::numeric * 100) / counts.characters, 1)
          end as percent
        from unlock_stats u
        cross join counts
        where u.unlocks > 0
        order by u.unlocks, u.points desc, u.name
        limit 10
      ) x
    ),
    'neverEarned', (select count(*)::int from unlock_stats where unlocks = 0),
    'neverEarnedExamples', (
      select coalesce(jsonb_agg(to_jsonb(x) order by x.points desc, x.name), '[]'::jsonb)
      from (
        select
          u.id,
          u.name,
          u.category,
          u.points,
          u.unlocks,
          0::numeric as percent
        from unlock_stats u
        where u.unlocks = 0
        order by u.points desc, u.name
        limit 5
      ) x
    )
  )
  from counts;
$$;

grant execute on function public.get_community_stats() to anon, authenticated;
