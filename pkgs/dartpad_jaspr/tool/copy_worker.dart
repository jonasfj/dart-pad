import 'dart:io';
import 'dart:isolate';

void main() async {
  final packageUri = Uri.parse('package:dartpad/');
  final resolvedUri = await Isolate.resolvePackageUri(packageUri);
  if (resolvedUri == null) {
    print('Failed to resolve package:dartpad');
    exit(1);
  }
  
  // resolvedUri points to lib/ directory of the dartpad package.
  // We want to access the web/ directory.
  final webDir = Directory.fromUri(resolvedUri.resolve('../web'));
  
  if (!webDir.existsSync()) {
    print('web/ directory not found in dartpad package at ${webDir.path}');
    exit(1);
  }
  
  final destDir = Directory('web/asset/worker/');
  if (destDir.existsSync()) {
    destDir.deleteSync(recursive: true);
  }
  destDir.createSync(recursive: true);
  
  print('Copying worker assets from ${webDir.path} to ${destDir.path}');
  
  // copy contents
  for (final entity in webDir.listSync(recursive: true)) {
    final relative = entity.path.substring(webDir.path.length + 1);
    final targetPath = '${destDir.path}/$relative';
    if (entity is Directory) {
      Directory(targetPath).createSync(recursive: true);
    } else if (entity is File) {
      entity.copySync(targetPath);
    }
  }
  print('Done.');
}
