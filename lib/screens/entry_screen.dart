import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collection.dart';
import '../state/collection_store.dart';
import '../widgets/card_image.dart';
import '../widgets/dialogs.dart';
import '../widgets/entry_form.dart';
import 'card_detail_screen.dart';

/// Edita uma carta que já está na coleção (quantidade, estado, mover, excluir).
class EntryScreen extends StatelessWidget {
  const EntryScreen({super.key, required this.entryId});

  final int entryId;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CollectionStore>();
    final entry = store.entryById(entryId);
    if (entry == null) return const Scaffold();
    final card = entry.card;

    return Scaffold(
      appBar: AppBar(
        title: Text(card.displayName),
        actions: [
          IconButton(
            tooltip: 'Ver edições',
            icon: const Icon(Icons.info_outline),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CardDetailScreen(card: card))),
          ),
          IconButton(
            tooltip: 'Remover',
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              if (!await confirm(context, 'Remover carta?', '${entry.quantity}x ${card.displayName} será removida.')) {
                return;
              }
              await store.deleteEntry(entry.id);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 240),
              child: CardImage(url: card.imageNormal),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${card.setName} · #${card.collectorNumber} · ${rarities[card.rarity] ?? card.rarity}',
            textAlign: TextAlign.center,
          ),
          Text(
            'Unidade: ${store.formatMoney(card.priceFor(foil: entry.foil))} · Total: ${store.formatMoney(entry.valueUsd)}',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(height: 32),
          EntryForm(
            key: ValueKey(entry.id),
            card: card,
            initial: EntryData(
              collectionId: entry.collectionId,
              quantity: entry.quantity,
              foil: entry.foil,
              condition: entry.condition,
              language: entry.language,
            ),
            submitLabel: 'Salvar',
            onSubmit: (data) async {
              await store.updateEntry(entry, data);
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
