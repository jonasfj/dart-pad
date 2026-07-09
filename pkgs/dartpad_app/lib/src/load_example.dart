import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Loads an example from pub.dev.
///
/// Fetches the tarball for [package] (and [version] if specified, or latest),
/// extracts everything within the [path] directory into a map.
/// If a `pubspec.yaml` is not found within [path], it will walk up the directories
/// to find the first `pubspec.yaml` and include it at the root of the returned map.
Future<Map<String, Uint8List>> loadExample({
  required String package,
  String? version,
  required String path,
}) async {
  final client = http.Client();
  try {
    String archiveUrl;
    if (version == null) {
      final response = await client.get(
        Uri.parse('https://pub.dev/api/packages/$package'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch package $package info');
      }
      final data = jsonDecode(response.body);
      archiveUrl = data['latest']['archive_url'];
    } else {
      final response = await client.get(
        Uri.parse('https://pub.dev/api/packages/$package'),
      );
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch package $package info');
      }
      final data = jsonDecode(response.body);
      final versions = data['versions'] as List;
      final ver = versions.firstWhere(
        (v) => v['version'] == version,
        orElse: () => throw Exception('Version not found'),
      );
      archiveUrl = ver['archive_url'];
    }

    return await loadFromArchiveUrl(archiveUrl: archiveUrl, path: path);
  } finally {
    client.close();
  }
}

/// Loads an example from a direct archive URL (e.g. from GitHub).
Future<Map<String, Uint8List>> loadFromArchiveUrl({
  required String archiveUrl,
  required String path,
}) async {
  final client = http.Client();
  try {
    final tarResponse = await client.get(Uri.parse(archiveUrl));
    if (tarResponse.statusCode != 200) {
      throw Exception('Failed to download archive');
    }

    final gzipBytes = tarResponse.bodyBytes;
    final tarBytes = GZipDecoder().decodeBytes(gzipBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    final result = <String, Uint8List>{};
    for (final file in archive) {
      if (!file.isFile) continue;
      result[file.name] = file.content;
    }

    for (final entry in result.entries.toList()) {
      if (entry.key.endsWith('pubspec.yaml')) {
        try {
          final pubspecStr = utf8.decode(entry.value);
          final editor = YamlEditor(pubspecStr);
          final yaml = loadYaml(pubspecStr);

          if (yaml is YamlMap) {
            if (yaml.containsKey('resolution') &&
                yaml['resolution'] == 'workspace') {
              editor.remove(['resolution']);
            }

            for (final depKey in ['dependencies', 'dev_dependencies']) {
              if (yaml.containsKey(depKey)) {
                final deps = yaml[depKey];
                if (deps is YamlMap) {
                  for (final depEntry in deps.entries) {
                    final pkgName = depEntry.key as String;
                    final depSpec = depEntry.value;
                    if (depSpec is YamlMap &&
                        (depSpec.containsKey('path') ||
                            depSpec.containsKey('git'))) {
                      editor.update([depKey, pkgName], 'any');
                    }
                  }
                }
              }
            }
          }
          result[entry.key] = utf8.encode(editor.toString());
        } catch (e) {
          // Fallback if parsing fails
        }
      }
    }

    return result;
  } finally {
    client.close();
  }
}
