import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/equipe.dart';
import '../../models/joueur.dart';
import '../../providers/auth_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/communs.dart';

/// Les champs de formulaire de l'espace coachs.
///
/// Ils sont regroupés ici pour que tous les écrans de saisie aient la
/// même allure et le même comportement, sans qu'on ait à y penser.

/// L'étiquette au-dessus d'un champ.
class _Etiquette extends StatelessWidget {
  const _Etiquette(this.texte);

  final String texte;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Text(
      texte,
      style: Typo.texte(taille: 11.5, graisse: 600, couleur: Couleurs.gris),
    ),
  );
}

InputDecoration _decoration({Widget? suffixe, bool dense = false}) =>
    InputDecoration(
      isDense: dense,
      filled: true,
      fillColor: Couleurs.blanc,
      suffixIcon: suffixe,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: dense ? 9 : 12,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Couleurs.ligne),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Couleurs.ligne),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(11),
        borderSide: const BorderSide(color: Couleurs.bleu, width: 2),
      ),
    );

/// Une liste déroulante.
class ChampListe<T> extends StatelessWidget {
  const ChampListe({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.options,
    required this.onChange,
  });

  final String libelle;
  final T? valeur;
  final List<(T, String)> options;
  final ValueChanged<T?> onChange;

  @override
  Widget build(BuildContext context) {
    // Une valeur absente de la liste ferait planter le DropdownButton :
    // on la neutralise plutôt que de faire confiance à l'appelant.
    final valide = options.any((o) => o.$1 == valeur) ? valeur : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Etiquette(libelle),
          DropdownButtonFormField<T>(
            initialValue: valide,
            isExpanded: true,
            decoration: _decoration(),
            style: Typo.texte(taille: 13.5),
            items: [
              for (final (v, l) in options)
                DropdownMenuItem(
                  value: v,
                  child: Text(l, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: onChange,
          ),
        ],
      ),
    );
  }
}

/// Un champ numérique entier positif.
class ChampNombre extends StatelessWidget {
  const ChampNombre({
    super.key,
    required this.libelle,
    required this.controleur,
    required this.onChange,
  });

  final String libelle;
  final TextEditingController controleur;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Etiquette(libelle),
          TextField(
            controller: controleur,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => onChange(),
            style: Typo.texte(taille: 14),
            decoration: _decoration(),
          ),
        ],
      ),
    );
  }
}

/// Un sélecteur à plusieurs positions.
class ChampSegments extends StatelessWidget {
  const ChampSegments({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.options,
    required this.onChange,
  });

  final String libelle;
  final String valeur;
  final List<(String, String)> options;
  final ValueChanged<String> onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Etiquette(libelle),
          // Au-delà de trois positions les libellés deviennent illisibles
          // sur un téléphone : on passe alors en puces qui se replient.
          if (options.length <= 3)
            Segments(options: options, actif: valeur, onChoix: onChange)
          else
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                for (final (v, l) in options)
                  PuceFiltre(
                    libelle: l,
                    choisi: v == valeur,
                    onTap: () => onChange(v),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// La date et l'heure du coup d'envoi.
class ChampDateHeure extends StatelessWidget {
  const ChampDateHeure({
    super.key,
    required this.valeur,
    required this.onChange,
  });

  final DateTime valeur;
  final ValueChanged<DateTime> onChange;

  Future<void> _choisirDate(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: valeur,
      firstDate: DateTime(valeur.year - 2),
      lastDate: DateTime(valeur.year + 2),
      locale: const Locale('fr', 'FR'),
    );
    if (d == null) return;
    onChange(DateTime(d.year, d.month, d.day, valeur.hour, valeur.minute));
  }

  Future<void> _choisirHeure(BuildContext context) async {
    final h = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(valeur),
      builder: (ctx, enfant) => MediaQuery(
        // Les horaires de match se disent en 24 h, jamais en AM/PM.
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: enfant!,
      ),
    );
    if (h == null) return;
    onChange(
      DateTime(valeur.year, valeur.month, valeur.day, h.hour, h.minute),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Etiquette('Date'),
                _Bouton(
                  texte: avecMajuscule(dateLongue(valeur)),
                  icone: Icons.calendar_today,
                  onTap: () => _choisirDate(context),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _Etiquette('Coup d’envoi'),
                _Bouton(
                  texte: heureDe(valeur),
                  icone: Icons.schedule,
                  onTap: () => _choisirHeure(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bouton extends StatelessWidget {
  const _Bouton({
    required this.texte,
    required this.icone,
    required this.onTap,
  });

  final String texte;
  final IconData icone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Couleurs.blanc,
          border: Border.all(color: Couleurs.ligne),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Row(
          children: [
            Icon(icone, size: 15, color: Couleurs.gris2),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                texte,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Typo.texte(taille: 13.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le choix d'un joueur, avec recherche.
///
/// Soixante licenciés dans une liste déroulante, c'est trop pour qu'on
/// s'y retrouve : on tape les premières lettres.
///
/// LA LISTE EST RÉDUITE AUX JOUEURS ÉLIGIBLES
///   Proposer les soixante licenciés du club pour un match d'U17, c'est
///   inviter à la faute de saisie. On ne garde que ceux qui peuvent
///   réellement évoluer dans l'équipe : le bon genre, et une génération
///   au plus égale au plafond de l'équipe. Le surclassement reste
///   possible — un 16 joue en U18 —, l'inverse jamais.
///
///   Une bascule permet quand même d'afficher tout le club : une règle
///   qui empêche de saisir la réalité est une mauvaise règle.
class ChampJoueur extends StatelessWidget {
  const ChampJoueur({
    super.key,
    required this.libelle,
    required this.valeur,
    required this.joueurs,
    required this.onChange,
    this.equipe,
    this.facultatif = false,
    this.exclu,
    this.compact = false,
  });

  final String libelle;
  final String? valeur;
  final List<Joueur> joueurs;
  final ValueChanged<String?> onChange;

  /// L'équipe qui joue la rencontre. Sans elle, aucun filtrage.
  final Equipe? equipe;

  final bool facultatif;

  /// Un joueur à retirer de la liste — le buteur, quand on choisit son
  /// passeur : la base refuse qu'il se serve lui-même.
  final String? exclu;

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final choisi = _trouver(valeur);
    final disponibles = joueurs.where((j) => j.id != exclu).toList();
    final eligibles = equipe == null
        ? disponibles
        : disponibles
              .where(
                (j) =>
                    j.genre == equipe!.genre &&
                    equipe!.accepteGeneration(j.generation),
              )
              .toList();

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 0 : 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!compact) _Etiquette(libelle),
          InkWell(
            onTap: () async {
              final id = await _choisir(context, eligibles, disponibles);
              if (id != null) onChange(id == '' ? null : id);
            },
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 12,
                vertical: compact ? 9 : 13,
              ),
              decoration: BoxDecoration(
                color: Couleurs.blanc,
                border: Border.all(color: Couleurs.ligne),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      choisi?.nomComplet ??
                          (facultatif ? 'Aucun' : 'Choisir $libelle'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.texte(
                        taille: 13.5,
                        couleur: choisi == null
                            ? Couleurs.gris2
                            : Couleurs.nuit,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: Couleurs.gris2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Joueur? _trouver(String? id) {
    if (id == null) return null;
    for (final j in joueurs) {
      if (j.id == id) return j;
    }
    return null;
  }

  Future<String?> _choisir(
    BuildContext context,
    List<Joueur> eligibles,
    List<Joueur> tous,
  ) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Couleurs.blanc,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ListeJoueurs(
        eligibles: eligibles,
        tous: tous,
        titre: libelle,
        nomEquipe: equipe?.nom,
        avecAucun: facultatif,
      ),
    );
  }
}

class _ListeJoueurs extends StatefulWidget {
  const _ListeJoueurs({
    required this.eligibles,
    required this.tous,
    required this.titre,
    required this.nomEquipe,
    required this.avecAucun,
  });

  final List<Joueur> eligibles;
  final List<Joueur> tous;
  final String titre;
  final String? nomEquipe;
  final bool avecAucun;

  @override
  State<_ListeJoueurs> createState() => _ListeJoueursState();
}

class _ListeJoueursState extends State<_ListeJoueurs> {
  String _recherche = '';
  bool _toutLeClub = false;

  @override
  Widget build(BuildContext context) {
    final source = _toutLeClub ? widget.tous : widget.eligibles;
    final masques = widget.tous.length - widget.eligibles.length;
    final terme = _recherche.trim().toLowerCase();
    final liste = terme.isEmpty
        ? source
        : source
              .where((j) => j.nomComplet.toLowerCase().contains(terme))
              .toList();

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 10),
              decoration: BoxDecoration(
                color: Couleurs.ligne,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _recherche = v),
                style: Typo.texte(taille: 14),
                decoration: _decoration(
                  suffixe: const Icon(
                    Icons.search,
                    size: 19,
                    color: Couleurs.gris2,
                  ),
                ).copyWith(hintText: 'Rechercher un joueur'),
              ),
            ),
            if (masques > 0 && widget.nomEquipe != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 10, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _toutLeClub
                            ? 'Tous les licenciés du club'
                            : '${widget.eligibles.length} joueur'
                                  '${widget.eligibles.length > 1 ? 's' : ''} '
                                  'éligible'
                                  '${widget.eligibles.length > 1 ? 's' : ''} '
                                  'en ${widget.nomEquipe}',
                        style: Typo.texte(
                          taille: 11.5,
                          couleur: Couleurs.gris,
                        ),
                      ),
                    ),
                    Switch(
                      value: _toutLeClub,
                      activeThumbColor: Couleurs.bleu,
                      onChanged: (v) => setState(() => _toutLeClub = v),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (widget.avecAucun)
                    ListTile(
                      title: Text(
                        'Aucun',
                        style: Typo.texte(
                          taille: 13.5,
                          couleur: Couleurs.gris,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(''),
                    ),
                  if (liste.isEmpty)
                    Vide(
                      message: terme.isNotEmpty
                          ? 'Aucun joueur à ce nom.'
                          : "Aucun licencié ne peut évoluer dans cette "
                                'équipe. Vérifiez les générations dans la '
                                'liste des joueurs, ou affichez tout le '
                                'club ci-dessus.',
                    ),
                  for (final j in liste)
                    ListTile(
                      dense: true,
                      title: Text(
                        j.nomComplet,
                        style: Typo.texte(taille: 13.5, graisse: 600),
                      ),
                      subtitle: Text(
                        j.libelleAge,
                        style: Typo.texte(
                          taille: 11,
                          couleur: Couleurs.gris2,
                        ),
                      ),
                      onTap: () => Navigator.of(context).pop(j.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Le choix de l'adversaire, avec création à la volée.
///
/// Un coach qui saisit un match contre un club jamais rencontré doit
/// pouvoir créer la fiche sur le moment : attendre un administrateur un
/// dimanche soir n'est pas une option.
class ChampAdversaire extends ConsumerWidget {
  const ChampAdversaire({
    super.key,
    required this.valeur,
    required this.onChange,
  });

  final String? valeur;
  final ValueChanged<String?> onChange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final liste = ref.watch(adversairesProvider).value ?? const [];
    String? nom;
    for (final a in liste) {
      if (a.id == valeur) nom = a.nom;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _Etiquette('Adversaire'),
          InkWell(
            onTap: () async {
              final id = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Couleurs.blanc,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
                builder: (_) => const _ListeAdversaires(),
              );
              if (id != null) onChange(id);
            },
            borderRadius: BorderRadius.circular(11),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 13,
              ),
              decoration: BoxDecoration(
                color: Couleurs.blanc,
                border: Border.all(color: Couleurs.ligne),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      nom ?? "Choisir l'adversaire",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Typo.texte(
                        taille: 13.5,
                        couleur: nom == null ? Couleurs.gris2 : Couleurs.nuit,
                      ),
                    ),
                  ),
                  const Icon(
                    Icons.expand_more,
                    size: 18,
                    color: Couleurs.gris2,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ListeAdversaires extends ConsumerStatefulWidget {
  const _ListeAdversaires();

  @override
  ConsumerState<_ListeAdversaires> createState() => _ListeAdversairesState();
}

class _ListeAdversairesState extends ConsumerState<_ListeAdversaires> {
  String _recherche = '';
  bool _creation = false;

  Future<void> _creer() async {
    final nom = _recherche.trim();
    if (nom.isEmpty) return;
    setState(() => _creation = true);
    try {
      final cree = await ref
          .read(adminRepositoryProvider)
          .creerAdversaire(nom);
      ref.invalidate(adversairesProvider);
      if (mounted) Navigator.of(context).pop(cree.id);
    } catch (_) {
      if (mounted) setState(() => _creation = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tous = ref.watch(adversairesProvider).value ?? const [];
    final terme = _recherche.trim().toLowerCase();
    final liste = terme.isEmpty
        ? tous
        : tous.where((a) => a.nom.toLowerCase().contains(terme)).toList();

    // On ne propose la création que si le nom tapé n'existe pas déjà,
    // au caractère près : c'est ainsi qu'on évite « Derval » et
    // « derval » côte à côte.
    final existeExactement = tous.any(
      (a) => a.nom.toLowerCase() == terme,
    );
    final peutCreer = terme.isNotEmpty && !existeExactement;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.only(top: 8, bottom: 10),
              decoration: BoxDecoration(
                color: Couleurs.ligne,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _recherche = v),
                textCapitalization: TextCapitalization.words,
                style: Typo.texte(taille: 14),
                decoration: _decoration(
                  suffixe: const Icon(
                    Icons.search,
                    size: 19,
                    color: Couleurs.gris2,
                  ),
                ).copyWith(hintText: 'Rechercher ou créer un adversaire'),
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 16),
                children: [
                  if (peutCreer)
                    ListTile(
                      leading: _creation
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.add_circle_outline,
                              color: Couleurs.bleu,
                            ),
                      title: Text(
                        'Créer « ${_recherche.trim()} »',
                        style: Typo.texte(
                          taille: 13.5,
                          graisse: 600,
                          couleur: Couleurs.bleu,
                        ),
                      ),
                      onTap: _creation ? null : _creer,
                    ),
                  if (liste.isEmpty && !peutCreer)
                    const Vide(message: 'Aucun adversaire à ce nom.'),
                  for (final a in liste)
                    ListTile(
                      dense: true,
                      title: Text(
                        a.nom,
                        style: Typo.texte(taille: 13.5, graisse: 600),
                      ),
                      onTap: () => Navigator.of(context).pop(a.id),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
