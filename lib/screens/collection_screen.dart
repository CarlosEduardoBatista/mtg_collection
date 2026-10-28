import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collection.dart';
import '../state/collection_store.dart';
import '../widgets/card_image.dart';
import 'entry_screen.dart';
import 'search_screen.dart';

enum SortMode { name, priceDesc, cmc, recent }

const _sortLabels = {
  SortMode.name: 'Nome',
  SortMode.priceDesc: 'Maior preço',
  SortMode.cmc: 'Custo de mana',
  SortMode.recent: 'Adicionadas recentemente',
};

/// W U B R G, mais C (incolor) e M (multicolorida).
const _colorFilters = {
  'W': 'Branco',
  'U': 'Azul',
  'B': 'Preto',
  'R': 'Vermelho',
  'G': 'Verde',
  'C': 'Incolor',
  'M': 'Multicolor',
};

class CollectionFilter {
  String text = '';
  Set<String> colors = {};
  String? type;
  String? setCode;
  String? rarity;
  SortMode sort = SortMode.name;

  int get activeCount => colors.length + [type, setCode, rarity].whereType<String>().length;

  bool matches(CollectionEntry e) {
    final card = e.card;
    if (text.isNotEmpty) {
      final t = text.toLowerCase();
      if (!card.name.toLowerCase().contains(t) && !(card.printedName?.toLowerCase().contains(t) ?? false)) {
        return false;
      }
    }
    if (colors.isNotEmpty) {
      final ok = colors.any((c) => switch (c) {
            'C' => card.colors.isEmpty,
            'M' => card.colors.length > 1,
            _ => card.colors.contains(c),
          });
      if (!ok) return false;
    }
    if (type != null && !card.typeLine.contains(cardTypes[type]!)) return false;
    if (setCode != null && card.setCode != setCode) return false;
    if (rarity != null && card.rarity != rarity) return false;
    return true;
  }

  int compare(CollectionEntry a, CollectionEntry b) => switch (sort) {
        SortMode.name => a.card.displayName.compareTo(b.card.displayName),
        SortMode.priceDesc => (b.card.priceFor(foil: b.foil) ?? 0).compareTo(a.card.priceFor(foil: a.foil) ?? 0),
        SortMode.cmc => a.card.cmc.compareTo(b.card.cmc),
        SortMode.recent => b.addedAt.compareTo(a.addedAt),
      };
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, required this.collectionId});

  final int collectionId;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  final _filter = CollectionFilter();

  void _openFilters(List<CollectionEntry> all) {
    final sets = {for (final e in all) e.card.setCode: e.card.setName};
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setSheet) {
          void update(VoidCallback fn) {
            setSheet(fn);
            setState(() {});
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cores', style: Theme.of(context).textTheme.titleMedium),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final e in _colorFilters.entries)
                      FilterChip(
                        label: Text(e.value),
                        selected: _filter.colors.contains(e.key),
                        onSelected: (on) => update(() => on ? _filter.colors.add(e.key) : _filter.colors.remove(e.key)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _NullableDropdown(
                  label: 'Tipo',
                  value: _filter.type,
                  options: {for (final t in cardTypes.keys) t: t},
                  onChanged: (v) => update(() => _filter.type = v),
                ),
                _NullableDropdown(
                  label: 'Raridade',
                  value: _filter.rarity,
                  options: rarities,
                  onChanged: (v) => update(() => _filter.rarity = v),
                ),
                _NullableDropdown(
                  label: 'Edição',
                  value: _filter.setCode,
                  options: Map.fromEntries(sets.entries.toList()..sort((a, b) => a.value.compareTo(b.value))),
                  onChanged: (v) => update(() => _filter.setCode = v),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => update(() {
                    _filter.colors.clear();
                    _filter.type = _filter.rarity = _filter.setCode = null;
                  }),
                  child: const Text('Limpar filtros'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CollectionStore>();
    final collection = store.collectionById(widget.collectionId);
    if (collection == null) return const Scaffold();

    final all = store.entriesOf(collection.id);
    final shown = all.where(_filter.matches).toList()..sort(_filter.compare);
    final shownCount = shown.fold(0, (s, e) => s + e.quantity);
    final shownValue = shown.fold(0.0, (s, e) => s + e.valueUsd);

    return Scaffold(
      appBar: AppBar(
        title: Text(collection.name),
        actions: [
          PopupMenuButton<SortMode>(
            tooltip: 'Ordenar',
            icon: const Icon(Icons.sort),
            initialValue: _filter.sort,
            onSelected: (s) => setState(() => _filter.sort = s),
            itemBuilder: (_) => [
              for (final e in _sortLabels.entries) PopupMenuItem(value: e.key, child: Text(e.value)),
            ],
          ),
          IconButton(
            tooltip: 'Filtros',
            onPressed: () => _openFilters(all),
            icon: Badge(
              isLabelVisible: _filter.activeCount > 0,
              label: Text('${_filter.activeCount}'),
              child: const Icon(Icons.filter_list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Adicionar carta',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SearchScreen(targetCollectionId: collection.id)),
        ),
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Filtrar por nome',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _filter.text = v),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Text('$shownCount cartas'),
                const Spacer(),
                Text(store.formatMoney(shownValue), style: const TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(all.isEmpty ? 'Coleção vazia. Toque em + para adicionar.' : 'Nada encontrado.'))
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 130,
                      childAspectRatio: 0.6,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: shown.length,
                    itemBuilder: (_, i) => _EntryTile(entry: shown[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final CollectionEntry entry;

  @override
  Widget build(BuildContext context) {
    final store = context.read<CollectionStore>();
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EntryScreen(entryId: entry.id))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              CardImage(url: entry.card.imageSmall),
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
                  child: Text('${entry.quantity}x', style: TextStyle(color: scheme.onPrimary, fontSize: 12)),
                ),
              ),
              if (entry.foil)
                const Positioned(left: 4, top: 4, child: Icon(Icons.auto_awesome, size: 18, color: Colors.amber)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            store.formatMoney(entry.card.priceFor(foil: entry.foil)),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _NullableDropdown extends StatelessWidget {
  const _NullableDropdown({required this.label, required this.value, required this.options, required this.onChanged});

  final String label;
  final String? value;
  final Map<String, String> options;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('$label-$value'),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem(value: null, child: Text('Todos')),
          for (final e in options.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
