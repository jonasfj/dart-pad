import 'package:jaspr/dom.dart';
import '../src/google_fonts.dart';

abstract class Theme {
  /// The main brand color (Dart Blue). Use this for prominent logos, headers, or hero elements.
  static const Color primary = Color('#0175C2');

  /// Accent color for primary actions (VS Code Blue).
  static const Color accent = Color('#0e639c');

  /// Accent hover color for primary actions.
  static const Color accentHover = Color('#1177bb');

  static const Color primaryHover = Color('#2b6eb5');
  static const Color overlay = Color('#00000088');

  /// Selection color for active elements.
  static const Color selection = Color('#264f78');

  /// The deepest background color. Use for the main editor or console backgrounds.
  static const Color background = Color('#1e1e1e');

  /// The top app header background.
  static const Color header = Color('#333333');

  /// A slightly lighter background. Use for sidebars, panels, and floating elements.
  static const Color surface = Color('#252526');

  /// Highlight color for interactive surface elements when hovered.
  static const Color surfaceHover = Color('#2a2d2e');

  /// Highlight color for selected/active items within a surface (e.g., active file in tree).
  static const Color surfaceActive = Color('#37373d');

  /// Separator color for defining boundaries between panes, surfaces, and elements.
  static const Color border = Color('#3e3e42');

  /// Standard readable text color for general UI elements.
  static const Color textPrimary = Color('#cccccc');

  /// De-emphasized text color for secondary information, muted labels, or disabled states.
  static const Color textSecondary = Color('#858585');

  // --- Console Specific Colors ---
  static const Color error = Color('#f48771');
  static const Color system = Color('#4ec9b0');
}

// Defines the global CSS styles for this project.
//
// By using the @css annotation, these will be rendered automatically to CSS and included in your page.

@css
List<StyleRule> get styles => [
  // Special import rule to include to another css file.
  css.importGoogleFont(
    fonts: [
      (family: 'Google Sans Text', weights: [400, 500, 700]),
      (family: 'Google Sans Mono', weights: [400, 500, 700]),
    ],
    display: FontDisplay.swap,
  ),
  css.importMaterialSymbols(),
  // Each style rule takes a valid css selector and a set of styles.
  // Styles are defined using type-safe css bindings and can be freely chained and nested.
  css('html, body').styles(
    width: 100.percent,
    minHeight: 100.vh,
    padding: .zero,
    margin: .zero,
    color: Theme.textPrimary,
    fontFamily: const FontFamily.list([
      FontFamily('Google Sans Text'),
      FontFamily('ui-sans-serif'),
      FontFamilies.sansSerif,
    ]),
    backgroundColor: Theme.background,
    raw: {
      'color-scheme': 'dark',
      'scrollbar-color': '#424242 transparent',
      'scrollbar-width': 'thin',
    },
  ),
  css('.material-symbols-outlined').styles(
    raw: {
      'user-select': 'none',
      'flex-shrink': '0',
    },
  ),
  css('h1').styles(
    margin: .unset,
    fontSize: 4.rem,
  ),
];
