-- =====================================================================
--  STATOK — nouveaux licenciés U16 – U18 masculins
--
--  26 joueurs : 5 de génération 18, 5 de 17, 16 de 16.
--
--  Pas de catégorie ni d'équipe à renseigner : la génération suffit.
--  C'est `categories.generations` qui rattache un 17 à « U16 – U18 »,
--  et ce sont ses buts qui diront plus tard avec quelles équipes il a
--  réellement joué.
--
--  REJOUABLE
--    `joueurs` n'a aucune contrainte d'unicité sur le nom — deux frères
--    homonymes doivent pouvoir coexister. Le garde-fou est donc ici :
--    on n'insère que ce qui n'existe pas déjà à l'identique. Rejouer ce
--    fichier ne crée aucun doublon.
-- =====================================================================

insert into joueurs (prenom, nom, generation, genre, actif)
select v.prenom, v.nom, v.generation, 'M', true
from (values
  ('Yanis', 'Leger', '18'),
  ('Diego', 'Chauvin', '18'),
  ('Noah', 'Chauvin', '18'),
  ('Luca', 'Fereal', '18'),
  ('Antonin', 'Mariaud', '18'),
  ('Mahé', 'Brunel', '17'),
  ('Tom', 'Forgeau', '17'),
  ('Adhan', 'Foucher-Masson', '17'),
  ('Harouna', 'Leparoux', '17'),
  ('Loan', 'Forgeau', '17'),
  ('Jolan', 'Clermont', '16'),
  ('Cameron', 'Rouziou-Mace', '16'),
  ('Lucas', 'Letourneaux', '16'),
  ('Loïs', 'Gerbaud', '16'),
  ('Leo', 'Rochet', '16'),
  ('Yaël', 'Forget', '16'),
  ('Laël', 'Clermont', '16'),
  ('Luka', 'Juste', '16'),
  ('Elliot', 'Corneau', '16'),
  ('Killian', 'Quansha-Le-Breton', '16'),
  ('Evan', 'Touatit', '16'),
  ('Quentin', 'Jousset', '16'),
  ('Ilan', 'Leblay', '16'),
  ('Angelo', 'Chatelain-Hubert', '16'),
  ('Pierre', 'Bomme', '16'),
  ('Maxime', 'Goupil-Gerard', '16')
) as v (prenom, nom, generation)
where not exists (
  select 1 from joueurs j
  where j.prenom = v.prenom and j.nom = v.nom
);


-- =====================================================================
--  Contrôles
-- =====================================================================

-- 1. Les effectifs par génération
select generation,
       case generation when 'senior' then 'Séniors' else 'U' || generation end
         as libelle,
       genre,
       count(*) as licencies
from joueurs
where actif
group by generation, genre
order by array_position(
  array['13','14','15','16','17','18','senior'], generation
), genre;

-- 2. Combien chaque équipe peut désormais en aligner
with rangs as (
  select * from unnest(
    array['13','14','15','16','17','18','senior'],
    array[1, 2, 3, 4, 5, 6, 7]
  ) as t(generation, rang)
)
select e.nom as equipe,
       e.generation_max as plafond,
       count(j.id) as eligibles
from equipes e
join categories c on c.id = e.categorie_id
join rangs rp on rp.generation = e.generation_max
left join joueurs j
  on j.actif
 and j.genre = e.genre
 and (select rang from rangs where generation = j.generation) <= rp.rang
where e.actif
group by c.ordre, e.nom, e.genre, e.generation_max, e.ordre
order by c.ordre, e.genre desc, e.ordre;

-- 3. Les homonymes, à relire une fois
--    Trois familles ont plusieurs licenciés : ce sont probablement des
--    frères, mais autant le vérifier plutôt que de découvrir un doublon
--    dans le classement des buteurs.
select nom,
       string_agg(
         prenom || ' (' ||
         case generation when 'senior' then 'Séniors' else 'U' || generation end
         || ')', ', ' order by prenom
       ) as licencies
from joueurs
where actif
group by nom
having count(*) > 1
order by nom;
