import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../repositories/match_repository.dart';
import '../repositories/stats_repository.dart';

/// Les providers transverses : le contexte de l'app et l'accès aux données.
///
/// POURQUOI
///   Avant, chaque page relisait `SharedPreferences` dans son `initState`, puis
///   rechargeait tout depuis zéro. Aller sur Résultats, revenir, y retourner
///   déclenchait deux chargements complets identiques.
///
///   Ici, le contexte est lu une fois et les données sont mises en cache par
///   Riverpod. Changer de saison invalide le contexte, ce qui recharge en
///   cascade tout ce qui en dépend — sans qu'aucune page n'ait à le savoir.

// =====================================================================
// Le contexte : catégorie + saison
// =====================================================================

/// La catégorie et la saison actuellement affichées.
///
/// C'est le concept central de STATOK (voir ARCHITECTURE.md §4) : ces deux
/// valeurs filtrent absolument tout ce que l'app montre.
class ContexteApp {
  const ContexteApp({this.categorie, this.saison});

  /// Le **libellé d'interface** : `'U16 - U17 - U18'`, pas `'U16-17-18'`.
  /// La conversion vers la valeur base est faite par les repositories.
  final String? categorie;

  /// Format `'2025-2026'`.
  final String? saison;

  @override
  bool operator ==(Object other) =>
      other is ContexteApp &&
      other.categorie == categorie &&
      other.saison == saison;

  @override
  int get hashCode => Object.hash(categorie, saison);

  @override
  String toString() => 'ContexteApp($categorie, $saison)';
}

/// Clés utilisées dans `SharedPreferences`. Déclarées ici pour ne plus les
/// retrouver écrites en dur dans cinq fichiers.
const String cleCategorie = 'selected_category';
const String cleSaison = 'selected_season';

/// Lit le contexte depuis `SharedPreferences`.
///
/// Le résultat est mis en cache. Après avoir écrit une nouvelle saison ou
/// catégorie, appeler [rafraichirContexte] pour que tout se recharge.
final contexteProvider = FutureProvider<ContexteApp>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return ContexteApp(
    categorie: prefs.getString(cleCategorie),
    saison: prefs.getString(cleSaison),
  );
});

/// Enregistre un nouveau contexte et recharge tout ce qui en dépend.
///
/// À appeler depuis les sélecteurs de saison et l'écran de choix de catégorie.
/// Sans cet appel, les pages continueraient d'afficher l'ancienne saison.
Future<void> majContexte(
  WidgetRef ref, {
  String? categorie,
  String? saison,
}) async {
  final prefs = await SharedPreferences.getInstance();
  if (categorie != null) await prefs.setString(cleCategorie, categorie);
  if (saison != null) await prefs.setString(cleSaison, saison);
  ref.invalidate(contexteProvider);
}

// =====================================================================
// Les saisons disponibles
// =====================================================================

/// Première saison couverte par l'application.
const int premiereSaison = 2025;

/// Jour de bascule d'une saison à l'autre : le 28 mai.
final DateTime Function() _maintenant = DateTime.now;

/// La liste des saisons proposées, de la plus récente à la plus ancienne.
///
/// Elle est calculée, jamais stockée. Ce code était dupliqué à l'identique dans
/// `home_page.dart` et `admin_dashboard.dart`.
List<String> saisonsDisponibles() {
  final now = _maintenant();
  final debutSaisonCourante = now.isBefore(DateTime(now.year, 5, 28))
      ? now.year - 1
      : now.year;

  return [
    for (int annee = debutSaisonCourante; annee >= premiereSaison; annee--)
      '$annee-${annee + 1}',
  ];
}

// =====================================================================
// L'accès aux données
// =====================================================================

final matchRepositoryProvider = Provider<MatchRepository>(
  (ref) => MatchRepository(),
);

final statsRepositoryProvider = Provider<StatsRepository>(
  (ref) => StatsRepository(),
);
