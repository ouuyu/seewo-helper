import 'dart:io';

void main(List<String> args) {
  final options = _parseArgs(args);
  final type = options['type'] ?? 'patch';
  final printOnly = options.containsKey('print-only') || options.containsKey('print-current');
  final nextOnly = options.containsKey('next-only');
  final release = options.containsKey('release');
  final remote = options['remote'] ?? 'origin';

  if (!['major', 'minor', 'patch'].contains(type)) {
    stderr.writeln('Invalid --type. Use: major | minor | patch');
    exit(2);
  }

  if (printOnly && nextOnly) {
    stderr.writeln('Cannot use --print-only/--print-current with --next-only');
    exit(2);
  }

  if ((printOnly || nextOnly) && release) {
    stderr.writeln('--release cannot be used with print-only modes');
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

  final currentVersion = '$major.$minor.$patch';

  if (printOnly) {
    stdout.writeln(currentVersion);
    return;
  }

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

  final newVersion = '$major.$minor.$patch';
  final newBuildVersion = '$newVersion+$build';

  if (nextOnly) {
    stdout.writeln(newVersion);
    return;
  }

  final updatedPubspec = pubspecContent.replaceFirst(
    versionPattern,
    'version: $newBuildVersion',
  );
  pubspecFile.writeAsStringSync(updatedPubspec);

  _updateChangelog(newVersion);

  if (release) {
    _runGit(['add', 'pubspec.yaml', 'CHANGELOG.md']);
    _runGit(['commit', '-m', 'chore(release): bump version to $newVersion']);
    _runGit(['tag', 'v$newVersion']);
    _runGit(['push', remote]);
    _runGit(['push', remote, 'v$newVersion']);
  }

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

void _runGit(List<String> args) {
  final result = Process.runSync('git', args, runInShell: true);
  if (result.exitCode != 0) {
    stderr.writeln('git ${args.join(' ')} failed');
    if (result.stdout != null && result.stdout.toString().trim().isNotEmpty) {
      stderr.writeln(result.stdout);
    }
    if (result.stderr != null && result.stderr.toString().trim().isNotEmpty) {
      stderr.writeln(result.stderr);
    }
    exit(result.exitCode);
  }
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
