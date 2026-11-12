// ─────────────────────────────────────────────────────────────────────────────
//  app_avatar.dart  –  Clean circular avatar with initials fallback
// ─────────────────────────────────────────────────────────────────────────────

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/helpers.dart';

class AppAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double size;
  final Color? backgroundColor;
  final Color? textColor;
  final double? fontSize;
  final BoxBorder? border;
  final BoxShape shape;
  final BorderRadius? borderRadius;

  const AppAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.size = 40,
    this.backgroundColor,
    this.textColor,
    this.fontSize,
    this.border,
    this.shape = BoxShape.circle,
    this.borderRadius,
  });

  String get _initials => AppHelpers.initials(name);

  Color _resolveBgColor(BuildContext context) {
    if (backgroundColor != null) return backgroundColor!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF0D9488) : AppColors.primary;
  }

  Widget _buildInitials(BuildContext context) {
    final bg = _resolveBgColor(context);
    final textCol = textColor ?? Colors.white;
    final fSize = fontSize ?? (size * 0.38);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        shape: shape,
        borderRadius: shape == BoxShape.rectangle
            ? (borderRadius ?? BorderRadius.circular(8))
            : null,
        border: border,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            color: textCol,
            fontWeight: FontWeight.w800,
            fontSize: fSize,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final url = photoUrl?.trim();
    if (url == null || url.isEmpty) {
      return _buildInitials(context);
    }

    final effectiveRadius = shape == BoxShape.circle
        ? BorderRadius.circular(size / 2)
        : (borderRadius ?? BorderRadius.circular(8));

    Widget imageWidget;
    if (url.startsWith('data:image/')) {
      final commaIdx = url.indexOf(',');
      Uint8List? bytes;
      if (commaIdx != -1 && commaIdx + 1 < url.length) {
        try {
          bytes = base64Decode(url.substring(commaIdx + 1));
        } catch (_) {}
      }
      if (bytes == null || bytes.isEmpty) {
        return _buildInitials(context);
      }
      imageWidget = Image.memory(
        bytes,
        width: size,
        height: size,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => _buildInitials(context),
      );
    } else {
      imageWidget = Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildInitials(context),
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return _buildInitials(context);
        },
      );
    }

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: shape,
        borderRadius: shape == BoxShape.rectangle ? effectiveRadius : null,
        border: border,
      ),
      child: ClipRRect(
        borderRadius: effectiveRadius,
        child: imageWidget,
      ),
    );
  }
}
