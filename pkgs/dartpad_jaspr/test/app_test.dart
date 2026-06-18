import 'package:jaspr_test/jaspr_test.dart';
import 'package:dartpad_jaspr/app.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';
import 'package:dartpad_jaspr/components/app_header.dart';
import 'package:dartpad_jaspr/components/editor.dart';

void main() {
  group('DartPadJasprApp tests', () {
    testComponents('renders app structure correctly', (tester) async {
      tester.pumpComponent(
        ProviderScope(
          child: App(),
        ),
      );

      // Verify that AppHeader and Editor are rendered
      expect(find.byType(AppHeader), findsOneComponent);
      expect(find.byType(Editor), findsOneComponent);
    });

    testComponents('AppHeader run button triggers onRun', (tester) async {
      var runClicked = false;
      
      tester.pumpComponent(
        AppHeader(
          isBusy: false,
          onRun: () {
            runClicked = true;
          },
        ),
      );

      // Verify the button renders
      expect(find.tag('button'), findsOneComponent);
      
      // Simulate click
      await tester.click(find.tag('button'));
      
      // Verify callback triggered
      expect(runClicked, isTrue);
    });
  });
}
