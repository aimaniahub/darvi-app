import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/app_entities.dart';

class ProductTile extends StatelessWidget {
  const ProductTile({
    super.key,
    required this.product,
    required this.currency,
    required this.onTap,
    this.cartQty = 0,
    this.onIncrease,
    this.onDecrease,
  });

  final ProductView product;
  final String currency;
  final VoidCallback onTap;
  final int cartQty;
  final VoidCallback? onIncrease;
  final VoidCallback? onDecrease;

  @override
  Widget build(BuildContext context) {
    final lowStock = product.isLowStock;
    final outOfStock = product.stockQty <= 0;

    return InkWell(
      borderRadius: AppRadii.md,
      onTap: onTap,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.md,
          side: BorderSide(
            color: cartQty > 0 ? const Color(0xFF135D44).withValues(alpha: 0.5) : Colors.grey.shade200,
            width: cartQty > 0 ? 1.5 : 1.0,
          ),
        ),
        elevation: cartQty > 0 ? 2 : 0,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            children: [
              ProductImageWidget(imagePath: product.imagePath, size: 52),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${product.sku} • ${product.categoryName ?? '-'}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey.shade600,
                            fontSize: 11,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppFormatters.money(product.price, currency: currency),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: Color(0xFF135D44),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stock pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: outOfStock
                          ? Colors.red.shade100
                          : (lowStock ? Colors.orange.shade100 : Colors.green.shade100),
                      borderRadius: AppRadii.sm,
                    ),
                    child: Text(
                      '${product.stockQty}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: outOfStock
                            ? Colors.red.shade900
                            : (lowStock ? Colors.orange.shade900 : Colors.green.shade900),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Zomato-style math stepper: [- 2 +] or ADD button
                  if (cartQty > 0)
                    Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFF135D44),
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF135D44).withValues(alpha: 0.25),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          InkWell(
                            onTap: onDecrease,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(6)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Icon(Icons.remove, size: 16, color: Colors.white),
                            ),
                          ),
                          Container(
                            constraints: const BoxConstraints(minWidth: 20),
                            alignment: Alignment.center,
                            child: Text(
                              '$cartQty',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: onIncrease,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(6)),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              child: Icon(Icons.add, size: 16, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    InkWell(
                      onTap: onIncrease ?? onTap,
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF135D44), width: 1.2),
                        ),
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ADD',
                              style: TextStyle(
                                color: Color(0xFF135D44),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            SizedBox(width: 2),
                            Icon(Icons.add, size: 14, color: Color(0xFF135D44)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Reusable image widget that supports both network URLs and local file paths.
class ProductImageWidget extends StatelessWidget {
  const ProductImageWidget({
    super.key,
    this.imagePath,
    this.size = 56,
  });

  final String? imagePath;
  final double size;

  bool get _isNetworkUrl =>
      imagePath != null &&
      (imagePath!.startsWith('http://') || imagePath!.startsWith('https://'));

  bool get _isLocalFile =>
      imagePath != null &&
      !_isNetworkUrl &&
      imagePath!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (_isNetworkUrl) {
      return ClipRRect(
        borderRadius: AppRadii.md,
        child: Image.network(
          imagePath!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _PlaceholderBox(
              size: size,
              colorScheme: colorScheme,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: progress.expectedTotalBytes != null
                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                    : null,
              ),
            );
          },
          errorBuilder: (context, error, _) =>
              _PlaceholderBox(size: size, colorScheme: colorScheme),
        ),
      );
    }

    if (_isLocalFile) {
      return ClipRRect(
        borderRadius: AppRadii.md,
        child: Image.file(
          File(imagePath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, _) =>
              _PlaceholderBox(size: size, colorScheme: colorScheme),
        ),
      );
    }

    return _PlaceholderBox(size: size, colorScheme: colorScheme);
  }
}

class _PlaceholderBox extends StatelessWidget {
  const _PlaceholderBox({
    required this.colorScheme,
    required this.size,
    this.child,
  });

  final ColorScheme colorScheme;
  final double size;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer,
        borderRadius: AppRadii.md,
      ),
      child: child ??
          Icon(
            Icons.inventory_2_outlined,
            color: colorScheme.onPrimaryContainer,
            size: size * 0.5,
          ),
    );
  }
}
