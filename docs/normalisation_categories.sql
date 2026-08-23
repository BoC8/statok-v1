-- =====================================================================
-- STATOK — Normalisation des catégories
--
-- Date : 23 août 2026
--
-- CONSTAT
--   La colonne `categorie` contient deux écritures de la même chose :
--     'U16 - U17 - U18'  (forme d'affichage, avec espaces) — 72 matchs
--     'U16-17-18'        (forme normalisée)                —  1 match
--   Le code s'en accommode via _categoriePourDb / _categorieMatches,
--   dupliqués dans 9 fichiers. Cette dette empêche de filtrer côté serveur.
--
-- OBJECTIF
--   Une seule écriture par catégorie, celle que produit déjà
--   EquipeService.categoriePourDb() :
--     'U14 - U15'         -> 'U14-15'
--     'U16 - U17 - U18'   -> 'U16-17-18'
--     'SENIORS'           -> 'Seniors'
--
-- IDEMPOTENT : rejouable sans effet une fois la normalisation faite.
-- NE TOUCHE PAS à joueurs.categorie_detail ('14','15','Senior'…),
-- qui est une autre notion et reste inchangée.
--
-- ⚠️ Exécuter le bloc AVANT, puis les UPDATE, puis le bloc APRÈS,
--    et comparer les totaux : aucune ligne ne doit disparaître.
-- =====================================================================


-- ---------------------------------------------------------------------
-- AVANT — photographie de l'existant
-- ---------------------------------------------------------------------
select 'AVANT' as moment, 'matchs' as source, categorie, count(*) as nb
from public.matchs group by categorie
union all select 'AVANT', 'programmations', categorie, count(*)
from public.programmations group by categorie
union all select 'AVANT', 'joueurs', categorie, count(*)
from public.joueurs group by categorie
union all select 'AVANT', 'equipes', categorie, count(*)
from public.equipes group by categorie
union all select 'AVANT', 'classements', categorie, count(*)
from public.classements group by categorie
order by source, categorie;


-- ---------------------------------------------------------------------
-- NORMALISATION
-- ---------------------------------------------------------------------

-- matchs
update public.matchs set categorie = 'U14-15'    where categorie = 'U14 - U15';
update public.matchs set categorie = 'U16-17-18' where categorie = 'U16 - U17 - U18';
update public.matchs set categorie = 'Seniors'   where categorie = 'SENIORS';

-- programmations
update public.programmations set categorie = 'U14-15'    where categorie = 'U14 - U15';
update public.programmations set categorie = 'U16-17-18' where categorie = 'U16 - U17 - U18';
update public.programmations set categorie = 'Seniors'   where categorie = 'SENIORS';

-- joueurs
update public.joueurs set categorie = 'U14-15'    where categorie = 'U14 - U15';
update public.joueurs set categorie = 'U16-17-18' where categorie = 'U16 - U17 - U18';
update public.joueurs set categorie = 'Seniors'   where categorie = 'SENIORS';

-- equipes
update public.equipes set categorie = 'U14-15'    where categorie = 'U14 - U15';
update public.equipes set categorie = 'U16-17-18' where categorie = 'U16 - U17 - U18';
update public.equipes set categorie = 'Seniors'   where categorie = 'SENIORS';

-- classements
update public.classements set categorie = 'U14-15'    where categorie = 'U14 - U15';
update public.classements set categorie = 'U16-17-18' where categorie = 'U16 - U17 - U18';
update public.classements set categorie = 'Seniors'   where categorie = 'SENIORS';


-- ---------------------------------------------------------------------
-- APRÈS — vérification
--
-- Attendu : uniquement 'U14-15', 'U16-17-18' ou 'Seniors' dans la colonne
-- categorie, et des totaux par table identiques à ceux du bloc AVANT.
-- ---------------------------------------------------------------------
select 'APRÈS' as moment, 'matchs' as source, categorie, count(*) as nb
from public.matchs group by categorie
union all select 'APRÈS', 'programmations', categorie, count(*)
from public.programmations group by categorie
union all select 'APRÈS', 'joueurs', categorie, count(*)
from public.joueurs group by categorie
union all select 'APRÈS', 'equipes', categorie, count(*)
from public.equipes group by categorie
union all select 'APRÈS', 'classements', categorie, count(*)
from public.classements group by categorie
order by source, categorie;


-- ---------------------------------------------------------------------
-- FILET DE SÉCURITÉ — doit renvoyer 0 ligne
-- Détecte toute catégorie restée hors des trois valeurs attendues.
-- ---------------------------------------------------------------------
select 'matchs' as source, categorie from public.matchs
where categorie not in ('U14-15','U16-17-18','Seniors')
union all select 'programmations', categorie from public.programmations
where categorie not in ('U14-15','U16-17-18','Seniors')
union all select 'joueurs', categorie from public.joueurs
where categorie not in ('U14-15','U16-17-18','Seniors')
union all select 'equipes', categorie from public.equipes
where categorie not in ('U14-15','U16-17-18','Seniors')
union all select 'classements', categorie from public.classements
where categorie not in ('U14-15','U16-17-18','Seniors');
