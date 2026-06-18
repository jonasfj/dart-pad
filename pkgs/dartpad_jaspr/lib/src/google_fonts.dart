import 'package:jaspr/dom.dart';
// ignore: implementation_imports
import 'package:jaspr/src/dom/styles/css.dart' show CssUtility;

typedef GoogleFont = ({String family, List<int>? weights});

enum FontDisplay {
  auto, block, swap, fallback, optional
}

enum MaterialIconStyle {
  regular('Material Icons'),
  outlined('Material Icons Outlined'),
  round('Material Icons Round'),
  sharp('Material Icons Sharp'),
  twoTone('Material Icons Two Tone');

  final String name;
  const MaterialIconStyle(this.name);
}

enum MaterialSymbolStyle {
  outlined('Material Symbols Outlined'),
  rounded('Material Symbols Rounded'),
  sharp('Material Symbols Sharp');

  final String name;
  const MaterialSymbolStyle(this.name);
}

extension GoogleFontCssUtility on CssUtility {
  StyleRule importGoogleFont({
    required List<GoogleFont> fonts,
    FontDisplay display = FontDisplay.swap,
  }) {
    final families = fonts.map((f) {
      final name = f.family.replaceAll(' ', '+');
      if (f.weights != null && f.weights!.isNotEmpty) {
        return '$name:wght@${f.weights!.join(';')}';
      }
      return name;
    }).join('&family=');
    return import('https://fonts.googleapis.com/css2?family=$families&display=${display.name}');
  }

  StyleRule importMaterialIcons({
    List<MaterialIconStyle> styles = const [MaterialIconStyle.regular],
  }) {
    final families = styles.map((style) => style.name.replaceAll(' ', '+')).join('|');
    return import('https://fonts.googleapis.com/icon?family=$families');
  }

  StyleRule importMaterialSymbols({
    List<MaterialSymbolStyle> styles = const [MaterialSymbolStyle.outlined],
    bool fullAxes = false,
  }) {
    final axes = fullAxes ? ':opsz,wght,FILL,GRAD@20..48,100..700,0..1,-50..200' : '';
    final families = styles.map((style) => '${style.name.replaceAll(' ', '+')}$axes').join('&family=');
    return import('https://fonts.googleapis.com/css2?family=$families');
  }
}
