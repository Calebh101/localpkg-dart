/// Author: Calebh101 (Copyright (C) 2026 Calebh101)
/// Version: 1.0.0A
/// Original repository: Calebh101/localpkg-dart
///
/// This file is for letting a package update itself in a Dart/Flutter project.
/// This may be copied across projects or referenced by imports.
library;

import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Defines what's going to be updated with this updater script.
class Project {
  /// localpkg (Calebh101/localpkg-dart)
  static const localpkgDart = Project(package: "localpkg", repo: "Calebh101/localpkg-dart", isFlutter: false);

  /// localpkg_flutter (Calebh101/localpkg-flutter-2)
  static const localpkgFlutter = Project(package: "localpkg_flutter", repo: "Calebh101/localpkg-flutter-2", isFlutter: true);

  /// The package name of the project.
  final String package;

  /// The repository of the project.
  /// This must be a GitHub repository.
  ///
  /// Example:
  ///
  /// ```txt
  /// Calebh101/localpkg-dart
  /// ```
  final String repo;

  /// If the package is a Flutter package.
  final bool isFlutter;

  /// Defines what's going to be updated with this updater script.
  const Project({required this.package, required this.repo, required this.isFlutter});
}

void _debug(Object? input) {
  // ignore: avoid_print
  print("Updater: $input");
}

/// Update the specified project.
void update(Project project, {List<String> arguments = const []}) async {
  _debug("Starting update script...");
  final package = project.package;
  final repo = project.repo;

  ArgParser parser = ArgParser()
    ..addOption("directory", abbr: "d", help: "Working directory of the Dart/Flutter project.", defaultsTo: Directory.current.path)
    ..addOption("commit", abbr: "c", help: "Commit to use for $package.")
    ..addFlag("help", abbr: "h", help: "Show help message.");

  String usage = "Usage:\n\n${parser.usage}";
  ArgResults args = parser.parse(arguments);
  Directory directory = Directory(args["directory"]);
  File pubspec = File(p.joinAll([directory.path, "pubspec.yaml"]));

  if (args["help"]) {
    _debug(usage);
    exit(0);
  }

  if (await directory.exists().willEqual(false)) {
    _debug("Directory ${directory.path} does not exist.");
    exit(1);
  }

  if (await pubspec.exists().willEqual(false)) {
    _debug("File ${pubspec.path} does not exist.");
    exit(1);
  }

  YamlEditor editor = YamlEditor(await pubspec.readAsString());
  var loaded = editor.parseAt([]);
  var data = yamlToMap(loaded);
  Map<String, dynamic>? found = data["dependencies"]?[package];

  String? initialCommitSetting = found?["git"]?["ref"];
  if (initialCommitSetting == "main") initialCommitSetting = null;

  _debug("Fetching latest commit...");
  http.Response response = await http.get(Uri.parse("https://api.github.com/repos/$repo/commits/${args["commit"] ?? "main"}"));

  if (response.statusCode < 200 || response.statusCode >= 300) {
    _debug("Received bad request for API call: code ${response.statusCode}.");
    _debug(response.body);
    exit(-1);
  }

  Map body = jsonDecode(response.body);
  String sha = body["sha"];
  String message = body["commit"]?["message"] ?? "Unknown";
  _debug("Found commit ID of $sha: $message");

  if (sha == initialCommitSetting) {
    _debug("Package $package is up to date.");
    exit(0);
  }

  _debug("Updating data...");
  editor.update(["dependencies", package], {"git": {"url": "https://github.com/$repo.git", "ref": sha}});

  await pubspec.writeAsString(editor.toString());
  await resetGitCache(repo, sha);

  _debug("Updating packages...");
  var process = await Process.start(project.isFlutter ? "flutter" : "dart", ["pub", "get"], runInShell: true, workingDirectory: directory.path);
  process.stdout.transform(utf8.decoder).listen(stdout.write);
  process.stderr.transform(utf8.decoder).listen(stderr.write);
  int exitCode = await process.exitCode;

  if (exitCode != 0) {
    _debug("Process failed with code $exitCode.");
    exit(-1);
  } {
    _debug("Job done! Updated $package ($repo) to commit $sha ($message) from commit $initialCommitSetting.");
    exit(0);
  }
}

/// Turns YAML into an object.
dynamic yamlToMap(dynamic yaml) {
  if (yaml is YamlMap) {
    return Map<String, dynamic>.fromEntries(
      yaml.entries.map((e) => MapEntry(e.key, yamlToMap(e.value))),
    );
  } else if (yaml is YamlList) {
    return yaml.map((e) => yamlToMap(e)).toList();
  } else {
    return yaml;
  }
}

/// Reset the Git cache of a repository.
Future<void> resetGitCache(String repo, String sha) async {
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
  if (home == null) return;

  final cacheDir = Directory(p.join(home, ".pub-cache", "git", "cache"));
  if (!await cacheDir.exists()) return;
  var files = cacheDir.listSync();
  Directory? cached;

  for (var file in files) {
    if (file is Directory && file.path.contains(repo)) {
      cached = file;
      break;
    }
  }

  if (cached == null) return;
  final dir = Directory(cached.path);
  await dir.delete(recursive: true);
}

/// Some nice addons to [Future]s.
///
/// Originally from 'localpkg/functions.dart'.
extension FutureAddons<T> on Future<T> {
  /// Returns a `Future<bool>` that represents if the future will equal the inputted [value] when it completes.
  Future<bool> willEqual(T value) async {
    return (await this) == value;
  }
}