-- =====================================================================
--  STATOK — correctif : quelle tranche d'âge chaque équipe accueille
--
--  À exécuter sur la base v2.
--  Rejouable sans risque.
--
--  LE PROBLÈME
--    La catégorie ne suffit pas à dire qui peut jouer où. « U16 – U18 »
--    contient l'U18 A, l'U17 et l'U18 B : un licencié de génération 18
--    peut évoluer en U18 A ou en U18 B, mais pas en U17 — il est trop
--    vieux d'un an, alors même que les trois équipes appartiennent à la
--    même catégorie.
--
--    Sans cette information, le formulaire de saisie proposait les
--    soixante licenciés du club pour n'importe quelle équipe.
--
--  LA RÈGLE
--    Un joueur peut évoluer dans une équipe si sa génération est
--    inférieure ou égale au plafond de l'équipe. Le surclassement — un
--    jeune qui joue plus haut — est donc autorisé ; l'inverse ne l'est
--    pas.
-- =====================================================================

begin;

alter table equipes
  add column if not exists generation_max text;

update equipes set generation_max = '15'     where nom in ('U15 A', 'U15 B', 'U15 C', 'U15 F');
update equipes set generation_max = '17'     where nom = 'U17';
update equipes set generation_max = '18'     where nom in ('U18 A', 'U18 B', 'U18 F');
update equipes set generation_max = 'senior' where nom like 'Seniors%';

-- Filet de sécurité : toute équipe encore sans plafond accueille tout
-- le monde. Mieux vaut une liste trop large qu'une équipe impossible à
-- renseigner.
update equipes set generation_max = 'senior' where generation_max is null;

alter table equipes alter column generation_max set not null;

do $$
begin
  if not exists (
    select 1 from pg_constraint where conname = 'equipes_generation_max_check'
  ) then
    alter table equipes add constraint equipes_generation_max_check
      check (generation_max in ('13','14','15','16','17','18','senior'));
  end if;
end $$;

commit;


-- =====================================================================
--  Contrôle : combien de licenciés chaque équipe peut aligner
--
--  Les U17 doivent avoir moins de joueurs éligibles que les U18, et les
--  Seniors doivent tous les accepter.
-- =====================================================================
with rangs as (
  select * from unnest(
    array['13','14','15','16','17','18','senior'],
    array[1, 2, 3, 4, 5, 6, 7]
  ) as t(generation, rang)
)
select c.libelle as categorie,
       e.nom     as equipe,
       e.genre,
       e.generation_max as plafond,
       count(j.id) as licencies_eligibles
from equipes e
join categories c on c.id = e.categorie_id
join rangs rp on rp.generation = e.generation_max
left join joueurs j
  on j.actif
 and j.genre = e.genre
 and (select rang from rangs where generation = j.generation) <= rp.rang
where e.actif
group by c.ordre, c.libelle, e.nom, e.genre, e.generation_max, e.ordre
order by c.ordre, e.genre desc, e.ordre;
