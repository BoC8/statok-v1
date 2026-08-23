# STATOK — Carte d'architecture

> Application Flutter du **Football Club Pierre Bleue (FCPB)** : suivi des matchs,
> résultats et statistiques joueurs, avec un espace coach protégé.
>
> Ce fichier est la carte de référence du projet. Il est destiné autant à toi qu'à un
> assistant IA : le lire suffit pour comprendre l'app sans ouvrir les 10 000 lignes.
> **À mettre à jour quand la structure change** (nouvel écran, nouvelle table, refonte).
>
> Dernière mise à jour : 23 août 2026 · version `pubspec` : 1.0.2
> Schéma de la base : voir **`docs/schema.sql`**
> Signature iOS : voir **`docs/certificat-ios-sans-mac.md`**

---

## 1. Vue d'ensemble

| | |
|---|---|
| **Nom** | statok (affiché « STATOK » / « FCPB ») |
| **Stack** | Flutter · Dart SDK ^3.10.4 · Supabase (Postgres + Auth) |
| **Cibles** | iOS, Android (dossiers `web/`, `windows/`, `linux/`, `macos/` présents mais non exploités) |
| **Volume** | ~10 500 lignes de Dart réparties sur 26 fichiers non vides |
| **Langue** | Interface entièrement en français, locale forcée `fr_FR` |
| **CI** | `.github/workflows/ios_build.yml` |

### Dépendances et rôle de chacune

| Paquet | Rôle réel dans le code |
|---|---|
| `supabase_flutter` ^2.10.0 | Base de données + authentification. **Cœur de l'app.** |
| `shared_preferences` ^2.5.5 | Mémorise `selected_category` et `selected_season` — c'est le « contexte global » de l'app |
| `table_calendar` ^3.1.2 | Vue calendrier de `calendrier_page.dart` |
| `fl_chart` ^0.66.0 | Graphiques du dashboard équipe |
| `intl` ^0.20.2 + `flutter_localizations` | Formatage des dates en français |
| `google_fonts` ^6.2.1 | ⚠️ Déclaré mais **jamais importé** dans `lib/` |
| `flutter_riverpod` ^2.4.9 | ⚠️ `ProviderScope` est posé dans `main.dart` mais **aucun provider n'existe** |
| `go_router` ^14.2.7 | ⚠️ Déclaré mais **non utilisé** — la navigation passe par `Navigator` + `MaterialPageRoute` |

---

## 2. Arborescence de `lib/`

> Structure au 23 août 2026, après le grand nettoyage. Les fichiers marqués
> **[nouveau]** ou **[extrait]** datent de cette journée.

```
lib/
├── main.dart ......................... 47 l.  Init Supabase + intl, lance MyApp
├── supabase_config.dart ..............  2 l.  supabaseUrl + supabaseAnonKey
│
├── theme/
│   └── app_theme.dart ................ 36 l.  Couleurs club + ThemeData
│
├── utils/
│   └── categorie_utils.dart ......... 133 l.  [nouveau] TOUTE la logique catégorie
│                                              (remplace 16 méthodes dupliquées)
│
├── repositories/  ..................... l'accès aux données, plus aucune requête
│   ├── match_repository.dart ........ 107 l.  [nouveau] matchs + programmations
│   └── stats_repository.dart ........  51 l.  [nouveau] joueurs + actions
│
├── services/
│   └── equipe_service.dart .......... 152 l.  Chargement/CRUD des équipes
│
├── models/
│   ├── joueur_model.dart ............. 34 l.  ✅ seul modèle réellement utilisé
│   ├── match_model.dart .............. VIDE   ← prochain chantier
│   └── action_model.dart ............. VIDE   ← prochain chantier
│
├── providers/ ......................... 2 fichiers VIDES ← prochain chantier
├── utils/date_utils.dart .............. VIDE
│
├── widgets/
│   ├── compact_filter_button.dart .... 459 l. Panneau de filtres + AdversaireSearchField
│   ├── menu_card.dart ................  74 l. Carte du menu d'accueil
│   ├── match_card.dart ............... VIDE
│   └── team_selector.dart ............ VIDE
│
└── pages/
    ├── category_selection_page.dart .. 190 l. 🚪 ÉCRAN D'ENTRÉE
    ├── home_page.dart ................ 297 l. Menu principal + sélecteur de saison
    ├── calendrier_page.dart .......... 1200 l.
    ├── resultats_page.dart ...........  907 l.
    ├── stats_page.dart ...............  596 l.
    ├── equipes_selection_page.dart ...  123 l.
    ├── equipe_dashboard_page.dart .... 1362 l.
    ├── login_page.dart ...............  134 l. Accès coach
    ├── club_page.dart / team_page.dart / videos_page.dart .. 12-19 l. → COQUILLES VIDES
    │
    └── admin/
        ├── admin_dashboard.dart ......  227 l. 4 onglets
        ├── matchs_tab.dart ........... 1108 l. Saisie d'un match + liste
        ├── match_detail_dialog.dart ..  869 l. [extrait] Consulter/modifier un match
        ├── tab_session_page.dart .....  312 l. [extrait] Séance de tirs au but
        ├── programmations_tab.dart ... 1007 l.
        ├── joueurs_tab.dart ..........  650 l.
        └── equipes_admin_tab.dart ....  394 l.
```

**Les quatre pages publiques n'importent plus Supabase.** Elles passent par les
`repositories/`. C'est le meilleur test de la séparation : si une page a besoin
d'`import 'package:supabase_flutter/...'`, c'est qu'une requête a fui hors du repository.

---

## 3. Parcours utilisateur

### Côté public (aucune authentification)

```
CategorySelectionPage           « U14-U15 » / « U16-U17-U18 » / « SENIORS »
  │  écrit selected_category dans SharedPreferences
  │  pushReplacement
  ▼
HomePage                        sélecteur de saison + grille de 4 cartes
  ├──► CalendrierPage           calendrier des matchs à venir + joués
  ├──► ResultatsPage            liste des résultats, filtrable
  ├──► StatsPage                classements buteurs / passeurs / total (podium)
  └──► EquipesSelectionPage
          └──► EquipeDashboardPage(equipeName)   stats, graphiques, podiums de l'équipe
```

### Côté coach (authentifié)

```
HomePage → icône ⚙ AppBar
  │  si session Supabase active ──► AdminDashboard
  │  sinon                      ──► LoginPage (email + mot de passe)
  ▼                                    └── succès → AdminDashboard
AdminDashboard   (onglets internes, pas de route)
  ├── MATCHS ............ MatchsTab           saisir un match joué + buteurs/passeurs/TAB
  ├── PROGRAMMATIONS .... ProgrammationsTab   planifier un match à venir
  ├── JOUEURS(EUSES) .... JoueursTab          CRUD joueurs, activation/désactivation
  └── PARAMÈTRES ........ EquipesAdminTab     CRUD équipes + montée de catégorie
```

**Navigation** : `Navigator.push` / `pushReplacement` avec `MaterialPageRoute`, écrits
en dur dans chaque page. Aucune table de routes centralisée.

---

## 4. Le contexte global : catégorie + saison

C'est le concept le plus important de l'app, et il n'est écrit nulle part dans le code
sous forme de modèle. Deux valeurs, stockées dans `SharedPreferences`, filtrent
**tout** ce que l'app affiche :

| Clé | Écrite par | Lue par |
|---|---|---|
| `selected_category` | `CategorySelectionPage` | toutes les pages de données |
| `selected_season` | `HomePage`, `AdminDashboard` | toutes les pages de données |

**Saisons** : générées par calcul, pas stockées. Première saison = `2025-2026`,
bascule le **28 mai** (`_buildAvailableSeasons()`, dupliqué dans `home_page.dart` et
`admin_dashboard.dart`).

**Mapping catégorie** — l'app affiche un libellé, la base en stocke un autre :

| Affiché | Stocké en base |
|---|---|
| `U14 - U15` | `U14-15` |
| `U16 - U17 - U18` | `U16-17-18` |
| `SENIORS` | `Seniors` |

Ce mapping vit désormais dans **`lib/utils/categorie_utils.dart`**, en un seul
exemplaire. Il était auparavant recopié dans 9 fichiers, avec des divergences
silencieuses. `EquipeService.categoriePourDb()` subsiste comme simple délégation, pour
ne pas casser ses appelants.

**Toute nouvelle catégorie se déclare dans ce fichier, et nulle part ailleurs.**

---

## 5. Schéma Supabase

> Source de vérité : **`docs/schema.sql`** (export du dashboard, 22 août 2026).
> À regénérer après chaque migration : `supabase db dump --schema-only > docs/schema.sql`.

### 5.1 Les 7 tables

Toutes les clés primaires sont des `uuid` auto-générés, toutes les tables ont un
`created_at timestamptz NOT NULL`.

```
adversaires                       equipes
├── nom  text NOT NULL UNIQUE     ├── nom       text NOT NULL
└── logo_url  text  ⚠ inutilisé   ├── categorie text NOT NULL
                                  ├── genre     varchar DEFAULT 'M'
joueurs                           └── actif     bool NOT NULL DEFAULT true
├── nom              text NOT NULL
├── categorie        text NOT NULL       ← 'U14-15' | 'U16-17-18' | 'Seniors'
├── categorie_detail varchar             ← '14'|'15'|'16'|'17'|'18'|'Senior'
├── genre            varchar DEFAULT 'M' ← 'M' | 'F'
└── actif            bool NOT NULL DEFAULT true

matchs                                  programmations
├── date          date NOT NULL         ├── date          date NOT NULL
├── equipe        text NOT NULL  ⚠ FK✗  ├── heure         time NOT NULL
├── adversaire_id uuid → adversaires    ├── equipe        text NOT NULL  ⚠ FK✗
├── lieu          text NOT NULL         ├── adversaire_id uuid → adversaires
├── competition   text NOT NULL         ├── lieu          text NOT NULL
├── categorie     text NOT NULL         ├── competition   text NOT NULL
├── saison        text NOT NULL         ├── categorie     text NOT NULL
├── buts_gjpb     int  NOT NULL         └── saison        text NOT NULL
├── buts_adv      int  NOT NULL
├── tab_fcpb      int  (nullable)       actions
├── tab_adv       int  (nullable)       ├── match_id  uuid NOT NULL → matchs
└── verrouille    bool NOT NULL ⚠ inut. ├── joueur_id uuid NOT NULL → joueurs
                                        └── type      text NOT NULL

classements   ⚠ TABLE ENTIÈREMENT INUTILISÉE PAR L'APP
├── equipe / competition / position(text) / categorie / saison
```

### 5.2 Conventions de valeurs

Elles ne sont **pas** contraintes en base (pas de `CHECK`, pas d'`enum`) : ce sont des
conventions respectées par le code Dart uniquement.

| Colonne | Valeurs |
|---|---|
| `actions.type` | `Goal` · `Assist` · `TAB_Reussi` · `TAB_Rate` |
| `lieu` | `DOM` · `EXT` |
| `categorie` | `U14-15` · `U16-17-18` · `Seniors` |
| `genre` | `M` · `F` |
| `saison` | `2025-2026`, `2026-2027`, … |
| `joueurs.categorie_detail` | `14` `15` `16` `17` `18` `Senior` |

### 5.3 Règles métier portées par le code (pas par la base)

- **Une action = une occurrence.** Un doublé donne 2 lignes dans `actions`
  (`List.generate(quantite, …)` dans `matchs_tab.dart`) — la colonne `quantite`
  n'existe pas en base, elle n'est qu'un compteur temporaire dans le formulaire.
- **Éligibilité d'un joueur** (`_joueursEligiblesPourEquipe`) : le genre du joueur doit
  correspondre à `equipes.genre`, et son `categorie_detail` doit appartenir à la
  catégorie active. Si `equipes.genre` est absent, le code devine à partir du nom de
  l'équipe (présence d'un « F ») — heuristique fragile.
- **Adversaires créés à la volée** par `_ensureAdversaire()` : recherche par nom, insert
  si absent. L'unicité de `adversaires.nom` protège des doublons, mais pas de la casse
  ni des fautes de frappe (« Beaulieu » vs « Beaulieux » = 2 adversaires).
- **Désactivation vs suppression** : joueurs et équipes passent à `actif = false`.
  Matchs et programmations sont supprimés définitivement.
- **Enregistrer un match joué supprime la programmation correspondante** (même équipe,
  même adversaire, même jour) — fin de `_enregistrerMatch()`.
- **`tab_fcpb` / `tab_adv`** ne sont renseignés que si la compétition contient
  « coupe » (`_isCoupe`), et remis à `null` à l'édition sinon.

### 5.4 Écarts entre la base et le code

| Constat | Conséquence |
|---|---|
| ~~Pas de `ON DELETE CASCADE` sur `actions.match_id`~~ | ✅ Corrigé le 23/08/2026 — `docs/migration_cascade_actions.sql`. Voir §8. |
| `matchs.equipe` / `programmations.equipe` sont du **texte libre** sans FK vers `equipes.nom` | Renommer une équipe casse le lien avec son historique ; une faute de frappe crée une équipe fantôme |
| Aucun **index** en dehors des clés primaires | `actions.match_id`, `actions.joueur_id`, `matchs.saison`, `matchs.categorie` → scans complets, invisibles aujourd'hui, coûteux à terme |
| Aucune **unicité** sur `equipes(nom, categorie)` ni `joueurs(nom, categorie_detail)` | Doublons possibles ; le code s'en protège côté Dart uniquement (`ilike` + `maybeSingle`) |
| `matchs.verrouille` et `adversaires.logo_url` | Colonnes jamais lues ni écrites — fonctionnalités prévues puis abandonnées ? |
| Table **`classements`** | Jamais interrogée par l'app. Soit à implémenter (affichage du classement de chaque équipe), soit à supprimer. |
| `matchs.date` est de type `date`, le code envoie `toIso8601String()` (un timestamp complet) | Postgres tronque silencieusement — ça marche, mais c'est fortuit |
| **RLS** | Non visible dans l'export. À vérifier table par table dans le dashboard (voir §8). |

---

## 6. Comment les données sont chargées

Depuis le 23 août 2026, **le filtrage se fait côté serveur** (voir §8). Le schéma est le
même dans toutes les pages de données :

```dart
// 1. lire le contexte
final prefs = await SharedPreferences.getInstance();
final categorie = prefs.getString('selected_category');
final saison    = prefs.getString('selected_season');

// 2. ne télécharger que ce qui sera affiché
final dbCategorie = _categoriePourDb(categorie);   // 'U16 - U17 - U18' -> 'U16-17-18'

var query = _client.from('matchs')
    .select('*, adversaires(nom), actions(type, joueurs(nom))');
if (dbCategorie != null) query = query.eq('categorie', dbCategorie);
if (saison != null)      query = query.eq('saison', saison);

final res = await query.order('date', ascending: false);

// 3. plus de filtrage catégorie/saison en Dart — il n'a plus lieu d'être
```

Les filtres d'interface (équipe, compétition, lieu) restent en Dart : ils changent à
chaque clic, les refaire côté serveur provoquerait un aller-retour réseau par clic.

**Cas particulier de `stats_page`** : on ne filtre pas `actions` directement mais *à
travers sa jointure*. Le `!inner` rend la jointure obligatoire, ce qui autorise PostgREST
à filtrer sur les colonnes de la table liée :

```dart
.select('type, joueur_id, matchs!inner(equipe, competition, lieu, categorie, saison)')
.eq('matchs.categorie', dbCategorie)
.eq('matchs.saison', saison)
```

**Ce qui reste à améliorer** : aucun cache, aucun state partagé. Chaque page recharge
depuis zéro dans son `initState()`. Naviguer Accueil → Résultats → retour → Résultats
déclenche deux chargements complets. C'est ce que résoudraient les `providers/` Riverpod
restés vides (§8).

### ⚠️ Le temps réel des onglets admin — piège connu

`matchs_tab` et `programmations_tab` affichent leur liste via un `StreamBuilder` branché
sur un flux temps réel Supabase, et non un `FutureBuilder`.

**Depuis l'activation de la RLS, ce flux ne transmet plus les événements UPDATE.** La
lecture initiale fonctionne, les ajouts et suppressions passent, mais une modification
n'arrive jamais au client. C'est un bug Supabase ouvert depuis avril 2025
([discussion #35196](https://github.com/orgs/supabase/discussions/35196)), toujours sans
correctif, y compris avec une policy `SELECT using (true)`.

**Symptôme vécu le 23/08/2026** : modifier l'adversaire, le score, le lieu ou la
compétition d'un match semblait sans effet, alors que les buteurs et passeurs, eux, se
mettaient bien à jour. L'explication tenait à la source de chaque donnée : les champs du
match venaient du flux (périmé), les actions d'une requête fraîche relancée à chaque
ouverture du dialogue.

**Parade retenue** : ne plus dépendre du temps réel pour la justesse de l'affichage.
`_ouvrirDetailsMatch` et `_ouvrirDetails` sont désormais `async`, attendent la fermeture
du dialogue, puis incrémentent `_refreshTick` — ce qui recrée le `StreamBuilder` et
force une lecture neuve.

> **À retenir pour la suite** : sur cette base, le temps réel est un confort, jamais une
> garantie. Tout écran qui doit afficher une donnée à jour après modification doit
> recharger explicitement.

`docs/realtime_replica_identity.sql` tente de restaurer le comportement natif
(`replica identity full`), sans garantie — le bug amont est côté Supabase.

Le filtrage de ces flux est encore fait en Dart — à revoir si ces tables grossissent.

---

## 7. Duplications connues

Le même bloc de code existe à l'identique dans plusieurs fichiers. Le savoir évite de
corriger un bug à un seul endroit :

### ✅ Traité le 23 août 2026

Toute la famille « catégorie » — `_categoriePourDb`, `_categorieMatches`,
`_detailsPourCategorie`, `_categoriePourDetail`, `_detailSuivant`, `_normaliserGenre` —
soit **16 méthodes réparties dans 9 fichiers**, vit désormais dans
`lib/utils/categorie_utils.dart`.

Les copies **n'étaient pas identiques**. Trois divergences relevées avant fusion :

| Méthode | Divergence | Traitement |
|---|---|---|
| `categoriePourDb` | 6 fichiers géraient `'Seniors'`, 2 non | Version unifiée, idempotente |
| `detailsPourCategorie` | repli **opposé** : tous les détails vs ensemble vide | **Deux noms distincts**, la différence est désormais nommée |
| `categoriePourDetail` | `null` vs `'Seniors'` pour un détail inconnu | Version nullable ; le `?? 'Seniors'` reste explicite chez son appelant |

C'est la raison d'être de ce chantier : ces écarts n'étaient pas des bugs *encore*.

### Restant à traiter

| Fonction / classe | Copies dans |
|---|---|
| `_nomAdversaire()` | matchs_tab ×2, programmations_tab ×2, calendrier, resultats, equipe_dashboard |
| `_lieuCode()` | calendrier, resultats, stats, equipe_dashboard |
| `_getColorForCompet()` | calendrier, resultats, stats, equipe_dashboard |
| `_valeursUniques()` / `_compterOccurrences()` | calendrier, resultats, equipe_dashboard |
| `_buildResultBadge()` / `_buildTabTireursSection()` | calendrier, resultats |
| `_buildSeasonSelector()` / `_buildAvailableSeasons()` | home_page, admin_dashboard |
| **classe `TabTireur`** | déclarée **deux fois**, dans `calendrier_page.dart` **et** `resultats_page.dart` |
| `_ensureAdversaire()` | matchs_tab, match_detail_dialog, programmations_tab ×2 |

Le patron est toujours le même : ce sont des fonctions de **présentation** (formater un
nom, choisir une couleur, dédoublonner une liste). Elles mériteraient un
`lib/utils/affichage_utils.dart` sur le modèle de `categorie_utils.dart`.

---

## 8. Chantiers identifiés

Classés par rapport bénéfice/risque, du plus rentable au plus lourd.

### ✅ RÉSOLU — Incident certificat Apple exposé (22-23 août 2026)

`certificates-mac/Certificates.p12` — le **certificat de signature Apple, clé privée
incluse** — a été commité (commit `93160ba`, « Première configuration du build iOS ») et
poussé sur **`github.com/BoC8/statok-v1`, dépôt public**.

Le fichier est protégé par mot de passe, mais un `.p12` public se casse hors ligne.
Le CI n'en a **pas** besoin : `.github/workflows/ios_build.yml` passe par les GitHub
Secrets (`P12_BASE64`, `MOBILEPROVISION_BASE64`, `P12_PASSWORD`). Le fichier était donc
du poids mort exposé pour rien.

Traitement effectué le 23 août 2026 :

1. ✅ Nouveau certificat de distribution généré **depuis Windows, sans Mac** — clé RSA
   2048 + CSR via OpenSSL, `.p12` reconstitué en local
   (procédure complète : `docs/certificat-ios-sans-mac.md`)
2. ✅ Nouveau provisioning profile `Statok_Distribution_Profile`
3. ✅ Secrets GitHub mis à jour (`P12_BASE64`, `MOBILEPROVISION_BASE64`, `P12_PASSWORD`)
4. ✅ Build CI vérifié vert de bout en bout (build + upload TestFlight)
5. ✅ Ancien certificat (expiration 2027/02/10) **révoqué** sur developer.apple.com
6. ✅ `certificates-mac/` retiré du suivi Git et supprimé du disque ;
   `.gitignore` bloque désormais `*.p12`, `*.cer`, `*.mobileprovision`

Réécrire l'historique Git n'est pas nécessaire : le certificat étant révoqué, la copie
qui traîne dans les vieux commits ne vaut plus rien.

**Clé privée** : `statok-distribution.key` + `Certificate.p12` + mot de passe sont dans
`C:\Users\cleme\certificats-statok`, **hors du dépôt**. Sans la clé privée, le
certificat Apple est inutilisable — à sauvegarder ailleurs qu'à un seul endroit.

**Conséquence annexe** : le dépôt étant public, `lib/supabase_config.dart` et sa clé
`anon` le sont aussi. C'est le fonctionnement prévu par Supabase — **à condition que la
RLS soit active**. Elle n'est plus « recommandée », elle est indispensable. (Vérifié :
aucune clé `service_role` dans l'historique des 39 commits.)

### ✅ RÉSOLU — état du dépôt Git (23 août 2026)

Constat initial : 110 fichiers non commités, dont ~90 de pur bruit de fins de ligne
(CRLF ↔ LF), 15 fichiers avec ~6 000 lignes de vraies modifications jamais sauvegardées,
et surtout `lib/services/`, `equipes_admin_tab.dart`, `category_selection_page.dart`,
`compact_filter_button.dart` et les logos **pas suivis du tout**.

Correctifs :
- `.gitattributes` (`* text=auto eol=lf`) → plus de faux « fichiers modifiés »
- Tout le travail commité et poussé, en deux commits séparés (le vrai travail d'un côté,
  la normalisation technique de l'autre)
- `main` relié à `origin/main` (`git push -u`), 188 fichiers suivis

### ✅ RÉSOLU — coût et déclenchement du CI (23 août 2026)

`.github/workflows/ios_build.yml`, trois changements :

| Avant | Après | Pourquoi |
|---|---|---|
| `runs-on: macos-latest-large` | `runs-on: macos-latest` | Les *larger runners* sont facturés **même sur un dépôt public** ; les runners standard y sont gratuits et illimités |
| `on: push: branches: [main]` | `on: workflow_dispatch` + `push: tags: ["v*"]` | Un build à chaque commit déclenchait un upload TestFlight — et donc une erreur de version à répétition |
| build number manuel dans `pubspec.yaml` | `github.run_number + 100` | Plus jamais l'erreur « bundle version already used » |

**Règle de versionnage à retenir** : `version: 1.0.x+N` dans `pubspec.yaml`.
- `1.0.x` = version publique. Une fois **approuvée** par Apple, son « train » est fermé :
  il faut incrémenter pour livrer à nouveau. C'est la seule partie restée manuelle.
- `+N` = numéro de build, désormais généré par le CI. Ne plus y toucher.

Pour livrer : bouton **Run workflow** dans l'onglet Actions, ou
`git tag v1.0.3 && git push origin v1.0.3`.

### ✅ RÉSOLU — Bug de suppression d'un match (23 août 2026)

**Symptôme** : supprimer un match ayant au moins un but ou une passe ne faisait rien.
La boîte de dialogue se fermait normalement, le match restait en base.

**Cause** : `actions.match_id` référence `matchs.id` sans `ON DELETE CASCADE`, et
`_supprimerMatch()` supprimait le match sans nettoyer ses actions. Postgres refusait —
mais sans `try/catch`, l'exception passait inaperçue.

**Correctif, sur les deux plans** (volontairement redondant : si la migration n'est pas
jouée sur un environnement, le code tient quand même) :

1. **Base** — `docs/migration_cascade_actions.sql` : `ON DELETE CASCADE` sur
   `actions_match_id_fkey`.
2. **Dart** — `matchs_tab.dart`, `MatchDetailDialog._supprimerMatch()` :
   - suppression explicite des actions avant le match ;
   - `try/catch` avec `SnackBar` d'erreur — **ne plus jamais échouer en silence** ;
   - **boîte de confirmation ajoutée** : le bouton « Supprimer » est collé à « Fermer »
     dans la même barre, et un seul tap effaçait un match définitivement. Sur un
     téléphone en bord de terrain, c'est un accident qui attend d'arriver.
   - `messenger` et `navigator` capturés avant les `await` (règle
     `use_build_context_synchronously`).

La liste se met à jour seule après suppression : elle est branchée sur un
`StreamBuilder` (flux temps réel Supabase), pas sur un `FutureBuilder`.

**Reste à faire, même famille** : `programmations_tab.dart`,
`ProgrammationDetailDialog._supprimer()` a le même bouton sans confirmation ni
`try/catch`. Pas de bug de fond (une programmation n'a pas d'actions liées), mais même
risque de suppression accidentelle.

### ✅ RÉSOLU — Row Level Security Supabase (23 août 2026)

**Constat initial** : les 7 tables étaient en `RLS DISABLED`, sans aucune policy.
Supabase l'affichait en clair : *« This table can be accessed by anyone via the Data
API. »* Le dépôt étant public, la clé `anon` l'est aussi — et une clé `anon` ne protège
rien par elle-même, c'est la RLS qui protège. N'importe qui pouvait donc, en une requête
HTTP, non seulement lire mais **modifier et supprimer** toutes les données.

**Correctif appliqué** — script `docs/rls_policies.sql`, rejouable :

| Rôle | Droits |
|---|---|
| `anon` (app publique, non connecté) | `SELECT` uniquement |
| `authenticated` (coach connecté) | `SELECT` + `INSERT` + `UPDATE` + `DELETE` |

Deux policies par table (`lecture_publique`, `ecriture_authentifiee`), sur les 7 tables.
Vérifié : `rls_active = true`, `nb_policies = 2` partout, et l'app testée de bout en
bout — lecture publique et écritures admin fonctionnelles.

**Pourquoi c'était sans risque** : audit du code au préalable — aucune écriture ne part
du côté public. Tous les `insert`/`update`/`delete` sont dans `pages/admin/*`, derrière
l'authentification. `equipe_service` n'écrit que si appelé avec `persistHistorique: true`,
ce qui n'arrive que depuis `EquipesAdminTab`.

Vérifié aussi : aucune clé `service_role` n'a jamais été commitée dans les 39 commits.

> ⚠️ **À refaire pour toute nouvelle table.** Une table créée dans Supabase arrive avec
> la RLS désactivée par défaut. Rejouer `docs/rls_policies.sql` après l'avoir ajoutée à
> la liste du script.
- 4 `print()` restants en production (`catch (e) { print(...) }`) — à remplacer par un
  vrai log ou un message utilisateur.
- Plusieurs `catch (_) {}` silencieux dans `equipe_service.dart` masquent les erreurs.

### 🟡 Performance et structure

1. ~~**Filtrer côté serveur.**~~ ✅ **Fait le 23 août 2026.** Les 5 fichiers de
   chargement filtrent sur `categorie` + `saison` côté Postgres. Prérequis : la base a
   d'abord été normalisée (`docs/normalisation_categories.sql`) — 72 matchs étaient
   stockés sous la forme d'affichage `U16 - U17 - U18`, filtrer sans les convertir les
   aurait fait disparaître de l'app. Voir §6 pour le détail des requêtes.
2. ~~**Remplir les `repositories/`.**~~ ✅ **Fait le 23 août 2026.** `MatchRepository`
   et `StatsRepository` portent les requêtes des pages publiques ; ces quatre pages
   n'importent plus Supabase du tout. Les onglets admin gardent leurs requêtes en
   propre — ils écrivent autant qu'ils lisent, c'est un chantier distinct.
3. **Remplir les `providers/`. ← LE CHANTIER SUIVANT.** Riverpod est déjà installé et
   `ProviderScope` posé :
   un `FutureProvider` par jeu de données supprime les rechargements en boucle et
   partage le contexte catégorie/saison au lieu de relire `SharedPreferences` partout.
4. ~~**Créer `lib/utils/`**~~ ✅ **Fait le 23 août 2026** — `categorie_utils.dart`,
   16 méthodes dédupliquées. Reste la famille « présentation » (voir §7).
5. ~~**Découper `matchs_tab.dart`**~~ ✅ **Fait le 23 août 2026** : 2 228 lignes devenues
   1 108 (`matchs_tab`) + 869 (`match_detail_dialog`) + 312 (`tab_session_page`).
   `_TabSessionResult` et `_TabSessionPage` sont devenus publics — ils franchissaient
   désormais une frontière de fichier. Tout le reste demeure privé.
6. **Modèles manquants** : `MatchModel`, `ActionModel` restent vides, tout circule en
   `Map<String, dynamic>` — aucune vérification du compilateur sur les noms de colonnes.

### 🟢 Nettoyage

- Retirer `go_router` et `google_fonts` du `pubspec` (ou les utiliser).
- `club_page.dart`, `team_page.dart`, `videos_page.dart` : coquilles vides,
  jamais atteintes depuis la navigation → supprimer ou implémenter.
- `test/widget_test.dart` est le test généré par défaut, il ne teste rien de l'app.
- `.metadata`/`README.md` sont restés au contenu par défaut de `flutter create`.

---

## 9. Méthode de travail avec un assistant IA

1. **Faire lire ce fichier en premier.** Il donne le contexte en 5 secondes.
2. **Ne jamais demander de « lire tout le projet ».** Décrire la fonctionnalité :
   « le filtre par compétition dans Résultats » → les bons fichiers sont dans le §2.
3. **`docs/schema.sql` est la source de vérité de la base.** Le regénérer après chaque
   migration (`supabase db dump --schema-only > docs/schema.sql`).
4. **Commiter avant toute modification assistée**, pour pouvoir revenir en arrière.
5. **Mettre ce fichier à jour** après chaque changement structurel.

### Scripts SQL du projet (`docs/`)

| Fichier | Rôle | Rejouable |
|---|---|---|
| `schema.sql` | Schéma de référence de la base | — (documentation) |
| `rls_policies.sql` | Active la RLS + policies sur toutes les tables | ✅ |
| `migration_cascade_actions.sql` | `ON DELETE CASCADE` sur `actions.match_id` | ✅ |
| `normalisation_categories.sql` | Unifie l'écriture des catégories | ✅ |
| `index.sql` | Index accompagnant le filtrage serveur | ✅ |
| `realtime_replica_identity.sql` | Tentative de restaurer le temps réel sous RLS | ✅ |
| `certificat-ios-sans-mac.md` | Procédure de signature iOS depuis Windows | — |

### Où aller selon le sujet

| Sujet | Fichier(s) |
|---|---|
| Écran d'accueil, menu, saison | `pages/home_page.dart` |
| Choix de la catégorie | `pages/category_selection_page.dart` |
| Calendrier, matchs à venir | `pages/calendrier_page.dart` |
| Résultats, scores | `pages/resultats_page.dart` |
| Classement buteurs/passeurs | `pages/stats_page.dart` |
| Fiche d'une équipe, graphiques | `pages/equipe_dashboard_page.dart` |
| Saisie d'un match, buteurs, TAB | `pages/admin/matchs_tab.dart` |
| Planification d'un match | `pages/admin/programmations_tab.dart` |
| Gestion des joueurs | `pages/admin/joueurs_tab.dart` |
| Gestion des équipes, montée de catégorie | `pages/admin/equipes_admin_tab.dart` + `services/equipe_service.dart` |
| Filtres (équipe / compétition / lieu) | `widgets/compact_filter_button.dart` |
| Couleurs, thème | `theme/app_theme.dart` |
| Connexion coach | `pages/login_page.dart` |
