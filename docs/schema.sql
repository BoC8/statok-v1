-- =====================================================================
-- STATOK — Schéma Supabase (Postgres)
--
-- Source   : export du dashboard Supabase
-- Date     : 22 août 2026
-- Usage    : DOCUMENTATION UNIQUEMENT — ne pas exécuter tel quel.
--            L'ordre des tables et les contraintes ne sont pas garantis
--            valides pour une exécution directe.
--
-- À REGÉNÉRER après toute migration :
--   supabase db dump --schema-only > docs/schema.sql
-- =====================================================================

CREATE TABLE public.adversaires (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  nom text NOT NULL UNIQUE,
  logo_url text,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT adversaires_pkey PRIMARY KEY (id)
);

CREATE TABLE public.joueurs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  nom text NOT NULL,
  categorie text NOT NULL,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  genre character varying DEFAULT 'M'::character varying,
  categorie_detail character varying,
  CONSTRAINT joueurs_pkey PRIMARY KEY (id)
);

CREATE TABLE public.matchs (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  date date NOT NULL,
  equipe text NOT NULL,
  adversaire_id uuid NOT NULL,
  lieu text NOT NULL,
  competition text NOT NULL,
  buts_gjpb integer NOT NULL,
  buts_adv integer NOT NULL,
  categorie text NOT NULL,
  saison text NOT NULL,
  verrouille boolean NOT NULL DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  tab_fcpb integer,
  tab_adv integer,
  CONSTRAINT matchs_pkey PRIMARY KEY (id),
  CONSTRAINT matchs_adversaire_id_fkey FOREIGN KEY (adversaire_id) REFERENCES public.adversaires(id)
);

CREATE TABLE public.programmations (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  date date NOT NULL,
  heure time without time zone NOT NULL,
  equipe text NOT NULL,
  adversaire_id uuid NOT NULL,
  lieu text NOT NULL,
  competition text NOT NULL,
  categorie text NOT NULL,
  saison text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT programmations_pkey PRIMARY KEY (id),
  CONSTRAINT programmations_adversaire_id_fkey FOREIGN KEY (adversaire_id) REFERENCES public.adversaires(id)
);

CREATE TABLE public.actions (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  match_id uuid NOT NULL,
  joueur_id uuid NOT NULL,
  type text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT actions_pkey PRIMARY KEY (id),
  CONSTRAINT actions_match_id_fkey FOREIGN KEY (match_id) REFERENCES public.matchs(id),
  CONSTRAINT actions_joueur_id_fkey FOREIGN KEY (joueur_id) REFERENCES public.joueurs(id)
);

CREATE TABLE public.classements (
  id uuid NOT NULL DEFAULT uuid_generate_v4(),
  equipe text NOT NULL,
  competition text NOT NULL,
  position text NOT NULL,
  categorie text NOT NULL,
  saison text NOT NULL,
  created_at timestamp with time zone NOT NULL DEFAULT timezone('utc'::text, now()),
  CONSTRAINT classements_pkey PRIMARY KEY (id)
);

CREATE TABLE public.equipes (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  nom text NOT NULL,
  categorie text NOT NULL,
  actif boolean NOT NULL DEFAULT true,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  genre character varying DEFAULT 'M'::character varying,
  CONSTRAINT equipes_pkey PRIMARY KEY (id)
);

-- =====================================================================
-- NOTES DE LECTURE (voir ARCHITECTURE.md §5 pour le détail)
--
-- Valeurs applicatives (conventions, non contraintes en base) :
--   actions.type   : 'Goal' | 'Assist' | 'TAB_Reussi' | 'TAB_Rate'
--   lieu           : 'DOM' | 'EXT'
--   categorie      : 'U14-15' | 'U16-17-18' | 'Seniors'
--   genre          : 'M' | 'F'
--   saison         : '2025-2026', '2026-2027', …
--   joueurs.categorie_detail : '14' | '15' | '16' | '17' | '18' | 'Senior'
--
-- Colonnes présentes en base mais JAMAIS lues ni écrites par l'app :
--   matchs.verrouille, adversaires.logo_url
--
-- Table entière jamais utilisée par l'app : classements
--
-- Absent et manquant :
--   - aucun ON DELETE CASCADE sur actions.match_id  → supprimer un match
--     ayant des actions échoue (erreur de clé étrangère)
--   - aucun index secondaire (actions.match_id, actions.joueur_id,
--     matchs.saison/categorie, programmations.saison/categorie)
--   - aucune contrainte d'unicité sur equipes(nom, categorie)
--     ni sur joueurs(nom, categorie_detail)
--   - matchs.equipe / programmations.equipe sont du texte libre,
--     sans clé étrangère vers equipes.nom
--   - RLS : à vérifier dans le dashboard, non visible dans cet export
-- =====================================================================
