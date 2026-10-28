import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_colecao/widgets/dialogs.dart';

void main() {
  Future<String?> openAndClose(WidgetTester tester, {required bool confirm}) async {
    String? result = 'não respondeu';
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () async => result = await askText(context, 'Nova coleção'),
          child: const Text('abrir'),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '  Commander  ');
    await tester.tap(find.text(confirm ? 'OK' : 'Cancelar'));
    // Roda a animação de fechar até o fim: era aqui que a tela vermelha aparecia.
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    return result;
  }

  testWidgets('confirmar devolve o texto sem espaços', (tester) async {
    expect(await openAndClose(tester, confirm: true), 'Commander');
  });

  testWidgets('cancelar devolve null', (tester) async {
    expect(await openAndClose(tester, confirm: false), isNull);
  });
}
