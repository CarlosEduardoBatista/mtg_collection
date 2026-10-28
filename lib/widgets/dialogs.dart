import 'package:flutter/material.dart';

Future<String?> askText(BuildContext context, String title, {String initial = '', String label = 'Nome'}) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TextDialog(title: title, initial: initial, label: label),
    );

/// O diálogo é dono do controller, que só é descartado depois da animação de
/// fechar terminar (descartar antes disso gera a tela vermelha de erro).
class _TextDialog extends StatefulWidget {
  const _TextDialog({required this.title, required this.initial, required this.label});

  final String title;
  final String initial;
  final String label;

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: widget.label),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text.trim()), child: const Text('OK')),
      ],
    );
  }
}

Future<bool> confirm(BuildContext context, String title, String message) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirmar')),
      ],
    ),
  );
  return ok ?? false;
}

void showMessage(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
