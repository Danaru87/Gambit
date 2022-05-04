import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:dcli/dcli.dart';

import '../core/exceptions.dart';
import '../core/gambit_command.dart';
import '../core/tasks.extensions.dart';
import 'descriptor.dart';

class GetAppVersionCmd extends GambitCommand {
  late String flutterProjectPath;

  GetAppVersionCmd() : super(GetAppVersionCommandDescriptor());

  @override
  run() async {
    checkVerboseMode();
    flutterProjectPath =
        argResults![GetAppVersionCommandDescriptor.projectPathArgName];

    final _runResult = await _checkFlutterFolder()
        .bindRight(_getFlutterPubspec)
        .bindRight(_getSemanticVersion)
        .run();

    _runResult.fold(
      (_failure) {
        printError(_failure.cause);
        exit(_failure.exitCode ?? 1);
      },
      (semanticVersion) {
        printSuccess(semanticVersion, verbosePrefix: "Version:");
        exit(0);
      },
    );
  }

  Task<GCTaskResult<Directory>> _checkFlutterFolder() =>
      Task<GCTaskResult<Directory>>(() async {
        final currentDirectory = Directory(flutterProjectPath);
        if (!currentDirectory.existsSync()) {
          return left(
            CommandFailure(
              cause: "No directory found at ${currentDirectory.absolute.path}",
              exitCode: 1,
            ),
          );
        }
        return right(currentDirectory);
      });

  Task<GCTaskResult<String>> _getFlutterPubspec(
          Directory flutterProjectDirectory) =>
      Task<GCTaskResult<String>>(() async {
        printDebug(yellow(
            'Seaching pubspec into: ${flutterProjectDirectory.absolute.path}'));

        try {
          String pubspecPath = find(
            "pubspec.yaml",
            workingDirectory: flutterProjectDirectory.absolute.path,
            recursive: true,
            types: [FileSystemEntityType.file],
          ).toList().first;
          return right(pubspecPath);
        } on StateError catch (_) {
          return left(
            CommandFailure(
              cause:
                  "pubspec.yaml not found in ${flutterProjectDirectory.path}",
              exitCode: 1,
            ),
          );
        }
      });

  Task<GCTaskResult<String>> _getSemanticVersion(String pubspecPath) =>
      Task<GCTaskResult<String>>(() async {
        final yaml = PubSpec.fromFile(pubspecPath);
        if (!yaml.dependencies.containsKey("flutter")) {
          return left(
            CommandFailure(
              cause: "This pubspec is not flutter's pubspec.",
              exitCode: 1,
            ),
          );
        }

        final semanticVersion = [
          yaml.version!.major,
          yaml.version!.minor,
          yaml.version!.patch,
        ].join(".");
        return right(semanticVersion);
      });
}
