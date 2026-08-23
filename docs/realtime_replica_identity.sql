-- =====================================================================
-- STATOK — Tentative de restauration du temps réel sous RLS
--
-- Date : 23 août 2026
--
-- CONTEXTE
--   Depuis l'activation de la RLS, le flux Realtime de Supabase ne transmet
--   plus les événements UPDATE : la liste des matchs se charge bien mais ne se
--   met plus à jour après une modification.
--
--   C'est un problème connu et non résolu côté Supabase (discussion #35196,
--   ouverte en avril 2025, toujours sans correctif). Les événements UPDATE
--   cessent d'arriver même avec une policy SELECT `using (true)`.
--
-- CE QUE FAIT CE SCRIPT
--   `replica identity full` demande à Postgres d'inclure l'intégralité de
--   l'ancienne ligne dans le flux de réplication, au lieu de la seule clé
--   primaire. C'est ce dont Realtime a besoin pour évaluer la RLS sur un
--   UPDATE ou un DELETE.
--
--   Coût : le flux de réplication devient un peu plus volumineux. Négligeable
--   à l'échelle de cette base.
--
-- HONNÊTETÉ
--   Ce script PEUT suffire, mais rien ne le garantit — le bug amont est
--   toujours ouvert. C'est pourquoi l'application ne compte plus dessus :
--   elle recharge désormais explicitement après chaque modification. Le temps
--   réel redevient un confort, plus une dépendance.
--
-- SANS RISQUE : ne modifie aucune donnée.
-- =====================================================================

alter table public.matchs         replica identity full;
alter table public.programmations replica identity full;
alter table public.actions        replica identity full;
alter table public.joueurs        replica identity full;
alter table public.equipes        replica identity full;


-- =====================================================================
-- VÉRIFICATION 1 — les tables sont-elles publiées vers Realtime ?
--
-- Attendu : matchs et programmations présentes.
-- Si elles manquent : Dashboard → Database → Publications → supabase_realtime
-- =====================================================================

select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by tablename;


-- =====================================================================
-- VÉRIFICATION 2 — identité de réplication
--
-- relreplident : 'd' = default (clé primaire seule), 'f' = full
-- Attendu : 'f' sur les cinq tables ci-dessus.
-- =====================================================================

select
  c.relname as table_name,
  case c.relreplident
    when 'f' then 'FULL ✓'
    when 'd' then 'DEFAULT (cle primaire seule)'
    when 'n' then 'NOTHING'
    when 'i' then 'INDEX'
  end as replica_identity
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public'
  and c.relkind = 'r'
order by c.relname;
