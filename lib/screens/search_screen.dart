import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/mtg_card.dart';
import '../state/collection_store.dart';
import '../widgets/card_image.dart';
import 'card_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.targetCollectionId, this.initialQuery});

  /// Coleção já escolhida ao adicionar (quando aberta de dentro de uma coleção).
  final int? targetCollectionId;
  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final _controller = TextEditingController(text: widget.initialQuery);
  Timer? _debounce;
  List<String> _suggestions = const [];
  List<MtgCard>? _results;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final q = widget.initialQuery;
    if (q != null && q.isNotEmpty) _search(q);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (text.trim().length < 2) {
        setState(() => _suggestions = const []);
        return;
      }
      try {
        final s = await context.read<CollectionStore>().api.autocomplete(text.trim());
        if (mounted && _controller.text == text) setState(() => _suggestions = s);
      } catch (_) {
        // Sugestões são opcionais; erros aparecem só na busca.
      }
    });
  }

  Future<void> _search(String query, {bool exactName = false}) async {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() {
      _suggestions = const [];
      _loading = true;
      _error = null;
    });
    try {
      final api = context.read<CollectionStore>().api;
      final results = await api.search(exactName ? '!"$query"' : query);
      if (!mounted) return;
      setState(() => _results = results);
      if (exactName && results.length == 1) _open(results.first);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _open(MtgCard card) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CardDetailScreen(card: card, targetCollectionId: widget.targetCollectionId)),
      );

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: widget.initialQuery == null,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(hintText: 'Nome da carta (em inglês)', border: InputBorder.none),
          onChanged: _onChanged,
          onSubmitted: (q) => q.trim().isEmpty ? null : _search(q.trim()),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _suggestions.isNotEmpty
              ? ListView(
                  children: [
                    for (final s in _suggestions)
                      ListTile(
                        leading: const Icon(Icons.north_west),
                        title: Text(s),
                        onTap: () {
                          _controller.text = s;
                          _search(s, exactName: true);
                        },
                      ),
                  ],
                )
              : _error != null
                  ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!)))
                  : results == null
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'Digite o nome de uma carta.\n\n'
                            'Também aceita a sintaxe do Scryfall, por exemplo:\n'
                            '• t:dragon c:r  (dragões vermelhos)\n'
                            '• s:mh3 r:mythic  (míticas de Modern Horizons 3)\n'
                            '• lang:pt Raio  (cartas em português)',
                          ),
                        )
                      : results.isEmpty
                          ? const Center(child: Text('Nenhuma carta encontrada.'))
                          : ListView.builder(
                              itemCount: results.length,
                              itemBuilder: (_, i) {
                                final card = results[i];
                                return ListTile(
                                  leading: SizedBox(width: 40, child: CardImage(url: card.imageSmall)),
                                  title: Text(card.displayName),
                                  subtitle: Text('${card.typeLine}\n${card.setName}'),
                                  isThreeLine: true,
                                  onTap: () => _open(card),
                                );
                              },
                            ),
    );
  }
}
