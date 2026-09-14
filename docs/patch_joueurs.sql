-- =====================================================================
--  STATOK — correctif : un joueur n'appartient à aucune équipe
--
--  À exécuter sur la base v2 DÉJÀ créée, avant migration_v2.sql.
--  Si tu repars d'une base neuve, ce fichier est inutile : les nouvelles
--  versions de schema_v2.sql et seed_v2.sql l'intègrent déjà.
--
--  POURQUOI
--    Un licencié de génération 17 peut jouer en U18 A un week-end et en
--    U17 le suivant. La colonne joueurs.equipe_id était donc fausse dans
--    son principe : elle prétendait figer une appartenance qui n'existe
--    pas. Les équipes avec lesquelles un joueur a réellement joué se
--    lisent sur ses buts, via la rencontre.
--
--  CE QUE ÇA ENTRAÎNE
--    Sans équipe, plus rien ne disait à quelle catégorie rattacher une
--    fiche de joueur — or c'est le niveau auquel les droits des coachs
--    sont attribués. Il faut donc deux choses :
--      · categories.generations, pour retrouver la catégorie depuis la
--        génération du joueur ;
--      · joueurs.genre, pour départager masculins et féminines d'une
--        même catégorie.
--
--  Rejouable sans risque.
-- =====================================================================

begin;

-- ---------------------------------------------------------------------
--  1. Les catégories disent quelles générations elles accueillent
-- ---------------------------------------------------------------------
alter table categories
  add column if not exists generations text[] not null default '{}';

update categories set generations = '{13,14,15}' where libelle = 'U14 – U15';
update categories set generations = '{16,17,18}' where libelle = 'U16 – U18';
update categories set generations = '{senior}'   where libelle = 'Seniors';


-- ---------------------------------------------------------------------
--  2. Retirer la politique d'écriture AVANT de toucher aux colonnes
--
--  Elle s'appuie sur equipe_id : tant qu'elle existe, Postgres refuse de
--  supprimer la colonne. On la recrée en fin de fichier.
-- ---------------------------------------------------------------------
drop policy if exists ecriture on joueurs;


-- ---------------------------------------------------------------------
--  3. joueurs : le genre remplace l'équipe
--
--  Si la table contient déjà des lignes, elles passent toutes en 'M' —
--  c'était le cas de tous tes licenciés dans l'ancienne base. Corrige
--  ensuite les féminines depuis l'espace coachs, ou par un update.
-- ---------------------------------------------------------------------
alter table joueurs add column if not exists genre char(1);
update joueurs set genre = 'M' where genre is null;
alter table joueurs alter column genre set not null;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'joueurs_genre_check') then
    alter table joueurs add constraint joueurs_genre_check check (genre in ('M', 'F'));
  end if;
end $$;

drop index if exists joueurs_equipe;
alter table joueurs drop column if exists equipe_id;
create index if not exists joueurs_generation on joueurs (generation, genre) where actif;


-- ---------------------------------------------------------------------
--  4. Les fonctions d'habilitation
-- ---------------------------------------------------------------------
create or replace function public.categorie_de_generation(p_generation text)
returns uuid
language sql stable
as $$
  select id from categories where p_generation = any (generations) limit 1;
$$;

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


-- ---------------------------------------------------------------------
--  5. La politique d'écriture sur les joueurs, version sans équipe
-- ---------------------------------------------------------------------
create policy ecriture on joueurs for all to authenticated
  using      (peut_ecrire_joueur(generation, genre))
  with check (peut_ecrire_joueur(generation, genre));

commit;


-- =====================================================================
--  Contrôle
-- =====================================================================

-- Chaque catégorie accueille bien ses générations, sans chevauchement.
select libelle, ordre, generations from categories order by ordre;

-- La table joueurs n'a plus d'équipe et a bien un genre.
select column_name, data_type, is_nullable
from information_schema.columns
where table_schema = 'public' and table_name = 'joueurs'
order by ordinal_position;
