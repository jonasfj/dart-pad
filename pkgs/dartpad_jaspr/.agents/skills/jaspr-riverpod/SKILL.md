---
name: jaspr-riverpod
description: Use this skill when managing state in a Jaspr application using Riverpod. Covers context extensions, top-level providers, and removing ConsumerWidgets.
---

# Jaspr Riverpod State Management

`jaspr_riverpod` is a port of Riverpod tailored specifically for Jaspr. It brings robust state management to Jaspr without the boilerplate of Flutter.

## Key Differences from Flutter Riverpod

Because Jaspr is designed from the ground up to not suffer from Flutter's `InheritedWidget` issues, `jaspr_riverpod` is much cleaner:
- **No `Consumer` or `ConsumerWidget`**: You do not need special widgets to watch providers.
- **No `WidgetRef`**: Providers are read directly from the `BuildContext`.

## How to use

### 1. ProviderScope
At the root of your application, wrap your main component in a `ProviderScope`:

```dart
import 'package:jaspr_riverpod/jaspr_riverpod.dart';

void main() {
  runApp(ProviderScope(
    child: App(),
  ));
}
```

### 2. Defining Providers
Prefer using `Provider`, `NotifierProvider`, `AsyncNotifierProvider`, and `FutureProvider`. Stay away from legacy providers like `StateNotifierProvider` and `ChangeNotifierProvider`!

Define your providers as top-level variables, just like normal Riverpod.

```dart
final itemsProvider = NotifierProvider<ItemsNotifier, List<String>>(() {
  return ItemsNotifier();
});

// Always prefer final classes unless subclassing is needed!
final class ItemsNotifier extends Notifier<List<String>> {
  @override
  List<String> build() => [];
  
  void addItem(String item) {
    state = [...state, item];
  }
}
```

### 3. Watching Providers
Use `context.watch()` inside the `build` method of **any** component (`StatelessComponent` or `StatefulComponent`). This will automatically trigger a rebuild when the provider's state changes.

```dart
final class ItemsView extends StatelessComponent {
  @override
  Iterable<Component> build(BuildContext context) sync* {
    // Watches the provider and rebuilds when it changes
    final items = context.watch(itemsProvider);
    
    yield text('Items count: ${items.length}');
    
    yield button(
      onClick: () {
        // Reads the provider to mutate it without watching for changes
        context.read(itemsProvider.notifier).addItem('New Item');
      },
      [text('Add Item')],
    );
  }
}
```

## Useful Patterns

### Context Extensions
You can create extension methods on `BuildContext` to hide the provider access and make actions easier to call from anywhere:

```dart
extension TaskContext on BuildContext {
  void addTask(String task) {
    read(itemsProvider.notifier).addItem(task);
  }
}

// Usage in a component:
// context.addTask('New Task');
```

### Scoping Rebuilds
If you have a large component but only a small part depends on a provider, you can use a `Builder` to scope the rebuilds and avoid rebuilding the entire parent:

```dart
Builder(builder: (context) sync* {
  final count = context.watch(counterProvider);
  yield text('Count: $count');
})
```

## Documentation
- Pub package: https://pub.dev/packages/jaspr_riverpod
- Core Riverpod Docs: https://riverpod.dev/
