import 'package:flutter/material.dart';
// DOGONOMICS APP THEME - Standardized Color Scheme
// Background Colors
const Color APP_BACKGROUND = Color.fromARGB(255, 0, 0, 0);           // Main dark background
const Color CARD_BACKGROUND = Color(0xFF1E1E1E);          // Card/container background
const Color CARD_BACKGROUND_ELEVATED = Color(0xFF2A2A2A); // Slightly elevated cards

// Primary Accent Colors
const Color ACCENT_GREEN = Color(0xFF2E7D32);             // Primary green
const Color ACCENT_GREEN_LIGHT = Color(0xFF66BB6A);       // Light green
const Color ACCENT_GREEN_BRIGHT = Color(0xFF4CAF50);      // Bright green

// Text Colors
const Color TEXT_PRIMARY = Colors.white;                   // Primary text
const Color TEXT_SECONDARY = Color(0xFFB0B0B0);           // Secondary text
const Color TEXT_DISABLED = Color(0xFF757575);            // Disabled text

// Status Colors
const Color COLOR_POSITIVE = Color(0xFF4CAF50);           // Positive/gain (green)
const Color COLOR_NEGATIVE = Color(0xFFF44336);           // Negative/loss (red)
const Color COLOR_WARNING = Color(0xFFFF9800);            // Warning (orange)
const Color COLOR_INFO = Color(0xFF2196F3);               // Info (blue)

// Asset Type Colors
const Color COLOR_STOCKS = Color(0xFF2196F3);             // Blue for stocks
const Color COLOR_BONDS = Color(0xFF4CAF50);              // Green for bonds
const Color COLOR_COMMODITIES = Color(0xFFFF9800);        // Orange for commodities

// Chart Colors
const Color CHART_PRIMARY = Color(0xFF2196F3);            // Primary chart line
const Color CHART_SECONDARY = Color(0xFF66BB6A);          // Secondary chart line
const Color CHART_GRID = Color(0xFF424242);               // Grid lines
const Color CHART_BACKGROUND = Color(0xFF1E1E1E);         // Chart background

// Chart Color Palette for Multiple Data Series
const List<Color> CHART_COLORS = [
  Color(0xFF2196F3),  // Blue
  Color(0xFF4CAF50),  // Green
  Color(0xFFFF9800),  // Orange
  Color(0xFF9C27B0),  // Purple
  Color(0xFFF44336),  // Red
  Color(0xFF00BCD4),  // Cyan
  Color(0xFFE91E63),  // Pink
  Color(0xFFFFC107),  // Amber
];

// Border Colors
const Color BORDER_COLOR = Color.fromARGB(255, 49, 49, 49);             // Standard border
const Color BORDER_COLOR_LIGHT = Color(0xFF616161);       // Light border
const Color DIVIDER_COLOR = Color(0xFF303030);            // Divider lines

// Button Colors
const Color BUTTON_PRIMARY = Color(0xFF4CAF50);           // Primary button
const Color BUTTON_SECONDARY = Color(0xFF424242);         // Secondary button
const Color BUTTON_DANGER = Color(0xFFF44336);            // Danger/delete button

// Legacy Support (keep for backward compatibility, will be phased out)
// ignore: non_constant_identifier_names
final MAINGREY = APP_BACKGROUND;
// ignore: non_constant_identifier_names
final STOCK_CARD = CARD_BACKGROUND;
// ignore: non_constant_identifier_names
final MAINGREY_LIGHT = TEXT_SECONDARY;
// ignore: non_constant_identifier_names
final BACKG_COLOR = APP_BACKGROUND;
// ignore: non_constant_identifier_names
final ACCENT_COLOR = ACCENT_GREEN;
// ignore: non_constant_identifier_names
final ACCENT_SHADOW = Color(0xFF1B5E20);
// ignore: non_constant_identifier_names
final ACCENT_COLOR_BRIGHT = ACCENT_GREEN_BRIGHT;

// ============================================================================
// STANDARDIZED STYLES
// ============================================================================

// Text Styles
const TextStyle HEADING_LARGE = TextStyle(
  color: TEXT_PRIMARY,
  fontSize: 24,
  fontWeight: FontWeight.bold,
);

const TextStyle HEADING_MEDIUM = TextStyle(
  color: TEXT_PRIMARY,
  fontSize: 18,
  fontWeight: FontWeight.bold,
);

const TextStyle HEADING_SMALL = TextStyle(
  color: TEXT_PRIMARY,
  fontSize: 16,
  fontWeight: FontWeight.bold,
);

const TextStyle BODY_PRIMARY = TextStyle(
  color: TEXT_PRIMARY,
  fontSize: 14,
);

const TextStyle BODY_SECONDARY = TextStyle(
  color: TEXT_SECONDARY,
  fontSize: 14,
);

const TextStyle CAPTION_TEXT = TextStyle(
  color: TEXT_SECONDARY,
  fontSize: 12,
);
BoxDecoration cardDecoration({Color? color, Color? borderColor}) {
  return BoxDecoration(
    color: color ?? CARD_BACKGROUND,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: borderColor ?? BORDER_COLOR),
  );
}

BoxDecoration cardDecorationElevated({Color? color}) {
  return BoxDecoration(
    color: color ?? CARD_BACKGROUND,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

BoxDecoration gradientCardDecoration({
  required Color startColor,
  required Color endColor,
}) {
  return BoxDecoration(
    gradient: LinearGradient(
      colors: [startColor, endColor],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.3),
        blurRadius: 10,
        offset: const Offset(0, 4),
      ),
    ],
  );
}

// ============================================================================
// UTILITY FUNCTIONS
// ============================================================================

Color getChangeColor(double change) {
  return change >= 0 ? COLOR_POSITIVE : COLOR_NEGATIVE;
}

String formatChangeText(double change) {
  return change >= 0 ? '+${change.toStringAsFixed(2)}%' : '${change.toStringAsFixed(2)}%';
}