import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collection.dart';
import '../state/collection_store.dart';
import '../widgets/dialogs.dart';
import 'collection_screen.dart';
import 'scan_screen.dart';
import 'search_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _newCollection(BuildContext context) async {
    final store = context.read<CollectionStore>();
    final name = await askText(context, 'Nova coleção');
    if (name != null && name.isNotEmpty) await store.createCollection(name);
  }

  Future<void> _refreshPrices(BuildContext context) async {
    final store = context.read<CollectionStore>();
    showMessage(context, 'Atualizando preços…');
    try {
      final n = await store.refreshPrices();
      if (context.mounted) showMessage(context, 'Preços de $n cartas atualizados');
    } catch (e) {
      if (context.mounted) showMessage(context, 'Não foi possível atualizar: $e');
    }
  }

  Future<void> _setDollarRate(BuildContext context) async {
    final store = context.read<CollectionStore>();
    final text = await askText(
      context,
      'Cotação do dólar',
      initial: store.dollarRate?.toStringAsFixed(2) ?? '',
      label: 'R\$ por US\$ (vazio = mostrar em dólar)',
    );
    if (text == null) return;
    await store.setDollarRate(text.isEmpty ? null : double.tryParse(text.replaceAll(',', '.')));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CollectionStore>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Minhas coleções'),
        actions: [
          IconButton(
            tooltip: 'Buscar carta',
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SearchScreen())),
          ),
          IconButton(
            tooltip: 'Escanear carta',
            icon: const Icon(Icons.photo_camera_outlined),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ScanScreen())),
          ),
          PopupMenuButton<String>(
            onSelected: (v) => v == 'prices' ? _refreshPrices(context) : _setDollarRate(context),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'prices', child: Text('Atualizar preços')),
              PopupMenuItem(value: 'rate', child: Text('Cotação do dólar')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _newCollection(context),
        icon: const Icon(Icons.create_new_folder_outlined),
        label: const Text('Nova coleção'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(child: _Stat(label: 'Cartas', value: '${store.cardCount(null)}')),
                  Expanded(child: _Stat(label: 'Valor estimado', value: store.formatMoney(store.valueUsd(null)))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          if (store.collections.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Text(
                'Crie sua primeira coleção (ex.: "Fichário Commander")\ne depois adicione cartas pela busca ou pela câmera.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
            ),
          for (final c in store.collections) _CollectionTile(collection: c),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.textTheme.labelMedium),
        Text(value, style: theme.textTheme.headlineSmall),
      ],
    );
  }
}

class _CollectionTile extends StatelessWidget {
  const _CollectionTile({required this.collection});

  final Collection collection;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<CollectionStore>();
    return Card(
      child: ListTile(
        leading: const Icon(Icons.collections_bookmark_outlined),
        title: Text(collection.name),
        subtitle: Text('${store.cardCount(collection.id)} cartas · ${store.formatMoney(store.valueUsd(collection.id))}'),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => CollectionScreen(collectionId: collection.id)),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'rename') {
              final name = await askText(context, 'Renomear coleção', initial: collection.name);
              if (name != null && name.isNotEmpty) await store.renameCollection(collection.id, name);
            } else if (await confirm(
                context, 'Excluir coleção?', '"${collection.name}" e todas as suas cartas serão removidas.')) {
              await store.deleteCollection(collection.id);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'rename', child: Text('Renomear')),
            PopupMenuItem(value: 'delete', child: Text('Excluir')),
          ],
        ),
      ),
    );
  }
}
