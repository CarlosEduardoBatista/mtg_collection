# Coleção MTG

App Flutter para catalogar coleções de cartas de Magic: The Gathering.
Os dados das cartas (imagens, edições e preços) vêm da API pública do [Scryfall](https://scryfall.com/docs/api).
A coleção fica salva só no celular, em SQLite.

## Recursos

- Busca de cartas com autocompletar e a sintaxe do Scryfall (`t:dragon c:r`, `s:mh3`, `lang:pt`…)
- Escolha da edição exata, inclusive impressões em outros idiomas
- Várias coleções/pastas, com quantidade, foil, estado (NM…D) e idioma
- Filtros por nome, cor, tipo, raridade e edição, e ordenação por nome, preço, CMC ou data
- Preços em US$ (ou em R$, se você informar a cotação do dólar) e valor total por coleção
- Botão para atualizar os preços de todas as cartas
- Leitura pela câmera: OCR no próprio aparelho (Google ML Kit) lê o nome e busca a carta

## Como rodar

```bash
flutter pub get
flutter run
```

Com um celular Android conectado por USB (com depuração USB ativada) ou um emulador aberto.
A leitura pela câmera precisa de um aparelho real ou de um emulador com câmera.

Na primeira vez, aceite as licenças do Android SDK com `flutter doctor --android-licenses`.

### iOS

Precisa de um Mac com Xcode. O ML Kit exige iOS 15.5 ou mais novo: depois do primeiro `flutter run`,
edite `ios/Podfile` para `platform :ios, '15.5'` e rode `cd ios && pod install`.

## Estrutura

```
lib/
  main.dart                   inicialização e tema
  models/                     MtgCard (carta) e Collection/CollectionEntry
  services/scryfall_api.dart  cliente da API (com limite de 10 req/s)
  services/app_database.dart  SQLite: coleções, cache de cartas, entradas
  state/collection_store.dart estado do app (Provider/ChangeNotifier)
  screens/                    início, coleção, busca, detalhe, edição, câmera
  widgets/                    imagem da carta, formulário de entrada, diálogos
```

## Ideias para próximas versões

- Backup/exportação da coleção (CSV compatível com Moxfield/ManaBox)
- Preços em reais de lojas brasileiras
- Leitura contínua pela câmera (sem tirar foto)
- Montagem de decks a partir da coleção
