-- =====================================================================
-- STATOK — Activation de la Row Level Security
--
-- Date    : 23 août 2026
-- À jouer : Supabase Dashboard → SQL Editor → coller → Run
--
-- PRINCIPE
--   Lecture  : autorisée à tout le monde (rôle anon) — la partie publique
--              de l'app en a besoin, et il s'agit de résultats sportifs.
--   Écriture : réservée aux utilisateurs connectés (rôle authenticated),
--              c'est-à-dire aux coachs passés par la page de login.
--
-- POURQUOI C'EST SÛR
--   Vérifié dans le code : aucune écriture ne part du côté public.
--   Tous les insert/update/delete sont dans pages/admin/*, donc derrière
--   l'authentification Supabase. equipe_service n'écrit que lorsqu'il est
--   appelé avec persistHistorique: true, ce qui n'arrive que depuis
--   EquipesAdminTab.
--
-- IDEMPOTENT : ce script peut être rejoué sans risque.
-- =====================================================================

do $$
declare
  t text;
  tables text[] := array[
    'actions',
    'adversaires',
    'classements',
    'equipes',
    'joueurs',
    'matchs',
    'programmations'
  ];
begin
  foreach t in array tables
  loop
    -- 1. Fermer la table
    execute format('alter table public.%I enable row level security', t);

    -- 2. Lecture ouverte à tous (anon = app publique, authenticated = coach)
    execute format('drop policy if exists "lecture_publique" on public.%I', t);
    execute format(
      'create policy "lecture_publique" on public.%I
         for select to anon, authenticated
         using (true)', t);

    -- 3. Écriture (insert / update / delete) réservée aux connectés
    execute format('drop policy if exists "ecriture_authentifiee" on public.%I', t);
    execute format(
      'create policy "ecriture_authentifiee" on public.%I
         for all to authenticated
         using (true) with check (true)', t);

    raise notice 'RLS activée sur %', t;
  end loop;
end $$;


-- =====================================================================
-- VÉRIFICATION — à exécuter après, doit afficher 7 lignes toutes à "true"
-- =====================================================================

select
  c.relname                             as table_name,
  c.relrowsecurity                      as rls_active,
  count(p.polname)                      as nb_policies
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
left join pg_policy p on p.polrelid = c.oid
where n.nspname = 'public'
  and c.relkind = 'r'
group by c.relname, c.relrowsecurity
order by c.relname;
