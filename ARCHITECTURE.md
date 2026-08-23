# STATOK — Carte d'architecture

> Application Flutter du **Football Club Pierre Bleue (FCPB)** : suivi des matchs,
> résultats et statistiques joueurs, avec un espace coach protégé.
>
> Ce fichier est la carte de référence du projet. Il est destiné autant à toi qu'à un
> assistant IA : le lire suffit pour comprendre l'app sans ouvrir les 10 000 lignes.
> **À mettre à jour quand la structure change** (nouvel écran, nouvelle table, refonte).
>
> Dernière mise à jour : 22 août 2026 · version `pubspec` : 1.0.1+10
> Schéma de la base : voir **`docs/schema.sql`**

---

## 1. Vue d'ensemble

| | |
|---|---|
| **Nom** | statok (affiché « STATOK » / « FCPB ») |
| **Stack** | Flutter · Dart SDK ^3.10.4 · Supabase (Postgres + Auth) |
| **Cibles** | iOS, Android (dossiers `web/`, `windows/`, `linux/`, `macos/` présents mais non exploités) |
| **Volume** | ~10 360 lignes de Dart réparties sur 24 fichiers non vides |
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

```
lib/
├── main.dart ......................... 47 l.  Init Supabase + intl, lance MyApp
├── supabase_config.dart ..............  2 l.  supabaseUrl + supabaseAnonKey
│
├── theme/
│   └── app_theme.dart ................ 36 l.  Couleurs club + ThemeData
│
├── models/
│   ├── joueur_model.dart ............. 34 l.  ✅ seul modèle réellement utilisé
│   ├── match_model.dart .............. VIDE
│   └── action_model.dart ............. VIDE
│
├── services/
│   └── equipe_service.dart ........... 154 l. Chargement/CRUD des équipes + mapping catégorie
│
├── repositories/  ..................... 2 fichiers VIDES
├── providers/ ......................... 2 fichiers VIDES
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
    ├── calendrier_page.dart .......... 1231 l.
    ├── resultats_page.dart ...........  936 l.
    ├── stats_page.dart ...............  622 l.
    ├── equipes_selection_page.dart ...  123 l.
    ├── equipe_dashboard_page.dart .... 1390 l.
    ├── login_page.dart ...............  134 l. Accès coach
    ├── club_page.dart / team_page.dart / videos_page.dart .. 12-19 l. → COQUILLES VIDES
    │
    └── admin/
        ├── admin_dashboard.dart ......  227 l. 4 onglets
        ├── matchs_tab.dart ........... 2227 l. ⚠️ le plus gros fichier
        ├── programmations_tab.dart ... 1017 l.
        ├── joueurs_tab.dart ..........  691 l.
        └── equipes_admin_tab.dart ....  425 l.
```

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

Ce mapping vit dans `EquipeService.categoriePourDb()` — **mais il est recopié à
l'identique dans 8 autres fichiers** sous le nom `_categoriePourDb()`.

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
| **Pas de `ON DELETE CASCADE` sur `actions.match_id`** et `_supprimerMatch()` ne supprime pas les actions avant le match | 🐞 **Bug actif** : supprimer un match qui a des buteurs échoue (violation de clé étrangère), sans `try/catch` ni message — la boîte de dialogue se ferme comme si tout allait bien. Voir §8. |
| `matchs.equipe` / `programmations.equipe` sont du **texte libre** sans FK vers `equipes.nom` | Renommer une équipe casse le lien avec son historique ; une faute de frappe crée une équipe fantôme |
| Aucun **index** en dehors des clés primaires | `actions.match_id`, `actions.joueur_id`, `matchs.saison`, `matchs.categorie` → scans complets, invisibles aujourd'hui, coûteux à terme |
| Aucune **unicité** sur `equipes(nom, categorie)` ni `joueurs(nom, categorie_detail)` | Doublons possibles ; le code s'en protège côté Dart uniquement (`ilike` + `maybeSingle`) |
| `matchs.verrouille` et `adversaires.logo_url` | Colonnes jamais lues ni écrites — fonctionnalités prévues puis abandonnées ? |
| Table **`classements`** | Jamais interrogée par l'app. Soit à implémenter (affichage du classement de chaque équipe), soit à supprimer. |
| `matchs.date` est de type `date`, le code envoie `toIso8601String()` (un timestamp complet) | Postgres tronque silencieusement — ça marche, mais c'est fortuit |
| **RLS** | Non visible dans l'export. À vérifier table par table dans le dashboard (voir §8). |

---

## 6. Comment les données sont chargées (point critique)

Le schéma est le même dans **toutes** les pages de données :

```dart
// 1. lire le contexte
final prefs = await SharedPreferences.getInstance();
final categorie = prefs.getString('selected_category');
final saison    = prefs.getString('selected_season');

// 2. TOUT télécharger, sans filtre serveur
final res = await _client.from('matchs')
    .select('*, adversaires(nom), actions(type, joueurs(nom))');

// 3. filtrer en Dart, ligne par ligne
for (var m in res) {
  if (!_categorieMatches(categorie, m['categorie'])) continue;
  if (saison != null && m['saison'] != saison) continue;
  ...
}
```

**Conséquence** : ouvrir le calendrier télécharge tous les matchs de toutes les
catégories et de toutes les saisons, puis en jette 90 %. Ça tient aujourd'hui parce que
la base est petite ; ça se dégradera saison après saison. C'est aussi le premier
chantier d'optimisation (voir §8).

Aucun cache, aucun state partagé : chaque page recharge depuis zéro dans son
`initState()`. Naviguer Accueil → Résultats → retour → Résultats = 2 chargements complets.

---

## 7. Duplications connues

Le même bloc de code existe à l'identique dans plusieurs fichiers. Le savoir évite de
corriger un bug à un seul endroit :

| Fonction / classe | Copies dans |
|---|---|
| `_categoriePourDb()` | equipe_service, matchs_tab, programmations_tab, joueurs_tab, equipes_admin_tab, calendrier, resultats, stats, equipe_dashboard — **9 copies** |
| `_categorieMatches()` | equipe_service, matchs_tab, programmations_tab, calendrier, resultats, stats, equipe_dashboard |
| `_nomAdversaire()` | matchs_tab ×2, programmations_tab ×2, calendrier, resultats, equipe_dashboard |
| `_lieuCode()` | calendrier, resultats, stats, equipe_dashboard |
| `_getColorForCompet()` | calendrier, resultats, stats, equipe_dashboard |
| `_valeursUniques()` / `_compterOccurrences()` | calendrier, resultats, equipe_dashboard |
| `_buildResultBadge()` / `_buildTabTireursSection()` | calendrier, resultats |
| `_buildSeasonSelector()` / `_buildAvailableSeasons()` | home_page, admin_dashboard |
| **classe `TabTireur`** | déclarée **deux fois**, dans `calendrier_page.dart` **et** `resultats_page.dart` |
| `_ensureAdversaire()` | matchs_tab ×2, programmations_tab ×2 |

---

## 8. Chantiers identifiés

Classés par rapport bénéfice/risque, du plus rentable au plus lourd.

### 🔴 Incident — certificat Apple exposé (22 août 2026)

`certificates-mac/Certificates.p12` — le **certificat de signature Apple, clé privée
incluse** — a été commité (commit `93160ba`, « Première configuration du build iOS ») et
poussé sur **`github.com/BoC8/statok-v1`, dépôt public**.

Le fichier est protégé par mot de passe, mais un `.p12` public se casse hors ligne.
Le CI n'en a **pas** besoin : `.github/workflows/ios_build.yml` passe par les GitHub
Secrets (`P12_BASE64`, `MOBILEPROVISION_BASE64`, `P12_PASSWORD`). Le fichier était donc
du poids mort exposé pour rien.

Traitement :
1. **Révoquer** le certificat sur developer.apple.com → Certificates, Identifiers &
   Profiles. C'est la seule action qui le neutralise vraiment.
2. En regénérer un + un nouveau provisioning profile, mettre à jour les GitHub Secrets.
3. `git rm --cached -r certificates-mac` + entrées `.gitignore` (fait).

Une fois le certificat révoqué, réécrire l'historique Git n'est plus nécessaire : la
copie qui traîne dans l'historique ne vaut plus rien.

**Conséquence annexe** : le dépôt étant public, `lib/supabase_config.dart` et sa clé
`anon` le sont aussi. C'est le fonctionnement prévu par Supabase — **à condition que la
RLS soit active**. Elle n'est plus « recommandée », elle est indispensable. (Vérifié :
aucune clé `service_role` dans l'historique des 39 commits.)

### 🔴 Urgent — état du dépôt Git

- **110 fichiers non commités**, dont ~90 ne sont que du bruit de fins de ligne
  (CRLF ↔ LF). Correctif appliqué : `.gitattributes` avec `* text=auto eol=lf`.
- Mais **15 fichiers portent de vraies modifications** (~6 000 lignes) jamais commitées.
- Pire : `lib/services/`, `lib/pages/admin/equipes_admin_tab.dart`,
  `lib/pages/category_selection_page.dart`, `lib/widgets/compact_filter_button.dart`
  et les logos ne sont **pas suivis du tout** par Git. Le dernier commit `v10` ne
  contient pas une partie de l'app actuelle. **Un disque qui lâche = travail perdu.**

### 🔴 Bug confirmé — suppression d'un match

`MatchDetailDialog._supprimerMatch()` (`matchs_tab.dart` ~l.1602) fait :

```dart
Future<void> _supprimerMatch() async {
  await _client.from('matchs').delete().eq('id', widget.match['id']);
  if (mounted) Navigator.pop(context);
}
```

Or `actions.match_id` référence `matchs.id` **sans `ON DELETE CASCADE`**. Dès qu'un
match a au moins un but ou une passe enregistrés, Postgres refuse la suppression. Il n'y
a ni `try/catch` ni message : la boîte se ferme, le match est toujours là.

Deux correctifs possibles (les faire tous les deux) :

1. **Côté base** — `ALTER TABLE actions DROP CONSTRAINT actions_match_id_fkey,
   ADD CONSTRAINT actions_match_id_fkey FOREIGN KEY (match_id)
   REFERENCES matchs(id) ON DELETE CASCADE;`
2. **Côté Dart** — supprimer les actions d'abord, et entourer d'un `try/catch` avec un
   `SnackBar` d'erreur (comme le fait déjà `_sauvegarderModifs`).

### 🟠 Sécurité

- `lib/supabase_config.dart` est suivi par Git. La clé `anon` est publique par nature,
  donc ce n'est pas grave **à condition que la RLS (Row Level Security) soit activée sur
  les 6 tables**. À vérifier dans le dashboard Supabase. Sans RLS, n'importe qui peut
  lire *et écrire* dans la base depuis l'app décompilée.
- Écriture (`insert`/`update`/`delete`) réservée à l'admin : c'est vrai dans l'UI, mais
  ça doit aussi être vrai en **policies Postgres**.
- 4 `print()` restants en production (`catch (e) { print(...) }`) — à remplacer par un
  vrai log ou un message utilisateur.
- Plusieurs `catch (_) {}` silencieux dans `equipe_service.dart` masquent les erreurs.

### 🟡 Performance et structure

1. **Filtrer côté serveur.** Ajouter `.eq('saison', saison).eq('categorie', cat)` aux
   requêtes. Gain immédiat, changement local, faible risque.
2. **Remplir les `repositories/`.** Un `MatchRepository`, `JoueurRepository`,
   `StatsRepository` qui portent les requêtes — les pages ne parlent plus à Supabase.
3. **Remplir les `providers/`.** Riverpod est déjà installé et `ProviderScope` posé :
   un `FutureProvider` par jeu de données supprime les rechargements en boucle et
   partage le contexte catégorie/saison au lieu de relire `SharedPreferences` partout.
4. **Créer `lib/utils/`** pour les fonctions dupliquées du §7 (une seule copie).
5. **Découper `matchs_tab.dart`** (2 227 l.) : `MatchDetailDialog` et `_TabSessionPage`
   sont déjà des classes séparées → un fichier chacune, quasi sans risque.
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
