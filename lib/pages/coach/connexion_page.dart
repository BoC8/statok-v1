import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../theme/app_theme.dart';
import '../../widgets/entete.dart';

/// L'entrée de l'espace coachs.
///
/// UNE VRAIE AUTHENTIFICATION, PAS UN CODE
///   La maquette proposait un code à quatre chiffres écrit en dur dans
///   le code source. Il aurait été lisible par quiconque ouvre le
///   dépôt, identique pour tout le staff, et sans lien avec les
///   habilitations par catégorie. On garde les comptes Supabase : c'est
///   eux que les politiques RLS reconnaissent.
class ConnexionPage extends ConsumerStatefulWidget {
  const ConnexionPage({super.key});

  @override
  ConsumerState<ConnexionPage> createState() => _ConnexionPageState();
}

class _ConnexionPageState extends ConsumerState<ConnexionPage> {
  final _email = TextEditingController();
  final _motDePasse = TextEditingController();
  bool _enCours = false;
  bool _masque = true;
  String? _erreur;

  @override
  void dispose() {
    _email.dispose();
    _motDePasse.dispose();
    super.dispose();
  }

  Future<void> _connecter() async {
    setState(() {
      _enCours = true;
      _erreur = null;
    });
    try {
      await ref.read(adminRepositoryProvider).connexion(
        email: _email.text.trim(),
        motDePasse: _motDePasse.text,
      );
      ref.invalidate(profilProvider);
    } catch (e) {
      // Le message de Supabase est en anglais et parfois technique.
      // On dit ce qui est utile sans révéler si l'adresse existe.
      setState(() => _erreur = 'Identifiants incorrects.');
    } finally {
      if (mounted) setState(() => _enCours = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pret =
        _email.text.trim().isNotEmpty && _motDePasse.text.isNotEmpty;

    return Scaffold(
      backgroundColor: Couleurs.nuit,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Blason(taille: 54),
                const SizedBox(height: 18),
                Text(
                  'Espace coachs',
                  style: Typo.titre(taille: 20, couleur: Colors.white),
                ),
                const SizedBox(height: 6),
                Text(
                  'Réservé au staff du FC Pierre Bleue',
                  style: Typo.texte(
                    taille: 12.5,
                    couleur: const Color(0xFF9DB0CE),
                  ),
                ),
                const SizedBox(height: 28),

                _Champ(
                  controleur: _email,
                  libelle: 'Adresse e-mail',
                  clavier: TextInputType.emailAddress,
                  onChange: () => setState(() {}),
                ),
                const SizedBox(height: 12),
                _Champ(
                  controleur: _motDePasse,
                  libelle: 'Mot de passe',
                  masque: _masque,
                  onChange: () => setState(() {}),
                  onValider: pret && !_enCours ? _connecter : null,
                  suffixe: IconButton(
                    onPressed: () => setState(() => _masque = !_masque),
                    icon: Icon(
                      _masque ? Icons.visibility_off : Icons.visibility,
                      size: 19,
                      color: const Color(0xFF9DB0CE),
                    ),
                  ),
                ),

                if (_erreur != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    _erreur!,
                    textAlign: TextAlign.center,
                    style: Typo.texte(taille: 12.5, couleur: Couleurs.or),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Couleurs.bleu,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      disabledBackgroundColor: Couleurs.nuit2,
                    ),
                    onPressed: pret && !_enCours ? _connecter : null,
                    child: _enCours
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            'Se connecter',
                            style: Typo.texte(
                              taille: 14,
                              graisse: 700,
                              couleur: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  "Si vous n'arrivez pas à vous connecter, contactez Clément Bolomey",
                  textAlign: TextAlign.center,
                  style: Typo.texte(
                    taille: 11,
                    couleur: const Color(0xFF6B7D9B),
                    hauteurLigne: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Champ extends StatelessWidget {
  const _Champ({
    required this.controleur,
    required this.libelle,
    required this.onChange,
    this.clavier,
    this.masque = false,
    this.suffixe,
    this.onValider,
  });

  final TextEditingController controleur;
  final String libelle;
  final VoidCallback onChange;
  final TextInputType? clavier;
  final bool masque;
  final Widget? suffixe;
  final VoidCallback? onValider;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controleur,
      keyboardType: clavier,
      obscureText: masque,
      autocorrect: false,
      enableSuggestions: false,
      onChanged: (_) => onChange(),
      onSubmitted: onValider == null ? null : (_) => onValider!(),
      style: Typo.texte(taille: 14, couleur: Colors.white),
      decoration: InputDecoration(
        labelText: libelle,
        labelStyle: Typo.texte(
          taille: 12.5,
          couleur: const Color(0xFF9DB0CE),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.08),
        suffixIcon: suffixe,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: Couleurs.bleu, width: 2),
        ),
      ),
    );
  }
}
