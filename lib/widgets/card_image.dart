import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagem da carta com cantos arredondados e proporção oficial (63 x 88 mm).
class CardImage extends StatelessWidget {
  const CardImage({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: const Icon(Icons.style_outlined),
    );
    return AspectRatio(
      aspectRatio: 63 / 88,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: url == null
            ? placeholder
            : CachedNetworkImage(
                imageUrl: url!,
                fit: BoxFit.cover,
                placeholder: (_, _) => placeholder,
                errorWidget: (_, _, _) => placeholder,
              ),
      ),
    );
  }
}
