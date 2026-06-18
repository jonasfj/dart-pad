import 'package:dartpad_jaspr/src/load_example.dart';
import 'package:test/test.dart';

void main() {
  test('load_example fetches package:retry example', () async {
    final files = await loadExample(
      package: 'retry',
      path: 'example/',
    );

    // Verify it found the example files
    expect(files.keys, contains('main.dart'));

    // Verify it walked up to find pubspec.yaml
    expect(files.keys, contains('pubspec.yaml'));

    print('Fetched files:');
    for (final key in files.keys) {
      print(' - $key (${files[key]?.length} bytes)');
    }
  });

  test('load_example fetches a specific version', () async {
    final files = await loadExample(
      package: 'retry',
      version: '3.1.1',
      path: 'example/',
    );

    expect(files.keys, contains('main.dart'));
    expect(files.keys, contains('pubspec.yaml'));
  });
}
