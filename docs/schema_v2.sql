-- =====================================================================
--  STATOK — schéma v2
--  FC Pierre Bleue · à exécuter sur un projet Supabase NEUF
--
--  Ordre d'exécution : ce fichier en entier, puis seed_v2.sql (données de
--  référence), puis le script de migration des données existantes.
--
--  Conventions
--    · identifiants en uuid, générés par la base
--    · pas de suppression physique des joueurs : colonne `actif`
--    · `phase` et `genre` ne sont jamais NULL — voir les notes ci-dessous
--    · lecture publique sur les données du club, écriture réservée au staff
-- =====================================================================


-- =====================================================================
--  1. RÉFÉRENTIEL
-- =====================================================================

-- ---------------------------------------------------------------------
--  saisons
--
--  `annee_debut` porte la logique (tri, calcul, comparaison) ; `libelle`
--  n'est que de l'affichage. Une saison va de juillet à juin.
--
--  `montee_faite` protège l'opération de montée de catégorie, qui est
--  irréversible : le bouton de l'espace coachs doit refuser de s'exécuter
--  une deuxième fois sur la même saison.
-- ---------------------------------------------------------------------
create table saisons (
  id            uuid primary key default gen_random_uuid(),
  annee_debut   int  not null unique check (annee_debut between 2000 and 2100),
  libelle       text not null,
  en_cours      bool not null default false,
  montee_faite  bool not null default false
);

-- Une seule saison en cours. L'index partiel l'impose au niveau de la base :
-- il est impossible de se retrouver avec deux saisons actives.
create unique index saisons_une_seule_en_cours
  on saisons (en_cours) where en_cours;


-- ---------------------------------------------------------------------
--  categories
--
--  Trois lignes, créées une fois pour toutes. `ordre` fixe la position
--  d'affichage partout dans l'application (1 = les plus jeunes).
--  C'est aussi le niveau auquel les droits des coachs sont attribués.
-- ---------------------------------------------------------------------
--  `generations` liste les tranches d'âge que la catégorie accueille.
--  C'est ce qui permet de retrouver la catégorie d'un joueur sans lui
--  attribuer d'équipe — indispensable puisqu'un licencié n'appartient à
--  aucune équipe fixe (voir la table joueurs).
create table categories (
  id           uuid   primary key default gen_random_uuid(),
  libelle      text   not null unique,
  ordre        int    not null unique,
  generations  text[] not null default '{}'
);


-- ---------------------------------------------------------------------
--  equipes
--
--  Le croisement categorie_id + genre forme les six groupes qui servent
--  de filtre dans toute l'application.
--
--  Pas de `nom_court` : `nom` est déjà court ("U15 B", "Seniors A") et
--  s'affiche tel quel dans les lignes de match.
--
--  Pas de `niveau` non plus : il change d'une phase à l'autre chez les
--  jeunes, il se lit donc sur l'engagement de la phase en cours.
--
--  `ordre` fixe la position d'affichage à l'intérieur d'un groupe. Il est
--  indispensable : l'ordre voulu n'est pas alphabétique (U18 A, puis U17,
--  puis U18 B) et une base ne garantit jamais l'ordre d'insertion.
-- ---------------------------------------------------------------------
create table equipes (
  id            uuid primary key default gen_random_uuid(),
  categorie_id  uuid not null references categories (id) on delete restrict,
  genre         char(1) not null check (genre in ('M', 'F')),
  nom           text not null,
  ordre         int  not null default 1 check (ordre > 0),
  actif         bool not null default true,
  unique (categorie_id, genre, nom),
  unique (categorie_id, genre, ordre)
);

create index equipes_categorie on equipes (categorie_id, genre);


-- ---------------------------------------------------------------------
--  adversaires
--
--  Une ligne par ÉQUIPE adverse, pas par club : "US Gournay",
--  "US Gournay 2" et "US Gournay U18" sont trois lignes distinctes.
--  L'historique des confrontations existe donc au niveau de l'équipe.
-- ---------------------------------------------------------------------
create table adversaires (
  id        uuid primary key default gen_random_uuid(),
  nom       text not null unique,
  logo_url  text
);


-- ---------------------------------------------------------------------
--  competitions
--
--  Le nom ne mentionne jamais la catégorie : "Départemental 1" est une
--  seule ligne, partagée par les seniors et les U15. C'est l'engagement
--  — donc l'équipe — qui dit de quelle catégorie il s'agit.
--
--  `type` alimente le filtre « championnat / coupe / amical ».
-- ---------------------------------------------------------------------
create table competitions (
  id    uuid primary key default gen_random_uuid(),
  nom   text not null unique,
  type  text not null check (type in ('championnat', 'coupe', 'amical'))
);


-- ---------------------------------------------------------------------
--  engagements
--
--  Quelle équipe joue quelle compétition, à quelle phase, telle saison.
--
--  LES PHASES
--    · seniors et coupes  → phase 0 (un seul championnat toute l'année)
--    · jeunes             → phases 1, 2 et 3, chacune pouvant pointer
--                           vers une compétition différente puisqu'une
--                           équipe monte ou descend entre les phases
--
--  phase est `not null default 0` et JAMAIS nullable. Avec un NULL,
--  toute contrainte composite portant sur ces colonnes serait ignorée
--  en silence par Postgres (comportement MATCH SIMPLE), et les requêtes
--  devraient partout écrire `phase is null or phase = ...`.
-- ---------------------------------------------------------------------
create table engagements (
  id              uuid primary key default gen_random_uuid(),
  equipe_id       uuid not null references equipes (id)      on delete cascade,
  competition_id  uuid not null references competitions (id) on delete restrict,
  saison_id       uuid not null references saisons (id)      on delete restrict,
  phase           int  not null default 0 check (phase between 0 and 3),
  unique (equipe_id, competition_id, saison_id, phase)
);

create index engagements_saison on engagements (saison_id, equipe_id);


-- =====================================================================
--  2. LICENCIÉS
-- =====================================================================

-- ---------------------------------------------------------------------
--  joueurs
--
--  PAS D'ÉQUIPE. Un licencié n'appartient à aucune équipe fixe : un
--  joueur de génération 17 peut jouer en U18 A un week-end et en U17 le
--  suivant. Les équipes avec lesquelles il a réellement joué se lisent
--  sur ses buts, via la rencontre — jamais sur sa fiche.
--
--  `generation` est donc sa seule appartenance. Elle est incrémentée
--  chaque été par l'opération de montée :
--  13 → 14 → 15 → 16 → 17 → 18 → senior, et senior ne bouge plus.
--
--  `genre` est nécessaire pour savoir quel coach a le droit de modifier
--  la fiche : sans équipe ni genre, rien ne distinguerait un licencié
--  des U16-U18 masculins d'une licenciée des U16-U18 féminines.
--
--  `actif` remplace la suppression : un joueur qui quitte le club passe
--  à false et ses buts restent attachés aux rencontres.
-- ---------------------------------------------------------------------
create table joueurs (
  id          uuid primary key default gen_random_uuid(),
  prenom      text not null,
  nom         text not null,
  generation  text not null check (generation in ('13','14','15','16','17','18','senior')),
  genre       char(1) not null check (genre in ('M', 'F')),
  actif       bool not null default true
);

create index joueurs_generation on joueurs (generation, genre) where actif;


-- =====================================================================
--  3. RENCONTRES
-- =====================================================================

-- ---------------------------------------------------------------------
--  rencontres
--
--  Une seule table pour le programmé et le joué. Le coach saisit la
--  rencontre une fois, puis ajoute le score et bascule `statut`.
--  C'est ce qui évite la double saisie et les doublons.
--
--  Les quatre colonnes saison_id / equipe_id / competition_id / phase
--  reprennent celles d'`engagements`. Cette redondance est assumée : le
--  formulaire de saisie alimente la liste des compétitions à partir des
--  engagements de l'équipe, et un match amical n'a pas d'engagement.
--  Aucune contrainte composite ne l'impose — c'est une garantie
--  applicative, à ne pas oublier.
-- ---------------------------------------------------------------------
create table rencontres (
  id              uuid not null primary key default gen_random_uuid(),
  saison_id       uuid not null references saisons (id)      on delete restrict,
  equipe_id       uuid not null references equipes (id)      on delete restrict,
  competition_id  uuid not null references competitions (id) on delete restrict,
  adversaire_id   uuid not null references adversaires (id)  on delete restrict,
  phase           int  not null default 0 check (phase between 0 and 3),
  date_heure      timestamptz not null,
  domicile        bool not null,
  statut          text not null default 'programmee'
                    check (statut in ('programmee', 'jouee')),

  -- null : match disputé. 'nous' : le FCPB ne s'est pas présenté, donc
  -- 0–3. 'eux' : l'adversaire ne s'est pas présenté, donc 3–0.
  --
  -- UN FORFAIT EST UN MATCH JOUÉ, PAS UN CINQUIÈME STATUT
  --   Il compte au classement comme une victoire ou une défaite. Le
  --   ranger parmi les matchs joués fait que tout ce qui les compte —
  --   bilans, séries, pourcentages — continue de fonctionner sans rien
  --   savoir des forfaits.
  forfait         text check (forfait is null or forfait in ('nous', 'eux')),

  score_pour      int check (score_pour   >= 0),
  score_contre    int check (score_contre >= 0),
  tab_pour        int check (tab_pour     >= 0),
  tab_contre      int check (tab_contre   >= 0),

  -- un match joué a forcément un score ; un match non joué n'en a pas
  constraint rencontres_score_coherent check (
    (statut =  'jouee' and score_pour is not null and score_contre is not null) or
    (statut <> 'jouee' and score_pour is     null and score_contre is     null)
  ),

  -- les tirs au but vont par paire, et seulement après un match nul
  constraint rencontres_tab_coherent check (
    (tab_pour is null and tab_contre is null) or
    (tab_pour is not null and tab_contre is not null
     and score_pour = score_contre and tab_pour <> tab_contre)
  ),

  -- le score d'un forfait n'est pas une saisie, c'est une conséquence
  constraint rencontres_forfait_coherent check (
    forfait is null or (
      statut     = 'jouee'
      and tab_pour   is null
      and tab_contre is null
      and (
        (forfait = 'nous' and score_pour = 0 and score_contre = 3) or
        (forfait = 'eux'  and score_pour = 3 and score_contre = 0)
      )
    )
  )
);

create index rencontres_saison  on rencontres (saison_id, date_heure desc);
create index rencontres_equipe  on rencontres (equipe_id, date_heure desc);
create index rencontres_adv     on rencontres (adversaire_id);
create index rencontres_statut  on rencontres (statut, date_heure);


-- ---------------------------------------------------------------------
--  buts
--
--  Une ligne par but marqué PAR le FCPB : cette table n'alimente que
--  `score_pour`. Un but encaissé n'existe que dans `score_contre`.
--
--  csc = true : but contre son camp d'un joueur ADVERSE, qui compte donc
--  pour nous. Dans ce cas il n'y a ni buteur ni passeur à créditer.
--
--  L'équipe concernée se lit sur la rencontre, jamais sur la fiche du
--  joueur : un joueur qui dépanne dans une autre catégorie voit chacun
--  de ses buts rattaché à la bonne équipe.
--
--  Le détail des buteurs est FACULTATIF : `score_pour` fait foi. Si le
--  nombre de lignes ne correspond pas au score, l'application le signale
--  au coach — elle ne recalcule rien.
-- ---------------------------------------------------------------------
create table buts (
  id            uuid primary key default gen_random_uuid(),
  rencontre_id  uuid not null references rencontres (id) on delete cascade,
  joueur_id     uuid references joueurs (id) on delete restrict,
  passeur_id    uuid references joueurs (id) on delete restrict,
  csc           bool not null default false,

  constraint buts_csc_coherent check (
    (csc     and joueur_id is     null and passeur_id is null) or
    (not csc and joueur_id is not null)
  ),
  constraint buts_passeur_distinct check (passeur_id is null or passeur_id <> joueur_id)
);

create index buts_rencontre on buts (rencontre_id);
create index buts_joueur    on buts (joueur_id)  where joueur_id  is not null;
create index buts_passeur   on buts (passeur_id) where passeur_id is not null;


-- ---------------------------------------------------------------------
--  tirs_au_but
--
--  Nos tireurs uniquement, dans l'ordre de passage. Le score de la
--  séance est déjà sur `rencontres` (tab_pour / tab_contre) : cette
--  table n'existe que pour afficher la colonne détaillée.
-- ---------------------------------------------------------------------
create table tirs_au_but (
  id            uuid primary key default gen_random_uuid(),
  rencontre_id  uuid not null references rencontres (id) on delete cascade,
  ordre         int  not null check (ordre > 0),
  joueur_id     uuid not null references joueurs (id) on delete restrict,
  marque        bool not null,
  unique (rencontre_id, ordre)
);

create index tirs_au_but_rencontre on tirs_au_but (rencontre_id);


-- =====================================================================
--  4. COMPTES ET DROITS
-- =====================================================================

-- ---------------------------------------------------------------------
--  profils
--
--  `auth.users` appartient à Supabase et n'accepte pas de colonnes
--  supplémentaires : cette table la prolonge, avec le même identifiant.
-- ---------------------------------------------------------------------
create table profils (
  id    uuid primary key references auth.users (id) on delete cascade,
  nom   text not null,
  role  text not null check (role in ('admin', 'coach'))
);


-- ---------------------------------------------------------------------
--  coach_categories
--
--  Quelles catégories un coach a le droit de modifier. Un admin n'a
--  aucune ligne ici et écrit partout.
--
--  `genre` vaut 'M', 'F' ou 'T' (les deux). Pas de NULL : une colonne
--  de clé primaire ne peut pas être nulle, et deux lignes NULL ne se
--  dédoublonneraient pas.
-- ---------------------------------------------------------------------
create table coach_categories (
  utilisateur_id  uuid not null references profils (id)    on delete cascade,
  categorie_id    uuid not null references categories (id) on delete cascade,
  genre           char(1) not null default 'T' check (genre in ('M', 'F', 'T')),
  primary key (utilisateur_id, categorie_id, genre)
);


-- =====================================================================
--  5. FONCTIONS D'HABILITATION
--
--  Toute la logique de droits vit ici, et les politiques RLS ne font que
--  les appeler. Trois raisons : les politiques restent lisibles, la règle
--  n'existe qu'à un seul endroit, et `security definer` évite que la
--  politique de `profils` ne se rappelle elle-même en boucle.
-- =====================================================================

create or replace function public.est_admin()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from profils
    where id = auth.uid() and role = 'admin'
  );
$$;

create or replace function public.est_staff()
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (select 1 from profils where id = auth.uid());
$$;

-- Le coach peut-il écrire sur cette équipe ?
create or replace function public.peut_ecrire_equipe(p_equipe_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select p_equipe_id is not null and (
    est_admin() or exists (
      select 1
      from equipes e
      join coach_categories cc
        on  cc.categorie_id = e.categorie_id
        and (cc.genre = 'T' or cc.genre = e.genre)
      where e.id = p_equipe_id
        and cc.utilisateur_id = auth.uid()
    )
  );
$$;

-- La catégorie qui accueille une génération donnée.
create or replace function public.categorie_de_generation(p_generation text)
returns uuid
language sql stable
as $$
  select id from categories where p_generation = any (generations) limit 1;
$$;

-- Le coach peut-il écrire sur cette fiche de joueur ?
--
-- Un joueur n'ayant pas d'équipe, on passe par sa génération pour
-- retrouver sa catégorie, et par son genre pour départager masculins et
-- féminines d'une même catégorie.
create or replace function public.peut_ecrire_joueur(p_generation text, p_genre char)
returns boolean
language sql stable security definer set search_path = public
as $$
  select est_admin() or exists (
    select 1
    from coach_categories cc
    where cc.utilisateur_id = auth.uid()
      and cc.categorie_id = categorie_de_generation(p_generation)
      and (cc.genre = 'T' or cc.genre = p_genre)
  );
$$;

-- Même question pour une rencontre : on remonte à son équipe.
create or replace function public.peut_ecrire_rencontre(p_rencontre_id uuid)
returns boolean
language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from rencontres r
    where r.id = p_rencontre_id
      and peut_ecrire_equipe(r.equipe_id)
  );
$$;


-- =====================================================================
--  6. POLITIQUES RLS
--
--  Lecture publique sur tout ce que l'application affiche : l'app est
--  consultable sans compte. Seuls `profils` et `coach_categories`
--  échappent à la règle — ce sont des données de personnes.
-- =====================================================================

alter table saisons          enable row level security;
alter table categories       enable row level security;
alter table equipes          enable row level security;
alter table adversaires      enable row level security;
alter table competitions     enable row level security;
alter table engagements      enable row level security;
alter table joueurs          enable row level security;
alter table rencontres       enable row level security;
alter table buts             enable row level security;
alter table tirs_au_but      enable row level security;
alter table profils          enable row level security;
alter table coach_categories enable row level security;

-- ---------- lecture ----------
create policy lecture on saisons      for select using (true);
create policy lecture on categories   for select using (true);
create policy lecture on equipes      for select using (true);
create policy lecture on adversaires  for select using (true);
create policy lecture on competitions for select using (true);
create policy lecture on engagements  for select using (true);
create policy lecture on joueurs      for select using (true);
create policy lecture on rencontres   for select using (true);
create policy lecture on buts         for select using (true);
create policy lecture on tirs_au_but  for select using (true);

-- ---------- structure du club : admin seul ----------
create policy ecriture on saisons     for all to authenticated
  using (est_admin()) with check (est_admin());
create policy ecriture on categories  for all to authenticated
  using (est_admin()) with check (est_admin());
create policy ecriture on equipes     for all to authenticated
  using (est_admin()) with check (est_admin());

-- ---------- engagements : le coach gère les compétitions de SES équipes ----------
-- Inscrire une équipe à une coupe en cours de saison est un acte courant,
-- pas une décision de structure : le coach doit pouvoir le faire seul,
-- mais uniquement sur les équipes des catégories qui lui sont attribuées.
create policy ecriture on engagements for all to authenticated
  using      (peut_ecrire_equipe(equipe_id))
  with check (peut_ecrire_equipe(equipe_id));

-- ---------- listes partagées : tout le staff ----------
-- Un coach doit pouvoir créer un adversaire ou une compétition au moment
-- où il saisit un match, sans attendre un admin.
create policy ecriture on adversaires  for all to authenticated
  using (est_staff()) with check (est_staff());
create policy ecriture on competitions for all to authenticated
  using (est_staff()) with check (est_staff());

-- ---------- joueurs ----------
-- L'habilitation passe par la génération et le genre, puisqu'un joueur
-- n'a pas d'équipe. `with check` autant que `using` : sans lui, un coach
-- pourrait faire passer un de ses licenciés dans une autre catégorie.
create policy ecriture on joueurs for all to authenticated
  using      (peut_ecrire_joueur(generation, genre))
  with check (peut_ecrire_joueur(generation, genre));

-- ---------- rencontres et leur détail ----------
create policy ecriture on rencontres for all to authenticated
  using      (peut_ecrire_equipe(equipe_id))
  with check (peut_ecrire_equipe(equipe_id));

create policy ecriture on buts for all to authenticated
  using      (peut_ecrire_rencontre(rencontre_id))
  with check (peut_ecrire_rencontre(rencontre_id));

create policy ecriture on tirs_au_but for all to authenticated
  using      (peut_ecrire_rencontre(rencontre_id))
  with check (peut_ecrire_rencontre(rencontre_id));

-- ---------- comptes ----------
-- Chacun lit sa propre fiche ; l'admin voit et gère tout le staff.
create policy lecture_soi on profils for select to authenticated
  using (id = auth.uid() or est_admin());
create policy ecriture on profils for all to authenticated
  using (est_admin()) with check (est_admin());

create policy lecture_soi on coach_categories for select to authenticated
  using (utilisateur_id = auth.uid() or est_admin());
create policy ecriture on coach_categories for all to authenticated
  using (est_admin()) with check (est_admin());


-- =====================================================================
--  7. VUE DE CONFORT
--
--  Les classements (buteurs, passeurs, décisifs) ont besoin de croiser
--  buts → rencontres → equipes à chaque fois. Cette vue fait la jointure
--  une bonne fois, pour que les repositories Dart restent courts et que
--  le filtrage par saison, catégorie ou compétition se fasse côté
--  serveur, comme on l'a mis en place pour les écrans publics.
--
--  Une vue hérite des politiques RLS de ses tables : rien à sécuriser
--  de plus, la lecture reste publique.
-- =====================================================================

create view v_buts as
select
  b.id,
  b.rencontre_id,
  b.joueur_id,
  b.passeur_id,
  b.csc,
  r.saison_id,
  r.equipe_id,
  r.competition_id,
  r.phase,
  r.date_heure,
  e.categorie_id,
  e.genre,
  c.type as type_competition
from buts b
join rencontres   r on r.id = b.rencontre_id
join equipes      e on e.id = r.equipe_id
join competitions c on c.id = r.competition_id
where r.statut = 'jouee'
  and r.forfait is null;   -- un forfait n'a pas de buteur
