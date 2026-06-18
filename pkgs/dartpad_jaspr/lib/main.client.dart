import 'package:jaspr/client.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';
import 'main.client.options.dart';

void main() {
  Jaspr.initializeApp(options: defaultClientOptions);
  runApp(ProviderScope(child: const ClientApp()));
}
