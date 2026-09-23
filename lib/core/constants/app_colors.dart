// ─────────────────────────────────────────────────────────────────────────────
//  app_colors.dart  –  Leavexa Brand Color Palette
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // ── Brand ──────────────────────────────────────────────────────────────────
  static const Color primary       = Color(0xFF1B4332); // Deep forest green
  static const Color primaryLight  = Color(0xFF2D6A4F);
  static const Color primaryDark   = Color(0xFF081C15);
  static const Color accent        = Color(0xFFD8F3DC); // Pale mint green

  // ── Background / Surface ───────────────────────────────────────────────────
  static const Color background    = Color(0xFFFFFFFF);
  static const Color surface       = Color(0xFFF8FAFB);
  static const Color surfaceAlt    = Color(0xFFF1F5F9);
  static const Color card          = Color(0xFFFFFFFF);

  // ── Text ───────────────────────────────────────────────────────────────────
  static const Color textPrimary   = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF475569);
  static const Color textHint      = Color(0xFF94A3B8);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // ── Status ─────────────────────────────────────────────────────────────────
  static const Color pending       = Color(0xFFF59E0B);
  static const Color pendingBg     = Color(0xFFFEF3C7);
  static const Color approved      = Color(0xFF16A34A);
  static const Color approvedBg    = Color(0xFFDCFCE7);
  static const Color rejected      = Color(0xFFDC2626);
  static const Color rejectedBg    = Color(0xFFFEE2E2);
  static const Color forwarded     = Color(0xFF2563EB);
  static const Color forwardedBg   = Color(0xFFDBEAFE);

  // ── Border / Divider ───────────────────────────────────────────────────────
  static const Color border        = Color(0xFFE2E8F0);
  static const Color divider       = Color(0xFFF1F5F9);

  // ── Shadow ─────────────────────────────────────────────────────────────────
  static const Color shadow        = Color(0x0D000000);
  static const Color shadowMedium  = Color(0x1A000000);
}
