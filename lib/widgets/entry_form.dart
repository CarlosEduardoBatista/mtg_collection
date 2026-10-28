import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/collection.dart';
import '../models/mtg_card.dart';
import '../state/collection_store.dart';
import 'dialogs.dart';

/// Formulário de quantidade, coleção, foil, estado e idioma.
/// Usado tanto para adicionar uma carta quanto para editar uma entrada.
class EntryForm extends StatefulWidget {
  const EntryForm({
    super.key,
    required this.card,
    this.initial,
    this.collectionId,
    required this.submitLabel,
    required this.onSubmit,
  });

  final MtgCard card;
  final EntryData? initial;
  final int? collectionId;
  final String submitLabel;
  final Future<void> Function(EntryData data) onSubmit;

  @override
  State<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends State<EntryForm> {
  static const _newCollection = -1;

  int? _collectionId;
  int _dropdownVersion = 0;
  late int _quantity;
  late bool _foil;
  late String _condition;
  late String _language;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final init = widget.initial;
    final store = context.read<CollectionStore>();
    _collectionId = init?.collectionId ?? widget.collectionId ?? store.collections.firstOrNull?.id;
    _quantity = init?.quantity ?? 1;
    _foil = init?.foil ?? !widget.card.hasNonFoil;
    _condition = init?.condition ?? 'NM';
    _language = init?.language ?? (languages.containsKey(widget.card.lang) ? widget.card.lang : 'en');
  }

  Future<void> _pickCollection(int? value) async {
    if (value != _newCollection) {
      setState(() => _collectionId = value);
      return;
    }
    final store = context.read<CollectionStore>();
    final name = await askText(context, 'Nova coleção');
    final id = (name == null || name.isEmpty) ? null : await store.createCollection(name);
    // Recria o seletor para ele não ficar mostrando "+ Nova coleção" se o usuário cancelar.
    if (mounted) {
      setState(() {
        _collectionId = id ?? _collectionId;
        _dropdownVersion++;
      });
    }
  }

  Future<void> _submit() async {
    final collectionId = _collectionId;
    if (collectionId == null) {
      showMessage(context, 'Escolha ou crie uma coleção');
      return;
    }
    setState(() => _saving = true);
    try {
      await widget.onSubmit(EntryData(
        collectionId: collectionId,
        quantity: _quantity,
        foil: _foil,
        condition: _condition,
        language: _language,
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collections = context.watch<CollectionStore>().collections;
    final card = widget.card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        DropdownButtonFormField<int>(
          key: ValueKey('$_collectionId-$_dropdownVersion'),
          initialValue: _collectionId,
          decoration: const InputDecoration(labelText: 'Coleção'),
          items: [
            for (final c in collections) DropdownMenuItem(value: c.id, child: Text(c.name)),
            const DropdownMenuItem(value: _newCollection, child: Text('+ Nova coleção')),
          ],
          onChanged: _pickCollection,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Quantidade'),
            const Spacer(),
            IconButton.outlined(
              onPressed: _quantity > 1 ? () => setState(() => _quantity--) : null,
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 48,
              child: Text('$_quantity', textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
            ),
            IconButton.outlined(onPressed: () => setState(() => _quantity++), icon: const Icon(Icons.add)),
          ],
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Foil'),
          subtitle: !card.hasFoil
              ? const Text('Esta edição não tem versão foil')
              : !card.hasNonFoil
                  ? const Text('Esta edição só existe em foil')
                  : null,
          value: _foil,
          onChanged: card.hasFoil && card.hasNonFoil ? (v) => setState(() => _foil = v) : null,
        ),
        DropdownButtonFormField<String>(
          initialValue: _condition,
          decoration: const InputDecoration(labelText: 'Estado'),
          items: [for (final e in conditions.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _condition = v!),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: _language,
          decoration: const InputDecoration(labelText: 'Idioma'),
          items: [for (final e in languages.entries) DropdownMenuItem(value: e.key, child: Text(e.value))],
          onChanged: (v) => setState(() => _language = v!),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(widget.submitLabel),
        ),
      ],
    );
  }
}

/// Abre o formulário em uma folha inferior para adicionar [card] à coleção.
Future<void> showAddEntrySheet(BuildContext context, MtgCard card, {int? collectionId}) {
  final store = context.read<CollectionStore>();
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(sheetContext).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(card.displayName, style: Theme.of(sheetContext).textTheme.titleLarge),
            Text('${card.setName} · #${card.collectorNumber}'),
            const SizedBox(height: 12),
            EntryForm(
              card: card,
              collectionId: collectionId,
              submitLabel: 'Adicionar à coleção',
              onSubmit: (data) async {
                await store.addEntry(card, data);
                if (sheetContext.mounted) Navigator.pop(sheetContext);
                final name = store.collectionById(data.collectionId)?.name ?? 'coleção';
                messenger.showSnackBar(SnackBar(content: Text('${data.quantity}x ${card.displayName} → $name')));
              },
            ),
          ],
        ),
      ),
    ),
  );
}
