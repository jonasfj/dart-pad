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
      final response = await client.get(Uri.parse('https://pub.dev/api/packages/$package'));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch package $package info');
      }
      final data = jsonDecode(response.body);
      archiveUrl = data['latest']['archive_url'];
    } else {
      final response = await client.get(Uri.parse('https://pub.dev/api/packages/$package'));
      if (response.statusCode != 200) {
        throw Exception('Failed to fetch package $package info');
      }
      final data = jsonDecode(response.body);
      final versions = data['versions'] as List;
      final ver = versions.firstWhere((v) => v['version'] == version, orElse: () => throw Exception('Version not found'));
      archiveUrl = ver['archive_url'];
    }

    final tarResponse = await client.get(Uri.parse(archiveUrl));
    if (tarResponse.statusCode != 200) {
      throw Exception('Failed to download archive');
    }

    final gzipBytes = tarResponse.bodyBytes;
    final tarBytes = GZipDecoder().decodeBytes(gzipBytes);
    final archive = TarDecoder().decodeBytes(tarBytes);

    final result = <String, Uint8List>{};
    String? foundPubspecPath;
    Uint8List? foundPubspecData;

    // Normalize path to remove leading slash and ensure trailing slash
    String targetPrefix = path;
    if (targetPrefix.startsWith('/')) {
      targetPrefix = targetPrefix.substring(1);
    }
    if (targetPrefix.isNotEmpty && !targetPrefix.endsWith('/')) {
      targetPrefix += '/';
    }

    for (final file in archive) {
      if (!file.isFile) continue;

      final filename = file.name;
      
      // If the file is within our target directory
      if (filename.startsWith(targetPrefix)) {
        final relativePath = filename.substring(targetPrefix.length);
        result[relativePath] = file.content;
        
        if (relativePath == 'pubspec.yaml') {
          foundPubspecPath = filename;
        }
      } 
      // Keep track of pubspec.yamls higher up in the directory tree
      else if (filename.endsWith('pubspec.yaml')) {
        // Only consider it if it's a parent of our target directory
        if (targetPrefix.startsWith(filename.replaceAll('pubspec.yaml', ''))) {
          // If we haven't found a closer pubspec yet (one with a longer path)
          if (foundPubspecPath == null || filename.length > foundPubspecPath.length) {
            foundPubspecPath = filename;
            foundPubspecData = file.content;
          }
        }
      }
    }

    // If we didn't find a pubspec inside the target path, but found one higher up
    if (!result.containsKey('pubspec.yaml') && foundPubspecData != null) {
      try {
        final pubspecStr = utf8.decode(foundPubspecData);
        final editor = YamlEditor(pubspecStr);
        final yaml = loadYaml(pubspecStr);
        
        if (yaml is YamlMap) {
          // Strip resolution: workspace
          if (yaml.containsKey('resolution') && yaml['resolution'] == 'workspace') {
            editor.remove(['resolution']);
          }
          
          // Strip path/git dependencies
          for (final depKey in ['dependencies', 'dev_dependencies']) {
            if (yaml.containsKey(depKey)) {
              final deps = yaml[depKey];
              if (deps is YamlMap) {
                for (final entry in deps.entries) {
                  final pkgName = entry.key as String;
                  final depSpec = entry.value;
                  if (depSpec is YamlMap && (depSpec.containsKey('path') || depSpec.containsKey('git'))) {
                    // Replace the local/git constraint with 'any'
                    editor.update([depKey, pkgName], 'any');
                  }
                }
              }
            }
          }
        }
        
        result['pubspec.yaml'] = utf8.encode(editor.toString());
      } catch (e) {
        // Fallback if parsing fails
        result['pubspec.yaml'] = foundPubspecData;
      }
    }

    return result;
  } finally {
    client.close();
  }
}
