-- =====================================================================
-- STATOK — Suppression en cascade des actions d'un match
--
-- Date    : 23 août 2026
-- À jouer : Supabase Dashboard → SQL Editor → coller → Run
--
-- PROBLÈME
--   actions.match_id référence matchs.id sans ON DELETE CASCADE.
--   Supprimer un match qui a au moins un but ou une passe déclenchait une
--   violation de clé étrangère côté Postgres. Le code Dart ne l'attrapait
--   pas : la boîte de dialogue se fermait comme si tout allait bien, et le
--   match restait en base.
--
-- CORRECTIF
--   La base prend désormais elle-même en charge la suppression des actions
--   liées. Le correctif Dart (suppression explicite des actions + try/catch)
--   reste en place : ceinture et bretelles, et il protège si cette migration
--   n'a pas été jouée sur un autre environnement.
--
-- SANS RISQUE : ne modifie aucune donnée, seulement la contrainte.
-- =====================================================================

alter table public.actions
  drop constraint if exists actions_match_id_fkey;

alter table public.actions
  add constraint actions_match_id_fkey
  foreign key (match_id)
  references public.matchs(id)
  on delete cascade;


-- =====================================================================
-- VÉRIFICATION — doit afficher "c" (= CASCADE) dans la colonne on_delete
-- =====================================================================

select
  con.conname                      as contrainte,
  con.confdeltype                  as on_delete,   -- 'c' = cascade, 'a' = no action
  case con.confdeltype
    when 'c' then 'CASCADE ✓'
    when 'a' then 'NO ACTION ✗'
    else con.confdeltype::text
  end                              as lisible
from pg_constraint con
join pg_class c on c.oid = con.conrelid
where c.relname = 'actions'
  and con.contype = 'f';
