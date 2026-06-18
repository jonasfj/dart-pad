import 'package:jaspr/dom.dart';
import 'package:jaspr/server.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';
import 'app.dart';
import 'main.server.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultServerOptions);
  runApp(
    ProviderScope(
      child: Document(
        title: 'dartpad',
        head: [
          link(href: 'https://dart.dev/assets/img/logo/dart-64.png', rel: 'icon', attributes: {'sizes': '64x64'}),
          script(src: 'asset/bundle.js', defer: true),
        ],
        styles: [
          css.import('https://fonts.googleapis.com/css?family=Roboto'),
          css('html, body').styles(
            width: 100.percent,
            minHeight: 100.vh,
            padding: .zero,
            margin: .zero,
            fontFamily: const FontFamily.list([FontFamily('Roboto'), FontFamilies.sansSerif]),
          ),
        ],
        body: App(),
      ),
    ),
  );
}
