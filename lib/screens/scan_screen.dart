import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../models/mtg_card.dart';
import '../state/collection_store.dart';
import '../widgets/card_image.dart';
import '../widgets/entry_form.dart';
import 'card_detail_screen.dart';
import 'search_screen.dart';

/// Fotografa uma carta, lê o nome com OCR (no aparelho) e procura no Scryfall.
class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key, this.targetCollectionId});

  final int? targetCollectionId;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  File? _photo;
  bool _busy = false;
  String? _status;
  List<String> _candidates = const [];
  MtgCard? _found;

  @override
  void dispose() {
    _recognizer.close();
    super.dispose();
  }

  /// Linhas do topo da carta, onde fica o nome, já sem símbolos de mana e ruído.
  static List<String> nameCandidates(RecognizedText text) {
    final lines = text.blocks.expand((b) => b.lines).toList()
      ..sort((a, b) => a.boundingBox.top.compareTo(b.boundingBox.top));
    final result = <String>[];
    for (final line in lines) {
      final cleaned = line.text
          .replaceAll(RegExp(r"[^\p{L}\s',\-]", unicode: true), ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      if (cleaned.length >= 3 && !result.contains(cleaned)) result.add(cleaned);
      if (result.length == 4) break;
    }
    return result;
  }

  Future<void> _scan(ImageSource source) async {
    final api = context.read<CollectionStore>().api;
    final XFile? file;
    try {
      file = await _picker.pickImage(source: source, maxWidth: 1600, imageQuality: 90);
    } catch (e) {
      setState(() => _status = 'Não foi possível abrir a câmera: $e');
      return;
    }
    if (file == null) return;

    setState(() {
      _photo = File(file!.path);
      _busy = true;
      _found = null;
      _candidates = const [];
      _status = 'Lendo o texto da carta…';
    });

    try {
      final text = await _recognizer.processImage(InputImage.fromFilePath(file.path));
      final candidates = nameCandidates(text);
      setState(() {
        _candidates = candidates;
        _status = candidates.isEmpty ? 'Nenhum texto reconhecido.' : 'Procurando no Scryfall…';
      });

      MtgCard? found;
      for (final c in candidates) {
        found = await api.named(c);
        if (found != null) break;
      }
      // Cartas em outros idiomas não batem com a busca por nome em inglês.
      for (final c in candidates.take(2)) {
        if (found != null) break;
        final results = await api.search(c, multilingual: true);
        if (results.isNotEmpty) found = results.first;
      }

      setState(() {
        _found = found;
        _status = found == null ? 'Não encontrei a carta. Toque num texto abaixo para buscar manualmente.' : null;
      });
    } catch (e) {
      setState(() => _status = 'Erro: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = _found;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Escanear carta')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Fotografe a carta inteira, na vertical, com boa luz. '
            'O app lê o nome no topo da carta e procura a carta correspondente.',
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : () => _scan(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('Fotografar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : () => _scan(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Galeria'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_busy) const LinearProgressIndicator(),
          if (_status != null) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(_status!)),
          if (found != null) ...[
            Text('Encontrada:', style: theme.textTheme.labelLarge),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 140, child: CardImage(url: found.imageNormal)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(found.displayName, style: theme.textTheme.titleLarge),
                      Text(found.typeLine),
                      Text(found.setName),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: () => showAddEntrySheet(context, found, collectionId: widget.targetCollectionId),
                        child: const Text('Adicionar'),
                      ),
                      OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                CardDetailScreen(card: found, targetCollectionId: widget.targetCollectionId),
                          ),
                        ),
                        child: const Text('Escolher outra edição'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
          if (found == null && _candidates.isNotEmpty && !_busy) ...[
            for (final c in _candidates)
              ListTile(
                leading: const Icon(Icons.search),
                title: Text(c),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SearchScreen(initialQuery: c, targetCollectionId: widget.targetCollectionId),
                  ),
                ),
              ),
          ],
          if (_photo != null) ...[
            const SizedBox(height: 16),
            ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(_photo!, height: 220)),
          ],
        ],
      ),
    );
  }
}
