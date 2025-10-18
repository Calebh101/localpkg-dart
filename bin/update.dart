import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

const String repo = "localpkg-dart";
const String package = "localpkg";

void _debug(Object? input) {
  // ignore: avoid_print
  print("Updater: $input");
}

void main(List<String> arguments) async {
  _debug("Starting update script...");

  ArgParser parser = ArgParser()
    ..addOption("directory", abbr: "d", help: "Working directory of Flutter project.", defaultsTo: Directory.current.path)
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
  Map<String, dynamic>? localpkg = data["dependencies"]?[package];

  if (localpkg == null) {
    _debug("Data for $package does not exist.");
    exit(1);
  }

  String? initialCommitSetting = localpkg["git"]?["ref"];
  if (initialCommitSetting == "main") initialCommitSetting = null;

  _debug("Fetching latest commit...");
  http.Response response = await http.get(Uri.parse("https://api.github.com/repos/Calebh101/$repo/commits/${args["commit"] ?? "main"}"));

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
  editor.update(["dependencies", package, "git", "ref"], sha);
  await pubspec.writeAsString(editor.toString());
  await resetGitCache(sha);

  _debug("Updating packages...");
  var process = await Process.start("flutter", ["pub", "get"], runInShell: true, workingDirectory: directory.path);
  process.stdout.transform(utf8.decoder).listen(stdout.write);
  process.stderr.transform(utf8.decoder).listen(stderr.write);
  int exitCode = await process.exitCode;

  if (exitCode != 0) {
    _debug("Process failed with code $exitCode.");
    exit(-1);
  } {
    _debug("Job done! Updated $package to commit $sha ($message) from commit $initialCommitSetting.");
    exit(0);
  }
}

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

Future<void> resetGitCache(String sha) async {
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

extension FutureAddons<T> on Future<T> {
  Future<bool> willEqual(T value) async {
    return (await this) == value;
  }
}