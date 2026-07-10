import 'package:flutter/material.dart';

import 'vivy_colors.dart';

class VivyTextStyles {
  static const TextStyle screenTitle = TextStyle(
    fontSize: 30,
    fontWeight: FontWeight.w700,
    color: VivyColors.textPrimary,
    height: 1.15,
  );

  static const TextStyle body = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w500,
    color: VivyColors.textSecondary,
    height: 1.35,
  );

  static const TextStyle cardTitle = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w700,
    color: VivyColors.textPrimary,
  );

  static const TextStyle cardSubtitle = TextStyle(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: VivyColors.textSecondary,
    letterSpacing: 0.2,
  );

  static const TextStyle primaryButton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: Colors.white,
  );

  static const TextStyle secondaryButton = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: VivyColors.primaryBlue,
  );
}
