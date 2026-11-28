import 'package:budget/colors.dart';
import 'package:budget/database/tables.dart';
import 'package:flutter/material.dart';

/// The home dial and the transaction pickers share the same category badge.
class OneMoneyCategoryBadge extends StatelessWidget {
  const OneMoneyCategoryBadge({
    required this.category,
    this.selected = false,
    this.size = 52,
    super.key,
  });

  final TransactionCategory category;
  final bool selected;
  final double size;

  static Color colorOf(TransactionCategory category) {
    final color = category.colour;
    return color == null || color.isEmpty
        ? const Color(0xFF4CAF50)
        : HexColor(color);
  }

  @override
  Widget build(BuildContext context) {
    final tone = colorOf(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: selected ? tone : tone.withOpacity(0.14),
      ),
      padding: EdgeInsets.all(size * 12 / 52),
      child: Image.asset(
        "assets/categories/${category.iconName ?? 'cash-bill-dollar.png'}",
        color: selected ? Colors.white : tone,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.category_outlined,
            size: size / 2, color: selected ? Colors.white : tone),
      ),
    );
  }
}
