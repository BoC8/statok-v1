-- =====================================================================
--  STATOK — données de référence v2
--  À exécuter APRÈS schema_v2.sql, sur le nouveau projet Supabase.
--
--  Ce fichier est rejouable : il ne crée rien deux fois.
--
--  Il couvre les saisons, les catégories et les treize équipes.
--  Les compétitions et les engagements viendront dans un second fichier,
--  quand tu m'auras donné les championnats de chaque équipe, phase par
--  phase, pour 2026-2027.
-- =====================================================================


-- ---------------------------------------------------------------------
--  Saisons
--
--  2025-2026 n'est là que pour accueillir l'historique migré depuis
--  l'ancienne base. Supprime la ligne si tu repars de zéro.
-- ---------------------------------------------------------------------
insert into saisons (annee_debut, libelle, en_cours) values
  (2025, '2025-2026', false),
  (2026, '2026-2027', true)
on conflict (annee_debut) do nothing;


-- ---------------------------------------------------------------------
--  Catégories
--
--  `ordre` fixe la position d'affichage partout : les plus jeunes en
--  premier. Les trois libellés sont ceux qui s'affichent tels quels.
-- ---------------------------------------------------------------------
--  `generations` dit quelles tranches d'âge la catégorie accueille.
--  C'est par là qu'on retrouve la catégorie d'un joueur, qui n'a pas
--  d'équipe fixe. Les trois listes doivent rester disjointes.
insert into categories (libelle, ordre, generations) values
  ('U14 – U15', 1, '{13,14,15}'),
  ('U16 – U18', 2, '{16,17,18}'),
  ('Seniors',   3, '{senior}')
on conflict (libelle) do update set generations = excluded.generations;


-- ---------------------------------------------------------------------
--  Équipes — treize au total
--
--  `ordre` est la position dans son groupe, pas un niveau hiérarchique.
--  Il reproduit l'ordre de ta maquette, qui n'est pas alphabétique :
--  chez les U16-U18 masculins, U18 A passe avant U17.
--
--  Orthographe : « Seniors » sans accent partout, y compris dans le nom
--  des équipes, pour ne pas avoir « Seniors » en catégorie et
--  « Séniors A » en équipe sur le même écran.
-- ---------------------------------------------------------------------
insert into equipes (categorie_id, genre, nom, ordre)
select c.id, v.genre, v.nom, v.ordre
from (values
  -- U14 – U15
  ('U14 – U15', 'M', 'U15 A',     1),
  ('U14 – U15', 'M', 'U15 B',     2),
  ('U14 – U15', 'M', 'U15 C',     3),
  ('U14 – U15', 'F', 'U15 F',     1),
  -- U16 – U18
  ('U16 – U18', 'M', 'U18 A',     1),
  ('U16 – U18', 'M', 'U17',       2),
  ('U16 – U18', 'M', 'U18 B',     3),
  ('U16 – U18', 'F', 'U18 F',     1),
  -- Seniors
  ('Seniors',   'M', 'Seniors A', 1),
  ('Seniors',   'M', 'Seniors B', 2),
  ('Seniors',   'M', 'Seniors C', 3),
  ('Seniors',   'M', 'Seniors D', 4),
  ('Seniors',   'F', 'Seniors F', 1)
) as v (categorie, genre, nom, ordre)
join categories c on c.libelle = v.categorie
on conflict (categorie_id, genre, nom) do nothing;


-- =====================================================================
--  Vérification
--  Doit afficher les six groupes, leurs équipes dans le bon ordre,
--  et un total de 13.
-- =====================================================================
select
  c.ordre                                   as rang,
  c.libelle                                 as categorie,
  case e.genre when 'M' then 'Masculins' else 'Féminines' end as genre,
  string_agg(e.nom, ' · ' order by e.ordre) as equipes,
  count(*)                                  as nb
from equipes e
join categories c on c.id = e.categorie_id
where e.actif
group by c.ordre, c.libelle, e.genre
order by c.ordre, e.genre desc;
