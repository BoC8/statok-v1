-- =====================================================================
--  STATOK — fusion des doublons d'adversaires
--
--  Le district n'a pas de nomenclature : « Derval » et « Derval SC 1 »
--  sont la même équipe saisie deux fois, et chacune porte une partie des
--  rencontres. Ce fichier les réunit.
--
--  ------------------------------------------------------------------
--  LES DOUZE CIBLES EXISTENT DÉJÀ — ET C'EST VÉRIFIÉ AVANT D'AGIR
--  ------------------------------------------------------------------
--  Chaque ligne est donc une FUSION : les rencontres de la source sont
--  rattachées à la cible, puis la source est supprimée.
--
--  Une cible introuvable ARRÊTE TOUT, et ce n'est pas un excès de
--  prudence. Si « Guémené 1 » était mal orthographié ici, la seule
--  autre issue serait de renommer la source — ce qui fabriquerait une
--  TROISIÈME variante du nom au lieu d'en supprimer une. Exactement le
--  désordre qu'on est en train de nettoyer, en pire, et sans rien qui
--  le signale.
--
--  Le contrôle porte sur les douze lignes d'un coup : tu vois toutes
--  les fautes de frappe en une fois, pas une par exécution.
--
--  TOUT OU RIEN
--    Le bloc est une transaction unique. Si une seule ligne échoue,
--    aucune ne passe : mieux vaut douze doublons qu'une base à moitié
--    recousue.
-- =====================================================================

begin;

drop table if exists _fusions;
drop table if exists _journal;

create table _fusions (ordre serial, source text, cible text);
create table _journal (
  ordre     int,
  source    text,
  cible     text,
  action    text,
  rencontres int
);

-- ---------------------------------------------------------------------
--  La liste. « Vay-Marsac » et « Vay-Marsac FC 1 » visent la même
--  cible : les deux s'y fondent, il n'y a pas de conflit.
-- ---------------------------------------------------------------------
insert into _fusions (source, cible) values
  ('Cambon 2',            'Cambon UBCC 2'),
  ('Derval',              'Derval SC 1'),
  ('Derval 3',            'Derval SC 3'),
  ('Guemene FC 1',        'Guémené 1'),
  ('Guemene 2',           'Guémené 2'),
  ('Heric',               'Héric 1'),
  ('Nort-sur-Erdre 2',    'Nort sur Erdre 2'),
  ('Nozay 2',             'Nozay OS 2'),
  ('Plesse Dresny ES 1',  'Dresny Plessé 1'),
  ('LUSTVI 1',            'St Vincent LUSTVI 1'),
  ('Vay-Marsac',          'Vay-Marsac 1'),
  ('Vay-Marsac FC 1',     'Vay-Marsac 1');


do $$
declare
  f            record;
  v_source_id  uuid;
  v_cible_id   uuid;
  v_deplacees  int;
  v_manquantes text;
begin
  -- -------------------------------------------------------------------
  --  Contrôle préalable : toutes les cibles doivent exister.
  --
  --  On les vérifie TOUTES avant d'en toucher une seule. Échouer sur la
  --  première venue obligerait à corriger, relancer, échouer sur la
  --  suivante — douze fois.
  -- -------------------------------------------------------------------
  select string_agg(distinct f2.cible, ', ' order by f2.cible)
    into v_manquantes
  from _fusions f2
  where not exists (select 1 from adversaires a where a.nom = f2.cible);

  if v_manquantes is not null then
    raise exception
      'Cible(s) introuvable(s) en base : %. '
      'Corrige l''orthographe dans la liste ci-dessus — rien n''a été '
      'modifié.', v_manquantes;
  end if;

  -- -------------------------------------------------------------------
  --  Les fusions, dans l'ordre de la liste.
  -- -------------------------------------------------------------------
  for f in select * from _fusions order by ordre loop

    select id into v_source_id from adversaires where nom = f.source;
    select id into v_cible_id  from adversaires where nom = f.cible;

    -- La source n'existe pas. Deux explications, et la base ne peut pas
    -- les départager : ou bien la fusion a déjà eu lieu, ou bien le nom
    -- source est mal orthographié. On ne tranche pas à sa place — mais
    -- on ne bloque pas non plus, sinon le fichier ne serait pas
    -- rejouable.
    if v_source_id is null then
      insert into _journal values (
        f.ordre, f.source, f.cible,
        'source absente — déjà fusionnée, ou mal orthographiée', 0
      );
      continue;
    end if;

    -- Source et cible confondues : rien à faire.
    if v_source_id = v_cible_id then
      insert into _journal values (
        f.ordre, f.source, f.cible, 'identiques — rien à faire', 0
      );
      continue;
    end if;

    -- FUSION. On déplace, puis on supprime. La clé étrangère est en
    -- `on delete restrict` : si une rencontre avait été oubliée, le
    -- delete échouerait et toute la transaction avec. C'est le dernier
    -- garde-fou, on le laisse faire son travail.
    update rencontres
    set adversaire_id = v_cible_id
    where adversaire_id = v_source_id;
    get diagnostics v_deplacees = row_count;

    delete from adversaires where id = v_source_id;

    insert into _journal values (
      f.ordre, f.source, f.cible, 'fusionnée', v_deplacees
    );

  end loop;
end $$;


-- =====================================================================
--  Ce qui s'est passé, ligne par ligne
--
--  Au premier passage, les douze lignes doivent être « fusionnée ».
--  Une ligne « source absente » veut dire que le nom de gauche ne
--  correspond à rien en base — à un accent, un espace ou une majuscule
--  près. Rien n'a été perdu pour autant : c'est simplement que ce
--  doublon-là n'a pas été traité.
-- =====================================================================
select ordre, source, cible, action, rencontres as matchs
from _journal
order by ordre;

commit;


-- =====================================================================
--  Contrôle — les adversaires restants et leur nombre de rencontres
--
--  Parcours-le une fois : c'est le moment où les doublons restants
--  sautent aux yeux.
-- =====================================================================
select a.nom,
       count(r.id) as rencontres
from adversaires a
left join rencontres r on r.adversaire_id = a.id
group by a.nom
order by a.nom;

-- Ménage.
drop table if exists _fusions;
drop table if exists _journal;
