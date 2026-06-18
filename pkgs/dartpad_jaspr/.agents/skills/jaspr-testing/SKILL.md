---
name: jaspr-testing
description: Write component tests and integration tests for Jaspr applications using the jaspr_test package. Use this skill when the user asks to test Jaspr components or when you need to verify functionality.
metadata:
  jaspr_version: 0.23.1
---

## Setup

First, ensure `jaspr_test` is added as a dev dependency in `pubspec.yaml`:
```shell
dart pub add jaspr_test --dev
```

## Component Testing API

To write tests for Jaspr components, you should use the `testComponents` function exported by `jaspr_test/jaspr_test.dart`.

### 1. Basic Example

A typical component test looks like this:

```dart
import 'package:jaspr_test/jaspr_test.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart'; // if needed
import 'package:my_app/components/my_component.dart';

void main() {
  group('MyComponent tests', () {
    
    // Use testComponents instead of test() or testWidgets()
    testComponents('renders my component correctly', (tester) async {
      // 1. Pump the component into the tester
      tester.pumpComponent(
        ProviderScope( // wrap in ProviderScope if testing riverpod state
          child: MyComponent(),
        ),
      );

      // 2. Verify rendering output using finders
      expect(find.byType(MyComponent), findsOneComponent);
      expect(find.text('Expected Text'), findsOneComponent);
      expect(find.tag('button'), findsOneComponent);
      
      // 3. Simulate events
      await tester.click(find.tag('button'));
      
      // 4. Verify updated state
      expect(find.text('Updated Text'), findsOneComponent);
    });
  });
}
```

### 2. Available Finders

Jaspr provides the `find` object (similar to `flutter_test`) to locate elements in the component tree:
- `find.byType(MyComponent)`: Finds a specific Component class.
- `find.tag('div')`: Finds a standard HTML element by its tag.
- `find.text('Hello')`: Finds a text node.
- `find.id('my-id')`: Finds an element by its HTML `id` attribute.
- `find.classes('btn-primary')`: Finds an element by its CSS classes.

### 3. Simulating Events

Use the `tester` instance to simulate user interactions:
- `await tester.click(Finder)`: Simulates a click on the element located by the finder.
- `await tester.input(Finder, value: 'Hello')`: Simulates typing 'Hello' into a text input or textarea.
- `await tester.change(Finder, checked: true)`: Simulates a change event on a checkbox input.
- `tester.dispatchEvent(Finder, 'custom-event')`: Dispatches a custom DOM event.

Always `await` interaction methods like `click`, `input`, and `change` as they automatically pump the event queue and allow the UI to update. Do **not** await `tester.pumpComponent()`.

## Testers

Jaspr has 3 tester classes to choose from, though `testComponents` handles most UI test cases:
1. **ComponentTester** (`jaspr_test/jaspr_test.dart`): Unit-test components in a simulated Dart testing environment. Use via the `testComponents` API as shown above.
2. **BrowserTester** (`jaspr_test/browser_test.dart`): Test components and DOM-interactions in a headless browser environment. Use via `testBrowser()`.
3. **ServerTester** (`jaspr_test/server_test.dart`): Test the rendering of components in a simulated server environment.

For standard integration tests or component UI tests, `testComponents` is recommended.
