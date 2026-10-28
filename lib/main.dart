import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'screens/home_screen.dart';
import 'services/app_database.dart';
import 'services/scryfall_api.dart';
import 'state/collection_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pt_BR');
  final store = CollectionStore(await AppDatabase.open(), ScryfallApi());
  await store.load();
  runApp(ChangeNotifierProvider.value(value: store, child: const MtgColecaoApp()));
}

class MtgColecaoApp extends StatelessWidget {
  const MtgColecaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    ThemeData theme(Brightness b) => ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6A3FB5), brightness: b),
          useMaterial3: true,
        );
    return MaterialApp(
      title: 'Coleção MTG',
      debugShowCheckedModeBanner: false,
      theme: theme(Brightness.light),
      darkTheme: theme(Brightness.dark),
      home: const HomeScreen(),
    );
  }
}
