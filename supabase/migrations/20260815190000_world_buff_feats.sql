-- World-buff Feats of Strength: Zandalar, Onyxia/Nefarian, Rend, and all three at once.
insert into public.achievements (id, name, description, category, points, icon)
values
  ('9009', 'Spirit of Zandalar', 'Receive the Spirit of Zandalar from the Heart of Hakkar.', 'Feats of Strength', 0, 'Interface\\Icons\\Ability_Creature_Poison_05'),
  ('9010', 'Rallying Cry of the Dragonslayer', 'Receive Rallying Cry of the Dragonslayer from an Onyxia or Nefarian head turn-in.', 'Feats of Strength', 0, 'Interface\\Icons\\INV_Misc_Head_Dragon_01'),
  ('9011', 'Warchief''s Blessing', 'Receive Warchief''s Blessing from a Rend Blackhand head turn-in.', 'Feats of Strength', 0, 'Interface\\Icons\\Spell_Arcane_TeleportOrgrimmar'),
  ('9012', 'World Buffed', 'Be under the effects of Spirit of Zandalar, Rallying Cry of the Dragonslayer, and Warchief''s Blessing at the same time.', 'Feats of Strength', 0, 'Interface\\Icons\\INV_Misc_Horn_01')
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  points = excluded.points,
  icon = excluded.icon;
