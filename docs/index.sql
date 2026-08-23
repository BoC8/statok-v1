-- =====================================================================
-- STATOK — Index accompagnant le filtrage côté serveur
--
-- Date : 23 août 2026
--
-- HONNÊTETÉ D'ABORD
--   Avec 73 matchs, ces index ne changeront strictement rien aujourd'hui :
--   Postgres lira la table entière de toute façon, c'est plus rapide que
--   de passer par un index sur si peu de lignes.
--
--   Ils servent à ce que le filtrage côté serveur reste rapide quand la
--   base grossira — plusieurs catégories, plusieurs saisons, des milliers
--   d'actions. Les poser maintenant coûte quelques kilo-octets et évite
--   d'y penser dans trois ans.
--
-- IDEMPOTENT : "if not exists" partout, rejouable sans risque.
-- =====================================================================

-- --- Filtres catégorie + saison (calendrier, résultats, stats) ---
create index if not exists idx_matchs_categorie_saison
  on public.matchs (categorie, saison);

create index if not exists idx_programmations_categorie_saison
  on public.programmations (categorie, saison);

-- --- Filtre par équipe (dashboard d'une équipe) ---
create index if not exists idx_matchs_equipe
  on public.matchs (equipe);

create index if not exists idx_programmations_equipe
  on public.programmations (equipe);

-- --- Clés étrangères (jointures actions -> matchs / joueurs) ---
-- Postgres n'indexe PAS automatiquement le côté enfant d'une clé étrangère.
-- Ces deux-là servent aussi bien aux jointures qu'aux suppressions en cascade.
create index if not exists idx_actions_match_id
  on public.actions (match_id);

create index if not exists idx_actions_joueur_id
  on public.actions (joueur_id);

-- --- Tri par date (toutes les listes sont ordonnées par date) ---
create index if not exists idx_matchs_date
  on public.matchs (date desc);

create index if not exists idx_programmations_date
  on public.programmations (date);


-- =====================================================================
-- VÉRIFICATION — doit lister les 8 index ci-dessus
-- =====================================================================

select
  tablename,
  indexname,
  pg_size_pretty(pg_relation_size(indexname::regclass)) as taille
from pg_indexes
where schemaname = 'public'
  and indexname like 'idx_%'
order by tablename, indexname;
