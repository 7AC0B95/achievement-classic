-- Owners can delete leftover unlocks when a sealed sync replaces the set.

drop policy if exists "Owners can delete character achievements" on public.character_achievements;
create policy "Owners can delete character achievements"
  on public.character_achievements for delete
  to authenticated
  using (
    exists (
      select 1 from public.characters c
      where c.id = character_id and c.user_id = auth.uid()
    )
  );
