/// Keyboard design system: consistent tokens for backgrounds, keys,
/// text, icons, pressed and active states. Light + Dark variants.
library;

import 'package:flutter/material.dart';

class KbTheme {
  final Color background;
  final Color keyBg;
  final Color keyBgSpecial;
  final Color keyBgPressed;
  final Color keyText;
  final Color keyTextSecondary;
  final Color icon;
  final Color accent;
  final Color accentText;
  final Color stripBg;
  final Color suggestionText;
  final Color border;
  final Color panelBg;

  const KbTheme({
    required this.background,
    required this.keyBg,
    required this.keyBgSpecial,
    required this.keyBgPressed,
    required this.keyText,
    required this.keyTextSecondary,
    required this.icon,
    required this.accent,
    required this.accentText,
    required this.stripBg,
    required this.suggestionText,
    required this.border,
    required this.panelBg,
  });

  static const light = KbTheme(
    background: Color(0xFFE8EAED),
    keyBg: Color(0xFFFFFFFF),
    keyBgSpecial: Color(0xFFCDD1D6),
    keyBgPressed: Color(0xFFB8BCC2),
    keyText: Color(0xFF1F2328),
    keyTextSecondary: Color(0xFF5F6368),
    icon: Color(0xFF444A50),
    accent: Color(0xFF1A73E8),
    accentText: Color(0xFFFFFFFF),
    stripBg: Color(0xFFF1F3F4),
    suggestionText: Color(0xFF1F2328),
    border: Color(0xFFD0D3D8),
    panelBg: Color(0xFFF7F8FA),
  );

  static const dark = KbTheme(
    background: Color(0xFF1B1C1F),
    keyBg: Color(0xFF34363B),
    keyBgSpecial: Color(0xFF26282C),
    keyBgPressed: Color(0xFF4A4D53),
    keyText: Color(0xFFEDEFF2),
    keyTextSecondary: Color(0xFFAEB4BB),
    icon: Color(0xFFC7CCD2),
    accent: Color(0xFF8AB4F8),
    accentText: Color(0xFF17233A),
    stripBg: Color(0xFF232529),
    suggestionText: Color(0xFFEDEFF2),
    border: Color(0xFF3C3F45),
    panelBg: Color(0xFF202226),
  );

  static KbTheme of(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? dark : light;
  }
}
