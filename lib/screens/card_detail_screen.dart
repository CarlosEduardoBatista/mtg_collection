import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collection.dart';
import '../models/mtg_card.dart';
import '../state/collection_store.dart';
import '../widgets/card_image.dart';
import '../widgets/entry_form.dart';

/// Detalhes de uma carta, com escolha da edição e botão para adicionar.
class CardDetailScreen extends StatefulWidget {
  const CardDetailScreen({super.key, required this.card, this.targetCollectionId});

  final MtgCard card;
  final int? targetCollectionId;

  @override
  State<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends State<CardDetailScreen> {
  late MtgCard _selected = widget.card;
  List<MtgCard>? _prints;
  bool _allLanguages = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _allLanguages = widget.card.lang != 'en';
    _loadPrints();
  }

  Future<void> _loadPrints() async {
    setState(() {
      _prints = null;
      _error = null;
    });
    try {
      final prints = await context.read<CollectionStore>().api.printsOf(widget.card, allLanguages: _allLanguages);
      if (mounted) setState(() => _prints = prints);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CollectionStore>();
    final theme = Theme.of(context);
    final card = _selected;
    final owned = store.entries
        .where((e) => card.oracleId != null ? e.card.oracleId == card.oracleId : e.card.name == card.name)
        .fold(0, (s, e) => s + e.quantity);

    return Scaffold(
      appBar: AppBar(title: Text(card.displayName)),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: () => showAddEntrySheet(context, card, collectionId: widget.targetCollectionId),
            icon: const Icon(Icons.add),
            label: const Text('Adicionar à coleção'),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 300),
              child: CardImage(url: card.imageNormal),
            ),
          ),
          const SizedBox(height: 16),
          Text(card.displayName, style: theme.textTheme.headlineSmall),
          if (card.printedName != null && card.printedName != card.name) Text(card.name),
          if (card.manaCost.isNotEmpty) Text(card.manaCost),
          Text(card.typeLine),
          const SizedBox(height: 8),
          Text(
            '${card.setName} (${card.setCode.toUpperCase()}) · #${card.collectorNumber} · '
            '${rarities[card.rarity] ?? card.rarity} · ${languages[card.lang] ?? card.lang}',
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              Chip(label: Text('Normal: ${store.formatMoney(card.priceUsd)}')),
              Chip(label: Text('Foil: ${store.formatMoney(card.priceUsdFoil)}')),
              if (card.priceEur != null) Chip(label: Text('€ ${card.priceEur!.toStringAsFixed(2)}')),
            ],
          ),
          if (owned > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Você já tem $owned cópia(s) desta carta (todas as edições).',
                  style: TextStyle(color: theme.colorScheme.primary)),
            ),
          const Divider(height: 32),
          Row(
            children: [
              Text('Edições', style: theme.textTheme.titleMedium),
              const Spacer(),
              const Text('Outros idiomas'),
              Switch(
                value: _allLanguages,
                onChanged: (v) {
                  _allLanguages = v;
                  _loadPrints();
                },
              ),
            ],
          ),
          if (_error != null)
            Text(_error!)
          else if (_prints == null)
            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
          else
            SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _prints!.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final p = _prints![i];
                  final selected = p.id == card.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = p),
                    child: Container(
                      width: 88,
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: selected ? theme.colorScheme.primary : Colors.transparent,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Column(
                        children: [
                          CardImage(url: p.imageSmall),
                          Text(
                            '${p.setCode.toUpperCase()} ${p.lang == 'en' ? '' : p.lang.toUpperCase()}',
                            style: theme.textTheme.labelSmall,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
