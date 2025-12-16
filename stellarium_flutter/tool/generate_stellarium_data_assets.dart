import 'dart:io';

void main() {
  final repoRoot = Directory.current;

  final pubspecFile = File('${repoRoot.path}/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml not found at: ${pubspecFile.path}');
    exitCode = 2;
    return;
  }

  final dataDir = Directory('${repoRoot.path}/assets/stellarium/data');
  if (!dataDir.existsSync()) {
    stdout.writeln('No data directory found at: ${dataDir.path}');
    exitCode = 0;
    return;
  }

  const startMarker = '# BEGIN STELLARIUM DATA ASSETS';
  const endMarker = '# END STELLARIUM DATA ASSETS';

  final pubspec = pubspecFile.readAsStringSync();
  final startIndex = pubspec.indexOf(startMarker);
  final endIndex = pubspec.indexOf(endMarker);

  if (startIndex == -1 || endIndex == -1 || endIndex < startIndex) {
    stderr.writeln(
      'Markers not found or invalid in pubspec.yaml. Expected:\n'
      '    $startMarker\n'
      '    $endMarker',
    );
    exitCode = 2;
    return;
  }

  final assets = <String>[];
  for (final entity in dataDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;

    final name = entity.uri.pathSegments.isEmpty
        ? entity.path
        : entity.uri.pathSegments.last;
    if (name.isEmpty) continue;
    if (name.startsWith('.')) continue;
    if (name == '.DS_Store') continue;

    final relative = entity.path.substring(repoRoot.path.length + 1);
    assets.add(relative.replaceAll('\\', '/'));
  }

  assets.sort();

  const indent = '    ';
  final generatedLines = <String>[
    '$indent$startMarker',
    ...assets.map((p) => '$indent- $p'),
    '$indent$endMarker',
  ].join('\n');

  final before = pubspec.substring(0, startIndex).trimRight();
  // Keep the remainder of the file verbatim (do NOT trim), otherwise we can
  // break YAML indentation for the next asset entries.
  final after = pubspec.substring(endIndex + endMarker.length);
  final nextPubspec = '$before\n$generatedLines$after';

  if (nextPubspec != pubspec) {
    pubspecFile.writeAsStringSync(nextPubspec);
    stdout.writeln('Updated pubspec.yaml with ${assets.length} data assets.');
  } else {
    stdout.writeln('pubspec.yaml already up to date.');
  }
}
