-- =====================================================================
--  FORFAITS — à la place de « reporté » et « annulé »
-- =====================================================================
--
--  POURQUOI CE CHANGEMENT
--    « Reporté » et « annulé » n'ont jamais servi : un match reporté
--    change de date, on corrige la date ; un match annulé disparaît du
--    calendrier, on supprime la fiche. Ce qui manquait vraiment, c'est
--    le forfait — fréquent chez les jeunes, et qui compte au classement.
--
--  LE CHOIX DE MODÉLISATION
--    Un forfait N'EST PAS un cinquième statut. C'est un match JOUÉ,
--    avec un score de 3–0, plus la mention de qui n'est pas venu. Le
--    dire ainsi vaut mieux que d'inventer un statut, parce que tout ce
--    qui compte les matchs joués — bilans, séries de résultats,
--    pourcentages de victoires — continue de fonctionner sans qu'on y
--    touche. Un forfait compte comme une victoire ou une défaite, ce
--    qu'il est.
--
--    D'où une colonne `forfait` à trois valeurs : null (match
--    disputé), 'nous' (le FCPB ne s'est pas présenté, donc 0–3),
--    'eux' (l'adversaire ne s'est pas présenté, donc 3–0).
--
--  À PASSER DANS L'ÉDITEUR SQL DE SUPABASE, EN UNE FOIS.
--  Rejouable : une deuxième exécution ne change rien.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
--  1. La colonne
-- ---------------------------------------------------------------------
alter table rencontres
  add column if not exists forfait text;

alter table rencontres
  drop constraint if exists rencontres_forfait_valeur;
alter table rencontres
  add constraint rencontres_forfait_valeur
  check (forfait is null or forfait in ('nous', 'eux'));


-- ---------------------------------------------------------------------
--  2. Les rencontres reportées ou annulées qui existent déjà
--
--  On ne peut pas deviner ce qu'elles devraient devenir : « reporté »
--  ne dit pas qui a déclaré forfait, et le plus souvent il ne s'agissait
--  pas d'un forfait du tout. Elles repassent donc en « à venir », leur
--  état d'origine, et le coach les reprend à la main s'il y a lieu.
--
--  Aucune donnée n'est perdue au passage : la contrainte
--  `rencontres_score_coherent` garantit qu'un match non joué n'a jamais
--  porté de score.
-- ---------------------------------------------------------------------
do $$
declare
  v_nb int;
  r    record;
begin
  select count(*) into v_nb
    from rencontres
   where statut in ('reportee', 'annulee');

  if v_nb = 0 then
    raise notice 'Aucune rencontre reportée ou annulée : rien à reprendre.';
  else
    raise notice '% rencontre(s) repassée(s) en « à venir » :', v_nb;
    for r in
      select rc.date_heure, e.nom as equipe, a.nom as adversaire, rc.statut
        from rencontres  rc
        join equipes     e on e.id = rc.equipe_id
        join adversaires a on a.id = rc.adversaire_id
       where rc.statut in ('reportee', 'annulee')
       order by rc.date_heure
    loop
      raise notice '  · % — % contre % (était « % »)',
        to_char(r.date_heure, 'DD/MM/YYYY'), r.equipe, r.adversaire, r.statut;
    end loop;

    update rencontres
       set statut = 'programmee'
     where statut in ('reportee', 'annulee');
  end if;
end $$;


-- ---------------------------------------------------------------------
--  3. Resserrer les statuts admis
--
--  L'ancienne contrainte est déclarée sur la colonne, donc nommée
--  automatiquement. On la retrouve par sa définition plutôt que par un
--  nom qu'on devinerait.
-- ---------------------------------------------------------------------
do $$
declare c record;
begin
  for c in
    select conname
      from pg_constraint
     where conrelid = 'public.rencontres'::regclass
       and contype  = 'c'
       and pg_get_constraintdef(oid) ilike '%reportee%'
  loop
    execute format('alter table rencontres drop constraint %I', c.conname);
  end loop;
end $$;

alter table rencontres
  drop constraint if exists rencontres_statut_valide;
alter table rencontres
  add constraint rencontres_statut_valide
  check (statut in ('programmee', 'jouee'));


-- ---------------------------------------------------------------------
--  4. Ce qu'un forfait doit être
--
--  Le score n'est pas une saisie mais une conséquence : 3–0 pour celui
--  qui s'est déplacé. L'écrire en contrainte plutôt qu'en commentaire
--  évite qu'un jour une écriture passée à côté de l'application laisse
--  un forfait 2–1 dans la base.
--
--  Pas de séance de tirs au but non plus : 3–0 n'est pas un nul, et la
--  contrainte `rencontres_tab_coherent` le refuserait de toute façon.
--  On le redit ici pour que la règle se lise d'un seul endroit.
-- ---------------------------------------------------------------------
alter table rencontres
  drop constraint if exists rencontres_forfait_coherent;
alter table rencontres
  add constraint rencontres_forfait_coherent check (
    forfait is null or (
      statut     = 'jouee'
      and tab_pour   is null
      and tab_contre is null
      and (
        (forfait = 'nous' and score_pour = 0 and score_contre = 3) or
        (forfait = 'eux'  and score_pour = 3 and score_contre = 0)
      )
    )
  );


-- ---------------------------------------------------------------------
--  5. Un forfait n'a pas de buteur
--
--  L'application n'en enregistre aucun — elle ne propose même pas la
--  feuille de match sur un forfait. La vue le garantit quand même :
--  si une ligne de but survivait à un match repassé en forfait, elle
--  gonflerait le classement des buteurs de trois buts fantômes.
--
--  C'est le seul endroit où le filtre doit vivre, puisque tous les
--  classements passent par `v_buts`.
-- ---------------------------------------------------------------------
create or replace view v_buts as
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
  and r.forfait is null;

commit;


-- =====================================================================
--  VÉRIFICATION — à lire après coup
-- =====================================================================
select
  count(*) filter (where statut = 'programmee')            as a_venir,
  count(*) filter (where statut = 'jouee' and forfait is null) as disputees,
  count(*) filter (where forfait = 'nous')                 as forfaits_nous,
  count(*) filter (where forfait = 'eux')                  as forfaits_eux
from rencontres;
