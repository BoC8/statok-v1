import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class CompactFilterButton extends StatelessWidget {
  final List<String> equipes;
  final List<String> competitions;
  final Set<String> selectedEquipes;
  final Set<String> selectedCompetitions;
  final Set<String> selectedLieux;
  final bool showEquipes;
  final Color Function(String competition) competitionColor;
  final void Function(
    Set<String> equipes,
    Set<String> competitions,
    Set<String> lieux,
  )
  onApply;
  final Widget? trailing;

  const CompactFilterButton({
    super.key,
    required this.equipes,
    required this.competitions,
    required this.selectedEquipes,
    required this.selectedCompetitions,
    this.selectedLieux = const {},
    this.showEquipes = true,
    required this.competitionColor,
    required this.onApply,
    this.trailing,
  });

  static const Map<String, String> _lieuLabels = {
    'DOM': 'Domicile',
    'EXT': 'Extérieur',
  };

  int get _activeCount =>
      selectedEquipes.length +
      selectedCompetitions.length +
      selectedLieux.length;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.black12)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const filterWidth = 112.0;
          const gapWidth = 8.0;
          const preferredSearchWidth = 238.0;
          const minSearchWidth = 210.0;
          final maxSearchWidth = constraints.maxWidth - filterWidth - gapWidth;
          final searchWidth = maxSearchWidth < minSearchWidth
              ? maxSearchWidth
              : (maxSearchWidth > preferredSearchWidth
                    ? preferredSearchWidth
                    : maxSearchWidth);

          return Row(
            children: [
              SizedBox(
                width: filterWidth,
                child: OutlinedButton.icon(
                  onPressed: () => _openFilters(context),
                  icon: const Icon(Icons.tune, size: 18),
                  label: Text(
                    _activeCount == 0 ? 'Filtrer' : 'Filtrer ($_activeCount)',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.bleuMarine,
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (trailing != null) ...[
                const Spacer(),
                const SizedBox(width: gapWidth),
                SizedBox(width: searchWidth, child: trailing!),
              ],
            ],
          );
        },
      ),
    );
  }

  void _openFilters(BuildContext context) {
    final draftEquipes = Set<String>.from(selectedEquipes);
    final draftCompetitions = Set<String>.from(selectedCompetitions);
    final draftLieux = Set<String>.from(selectedLieux);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            void toggle(Set<String> target, String value) {
              setModalState(() {
                if (target.contains(value)) {
                  target.remove(value);
                } else {
                  target.add(value);
                }
              });
            }

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.tune, color: AppTheme.bleuMarine),
                          const SizedBox(width: 8),
                          const Text(
                            'Filtres',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.bleuMarine,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (showEquipes) ...[
                        _buildSection(
                          title: 'FCPB',
                          icon: Icons.groups,
                          emptyText: 'Aucune equipe disponible.',
                          children: equipes.map((equipe) {
                            return _buildChip(
                              label: equipe,
                              selected: draftEquipes.contains(equipe),
                              color: AppTheme.bleuMarine,
                              onTap: () => toggle(draftEquipes, equipe),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                      ],
                      _buildSection(
                        title: 'Competitions',
                        icon: Icons.emoji_events,
                        emptyText: 'Aucune competition disponible.',
                        children: competitions.map((competition) {
                          final color = competitionColor(competition);
                          return _buildChip(
                            label: competition,
                            selected: draftCompetitions.contains(competition),
                            color: color,
                            showDot: true,
                            onTap: () => toggle(draftCompetitions, competition),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _buildSection(
                        title: 'Lieu',
                        icon: Icons.location_on,
                        emptyText: 'Aucun lieu disponible.',
                        children: _lieuLabels.entries.map((entry) {
                          return _buildChip(
                            label: entry.value,
                            selected: draftLieux.contains(entry.key),
                            color: AppTheme.bleuMarine,
                            onTap: () => toggle(draftLieux, entry.key),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                draftEquipes.clear();
                                draftCompetitions.clear();
                                draftLieux.clear();
                              });
                            },
                            child: const Text('Effacer'),
                          ),
                          const Spacer(),
                          ElevatedButton(
                            onPressed: () {
                              onApply(
                                draftEquipes,
                                draftCompetitions,
                                draftLieux,
                              );
                              Navigator.pop(context);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.bleuMarine,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 12,
                              ),
                            ),
                            child: const Text('Appliquer'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 17, color: AppTheme.bleuMarine),
            const SizedBox(width: 6),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.bleuMarine,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (children.isEmpty)
          Text(
            emptyText,
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          )
        else
          Wrap(spacing: 6, runSpacing: 6, children: children),
      ],
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
    bool showDot = false,
  }) {
    return RawChip(
      label: Text(label),
      avatar: showDot
          ? Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            )
          : null,
      selected: selected,
      onPressed: onTap,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: selected ? FontWeight.bold : FontWeight.w600,
        color: selected ? color : Colors.black87,
      ),
      side: BorderSide(color: selected ? color : Colors.grey.shade300),
      selectedColor: color.withValues(alpha: 0.14),
      backgroundColor: Colors.white,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
      padding: const EdgeInsets.symmetric(horizontal: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    );
  }
}

class AdversaireSearchField extends StatefulWidget {
  final String value;
  final List<String> adversaires;
  final ValueChanged<String> onChanged;

  const AdversaireSearchField({
    super.key,
    required this.value,
    required this.adversaires,
    required this.onChanged,
  });

  @override
  State<AdversaireSearchField> createState() => _AdversaireSearchFieldState();
}

class _AdversaireSearchFieldState extends State<AdversaireSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant AdversaireSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(
        offset: widget.value.length,
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<String>(
      textEditingController: _controller,
      focusNode: _focusNode,
      optionsBuilder: (textEditingValue) {
        final query = textEditingValue.text.trim().toLowerCase();
        if (query.isEmpty) return const Iterable<String>.empty();
        return widget.adversaires.where(
          (adversaire) => adversaire.toLowerCase().contains(query),
        );
      },
      onSelected: (value) {
        _controller.text = value;
        _controller.selection = TextSelection.collapsed(offset: value.length);
        widget.onChanged(value);
      },
      fieldViewBuilder:
          (context, textEditingController, focusNode, onFieldSubmitted) {
            return SizedBox(
              height: 32,
              child: TextField(
                controller: textEditingController,
                focusNode: focusNode,
                onChanged: (_) => setState(() {}),
                onSubmitted: (text) => widget.onChanged(text),
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Chercher un adversaire',
                  prefixIcon: const Icon(Icons.search, size: 18),
                  prefixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  suffixIcon: _controller.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            textEditingController.clear();
                            setState(() {});
                            widget.onChanged('');
                          },
                          icon: const Icon(Icons.close, size: 18),
                        ),
                  suffixIconConstraints: const BoxConstraints(
                    minWidth: 40,
                    minHeight: 40,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: AppTheme.bleuMarine),
                  ),
                ),
              ),
            );
          },
      optionsViewBuilder: (context, onSelected, options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(8),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180, maxWidth: 260),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final option = options.elementAt(index);
                  return ListTile(
                    dense: true,
                    minVerticalPadding: 6,
                    title: Text(option, style: const TextStyle(fontSize: 13)),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
