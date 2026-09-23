// ─────────────────────────────────────────────────────────────────────────────
//  app_logo.dart  –  Reusable Leavexa Logo Widget
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

class AppLogo extends StatelessWidget {
  final double width;

  const AppLogo({super.key, this.width = 140});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppConstants.logoPath,
      width: width,
      fit: BoxFit.contain,
    );
  }
}
