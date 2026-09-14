-- =====================================================================
--  Un compte coach limité à une seule catégorie
--
--  À exécuter APRÈS avoir créé le compte dans
--  Authentication → Users → Add user (avec « Auto Confirm User » coché).
--
--  Remplace l'adresse et le nom ci-dessous.
-- =====================================================================

-- 1. Rattacher le compte au staff, en tant que coach (pas admin)
insert into profils (id, nom, role)
select id, 'Coach U14-U15 M', 'coach'
from auth.users
where email = 'coach.u15@exemple.fr';

-- 2. Lui donner UNE catégorie, masculins seulement
--    genre : 'M', 'F', ou 'T' pour les deux
insert into coach_categories (utilisateur_id, categorie_id, genre)
select p.id, c.id, 'M'
from profils p, categories c
where p.nom = 'Coach U14-U15 M'
  and c.libelle = 'U14 – U15';


-- =====================================================================
--  Contrôle : qui a le droit d'écrire sur quoi
--
--  Un admin n'a aucune ligne dans coach_categories — c'est justement ce
--  qui lui donne accès à tout.
-- =====================================================================
select p.nom,
       p.role,
       u.email,
       coalesce(
         string_agg(
           c.libelle || ' ' || cc.genre,
           ', ' order by c.ordre
         ),
         'tout le club'
       ) as habilitations
from profils p
join auth.users u on u.id = p.id
left join coach_categories cc on cc.utilisateur_id = p.id
left join categories c on c.id = cc.categorie_id
group by p.nom, p.role, u.email
order by p.role, p.nom;


-- Et concrètement, équipe par équipe, pour un coach donné :
select e.nom as equipe,
       case
         when exists (
           select 1
           from coach_categories cc
           join profils p on p.id = cc.utilisateur_id
           where p.nom = 'Coach U14-U15 M'
             and cc.categorie_id = e.categorie_id
             and (cc.genre = 'T' or cc.genre = e.genre)
         ) then 'oui'
         else 'non'
       end as peut_modifier
from equipes e
join categories c on c.id = e.categorie_id
where e.actif
order by c.ordre, e.genre desc, e.ordre;
