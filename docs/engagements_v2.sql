-- =====================================================================
--  STATOK — compétitions et engagements 2026-2027
--  À exécuter APRÈS schema_v2.sql et seed_v2.sql.
--
--  Ce fichier est rejouable : il ne crée rien deux fois.
-- =====================================================================


-- ---------------------------------------------------------------------
--  Compétitions
--
--  Le nom ne porte jamais la catégorie : « Départemental 3 » est UNE
--  ligne, partagée par les Seniors A (masculins) et les Seniors F
--  (féminines), qui ne jouent évidemment pas le même championnat.
--  C'est l'engagement — donc l'équipe — qui tranche. Conséquence à
--  connaître : dans le filtre « Compétition » vu depuis « Tout le club »,
--  choisir « Départemental 3 » ramènera les matchs des deux équipes.
--  Dès qu'une catégorie est sélectionnée, l'ambiguïté disparaît.
--
--  « Match amical » est OBLIGATOIRE : rencontres.competition_id ne peut
--  pas être nul, un amical doit donc pointer quelque part.
-- ---------------------------------------------------------------------
insert into competitions (nom, type) values
  ('Départemental 1',  'championnat'),
  ('Départemental 2',  'championnat'),
  ('Départemental 3',  'championnat'),
  ('Départemental 4',  'championnat'),
  ('Départemental 5',  'championnat'),
  ('Départemental à 8', 'championnat'),
  ('Match amical',      'amical'),
  ('Tournoi',           'amical')
on conflict (nom) do nothing;

-- Les coupes du club. Ajoute les tiennes ici au fil des engagements.
insert into competitions (nom, type) values
  ('Coupe de France',   'coupe'),
  ('Coupe Gambardella', 'coupe')
on conflict (nom) do nothing;


-- ---------------------------------------------------------------------
--  Engagements 2026-2027
--
--  Seniors : phase 0 — un seul championnat toute l'année.
--  Jeunes  : phase 1 uniquement. Les phases 2 et 3 se décident en cours
--            de saison selon les montées et descentes ; le bloc en fin
--            de fichier sert à les ajouter le moment venu.
-- ---------------------------------------------------------------------
insert into engagements (equipe_id, competition_id, saison_id, phase)
select e.id, k.id, s.id, v.phase
from (values
  -- Seniors — pas de phase
  ('Seniors A', 'Départemental 3',  0),
  ('Seniors B', 'Départemental 4',  0),
  ('Seniors C', 'Départemental 5',  0),
  ('Seniors D', 'Départemental 5',  0),
  ('Seniors F', 'Départemental 3',  0),
  -- U16 – U18 — phase 1
  ('U18 A',     'Départemental 1',  1),
  ('U17',       'Départemental 2',  1),
  ('U18 B',     'Départemental 4',  1),
  ('U18 F',     'Départemental 2',  1),
  -- U14 – U15 — phase 1
  ('U15 A',     'Départemental 2',   1),
  ('U15 B',     'Départemental 4',   1),
  ('U15 C',     'Départemental 5',   1),
  ('U15 F',     'Départemental à 8', 1)
) as v (equipe, competition, phase)
join equipes      e on e.nom  = v.equipe
join competitions k on k.nom  = v.competition
join saisons      s on s.annee_debut = 2026
on conflict (equipe_id, competition_id, saison_id, phase) do nothing;


-- ---------------------------------------------------------------------
--  Coupes — seulement les équipes réellement engagées
--
--  Contrairement aux amicaux, une coupe ne concerne que les équipes qui
--  y sont inscrites : c'est ce qui fait que le formulaire de saisie des
--  U15 B ne proposera jamais « Coupe Gambardella ».
--
--  Phase 0 : une coupe traverse la saison, elle ne suit pas le découpage
--  en phases du championnat des jeunes.
-- ---------------------------------------------------------------------
insert into engagements (equipe_id, competition_id, saison_id, phase)
select e.id, k.id, s.id, 0
from (values
  ('U18 A',     'Coupe Gambardella'),
  ('Seniors A', 'Coupe de France'),
  ('Seniors F', 'Coupe de France')
) as v (equipe, competition)
join equipes      e on e.nom = v.equipe
join competitions k on k.nom = v.competition
join saisons      s on s.annee_debut = 2026
on conflict (equipe_id, competition_id, saison_id, phase) do nothing;


-- ---------------------------------------------------------------------
--  Amicaux : toutes les équipes, toujours
--
--  Chaque équipe est engagée d'office dans les compétitions de type
--  « amical », sans quoi le formulaire de saisie — qui propose les
--  compétitions de l'équipe — ne permettrait pas d'enregistrer un match
--  de préparation.
--
--  La requête part du TYPE, pas du nom : si tu ajoutes plus tard une
--  autre compétition amicale, il suffit de rejouer ce bloc pour que les
--  treize équipes en bénéficient.
-- ---------------------------------------------------------------------
insert into engagements (equipe_id, competition_id, saison_id, phase)
select e.id, k.id, s.id, 0
from equipes e
cross join competitions k
cross join saisons s
where e.actif
  and k.type = 'amical'
  and s.annee_debut = 2026
on conflict (equipe_id, competition_id, saison_id, phase) do nothing;


-- =====================================================================
--  Vérification
--  Doit afficher les treize équipes avec, pour chacune, ce que le
--  formulaire de saisie proposera dans sa liste de compétitions.
-- =====================================================================
select
  c.libelle                                   as categorie,
  case e.genre when 'M' then 'M' else 'F' end as g,
  e.nom                                       as equipe,
  string_agg(
    k.nom || case when g.phase > 0 then ' (ph. ' || g.phase || ')' else '' end,
    ' · ' order by k.type, k.nom
  )                                           as competitions
from engagements g
join equipes      e on e.id = g.equipe_id
join categories   c on c.id = e.categorie_id
join competitions k on k.id = g.competition_id
join saisons      s on s.id = g.saison_id
where s.annee_debut = 2026
group by c.ordre, c.libelle, e.genre, e.ordre, e.nom
order by c.ordre, e.genre desc, e.ordre;

-- Aucune équipe oubliée ? Cette requête doit ne rien renvoyer.
select e.nom as equipe_sans_engagement
from equipes e
where e.actif
  and not exists (
    select 1 from engagements g
    join saisons s on s.id = g.saison_id and s.annee_debut = 2026
    where g.equipe_id = e.id
  );


-- =====================================================================
--  MODÈLE — phases 2 et 3, à exécuter quand elles seront connues
--
--  Recopie ce bloc, décommente-le, mets la phase et les compétitions
--  réelles. Rien d'autre à toucher : le passé de l'équipe ne bouge pas,
--  ses anciennes rencontres restent rattachées à la phase où elles ont
--  été jouées.
-- =====================================================================
--
-- insert into engagements (equipe_id, competition_id, saison_id, phase)
-- select e.id, k.id, s.id, v.phase
-- from (values
--   ('U18 A', 'Départemental 1', 2),
--   ('U17',   'Départemental 1', 2),   -- monté
--   ('U18 B', 'Départemental 5', 2),   -- descendu
--   ('U18 F', 'Départemental 2', 2),
--   ('U15 A', 'Départemental 2', 2),
--   ('U15 B', 'Départemental 4', 2),
--   ('U15 C', 'Départemental 5', 2),
--   ('U15 F', 'Départemental A8', 2)
-- ) as v (equipe, competition, phase)
-- join equipes      e on e.nom = v.equipe
-- join competitions k on k.nom = v.competition
-- join saisons      s on s.annee_debut = 2026
-- on conflict (equipe_id, competition_id, saison_id, phase) do nothing;
