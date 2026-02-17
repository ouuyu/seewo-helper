import 'dart:io';

void main(List<String> args) {
  final options = _parseArgs(args);
  final type = options['type'] ?? 'patch';
  final printOnly = options.containsKey('print-only');

  if (!['major', 'minor', 'patch'].contains(type)) {
    stderr.writeln('Invalid --type. Use: major | minor | patch');
    exit(2);
  }

  final pubspecFile = File('pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml not found');
    exit(2);
  }

  final pubspecContent = pubspecFile.readAsStringSync();
  final versionPattern = RegExp(r'^version:\s*(\d+)\.(\d+)\.(\d+)\+(\d+)\s*$', multiLine: true);
  final match = versionPattern.firstMatch(pubspecContent);

  if (match == null) {
    stderr.writeln('Cannot parse version from pubspec.yaml');
    exit(2);
  }

  var major = int.parse(match.group(1)!);
  var minor = int.parse(match.group(2)!);
  var patch = int.parse(match.group(3)!);
  var build = int.parse(match.group(4)!);

  if (!printOnly) {
    switch (type) {
      case 'major':
        major += 1;
        minor = 0;
        patch = 0;
        break;
      case 'minor':
        minor += 1;
        patch = 0;
        break;
      case 'patch':
        patch += 1;
        break;
    }
    build += 1;
  }

  final newVersion = '$major.$minor.$patch';
  final newBuildVersion = '$newVersion+$build';

  if (printOnly) {
    stdout.writeln(newVersion);
    return;
  }

  final updatedPubspec = pubspecContent.replaceFirst(
    versionPattern,
    'version: $newBuildVersion',
  );
  pubspecFile.writeAsStringSync(updatedPubspec);

  _updateChangelog(newVersion);
  stdout.writeln('Bumped to $newBuildVersion');
}

Map<String, String> _parseArgs(List<String> args) {
  final options = <String, String>{};

  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) {
      continue;
    }

    final key = arg.substring(2);
    if (key == 'print-only') {
      options[key] = 'true';
      continue;
    }

    if (i + 1 < args.length && !args[i + 1].startsWith('--')) {
      options[key] = args[i + 1];
      i += 1;
    } else {
      options[key] = 'true';
    }
  }

  return options;
}

void _updateChangelog(String version) {
  final changelogFile = File('CHANGELOG.md');
  final date = DateTime.now().toIso8601String().split('T').first;
  final section = '## [$version] - $date\n- chore: release $version\n\n';

  if (!changelogFile.existsSync()) {
    changelogFile.writeAsStringSync('# Changelog\n\n$section');
    return;
  }

  final content = changelogFile.readAsStringSync();
  if (content.contains('## [$version]')) {
    return;
  }

  if (content.startsWith('# Changelog')) {
    final updated = content.replaceFirst('# Changelog\n\n', '# Changelog\n\n$section');
    changelogFile.writeAsStringSync(updated);
    return;
  }

  changelogFile.writeAsStringSync('# Changelog\n\n$section$content');
}
