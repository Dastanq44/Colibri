import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// A book cover thumbnail: the extracted cover image when available, otherwise
/// an all-grey placeholder box with a book glyph. 2:3 aspect by default.
class BookCover extends StatelessWidget {
  const BookCover({
    super.key,
    this.coverPath,
    this.coverUrl,
    this.width,
    this.height,
    this.borderRadius = 8,
  });

  /// Local cover file (imported books).
  final String? coverPath;

  /// Remote cover (catalog books); used when [coverPath] is null.
  final String? coverUrl;

  final double? width;
  final double? height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final path = coverPath;

    Widget placeholder() => Container(
          color: scheme.surfaceContainerHighest,
          alignment: Alignment.center,
          child: Icon(
            CupertinoIcons.book,
            size: (width ?? 56) * 0.42,
            color: scheme.onSurfaceVariant,
          ),
        );

    final url = coverUrl;
    final Widget image;
    if (path != null) {
      image = Image.file(
        File(path),
        fit: BoxFit.cover,
        // Corrupt/missing file falls back to the grey box.
        errorBuilder: (_, __, ___) => placeholder(),
      );
    } else if (url != null && url.isNotEmpty) {
      image = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder(),
      );
    } else {
      image = placeholder();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(width: width, height: height, child: image),
    );
  }
}
