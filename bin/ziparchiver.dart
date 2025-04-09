/*
  Copyright (C) 2025 hidenorly

   Licensed under the Apache License, Version 2.0 (the "License");
   you may not use this file except in compliance with the License.
   You may obtain a copy of the License at

       http://www.apache.org/licenses/LICENSE-2.0

   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
   See the License for the specific language governing permissions and
   limitations under the License.
*/

import 'dart:io';
import 'package:args/args.dart';
import '../lib/ziparchiver.dart';
import 'package:path/path.dart' as p;

// help
void printUsage(ArgParser parser) {
  print('Usage: dart ziparchiver target.zip files or just 1 file');
  print(parser.usage);
}


class ZipArchiverHelper
{
  static String getDeltaPath(String baseDir, String targetPath) {
    final String expandedBase = p.absolute(p.normalize(baseDir));
    final String expandedTarget = p.absolute(p.normalize(targetPath));

    // case : not started with baseDir
    if (!expandedTarget.startsWith(expandedBase)) {
      return targetPath;
    }

    // same path
    if (expandedTarget.length == expandedBase.length) {
      return "";
    }

    final candidate = expandedTarget.substring(expandedBase.length + 1);
    return candidate.length < targetPath.length ? candidate : targetPath;
  }

  static void createZipFile(String targetZipFile, List<String> targetFiles, [String? password]) async {
    // create zip file
    final zip = ZipArchiver();
    zip.open(targetZipFile, password);
    final baseDir = p.dirname(targetZipFile);

    // add file to the zipfile
    for (var targetFile in targetFiles) {
      print("zip ${targetFile} to ${targetZipFile}");
      final file = File(targetFile);
      final isFile = await file.exists();
      if( isFile ){
        zip.addFile(targetFile, getDeltaPath(baseDir, targetFile));
      }
    }
    zip.close();
  }

  // --- one file case. hoge.txt -> hoge.zip, hoge/ -> hoge.zip
  static Future<String> getZipFilePath(String path) async {
    final file = File(path);
    final dir = Directory(path);
    final isFile = await file.exists();
    final parentDir = isFile ? file.parent.path : dir.parent.path;
    final baseName = isFile ? file.uri.pathSegments.last.split('.').first : p.basename(dir.path);
    return "$parentDir/$baseName.zip";
  }

  // --- iterate files
  static Stream<FileSystemEntity> listEntities(Directory directory) async* {
    try {
      await for (final entity in directory.list()) {
        yield entity;
      }
    } catch (e) {
      print('Error listing directory ${directory.path}: $e');
    }
  }

  static Future<void> findFilesRecursively(String targetPath, void Function(File file) onFileFound) async {
    final directory = Directory(targetPath);

    if (await directory.exists()) {
      await for (final entity in listEntities(directory)) {
        if (entity is File) {
          onFileFound(entity);
        } else if (entity is Directory) {
          await findFilesRecursively(entity.path, onFileFound);
        }
      }
    } else {
      print('not found: ${targetPath}');
    }
  }

  // --- convert to files
  static Future<List<String>> getFileList(List<String> targets) async {
    List<String> targetFiles = [];
    for (final path in targets) {
      final dir = Directory(path);
      final isDir = await dir.exists();
      if( isDir ){
        await findFilesRecursively(path, (File file) {
          targetFiles.add(file.path);
        });
      } else {
        targetFiles.add(path);
      }
    }
    return targetFiles;
  }
}


void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('password', abbr: 'p', help: 'Password')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show usage information');

  ArgResults argResults;
  try {
    argResults = parser.parse(arguments);
  } on FormatException catch (e) {
    print('Error: ${e.message}');
    printUsage(parser);
    exit(-1); // report error status
  }

  // show help
  if (argResults['help'] == true || argResults.rest.length<1) {
    printUsage(parser);
    return;
  }
  String targetZipFile = argResults.rest[0];
  List<String> targets = [];
  List<String> targetFiles = [];
  if( argResults.rest.length == 1){
    // --- one file case. hoge.txt -> hoge.zip, hoge/ -> hoge.zip
    final path = argResults.rest[0];
    targets = [path];
    targetZipFile = await ZipArchiverHelper.getZipFilePath(path);    
  } else {
    // --- multiple case: args[0]:target.zip, arg[1..]:specified files, directories
    targets = argResults.rest.sublist(1);
  }

  if( await File(targetZipFile).exists() ){
    print("${targetZipFile} already exitst.");
    exit(-1);
  }

  // convert to files
  targetFiles = await ZipArchiverHelper.getFileList(targets);

  // create zip file
  ZipArchiverHelper.createZipFile(targetZipFile, targetFiles, argResults["password"]);


/*
  final zip = ZipArchiver();
  zip.open("test/hoge.zip");//, "password123");
  zip.addFile("test/testfile.txt", "testfile.txt");
  zip.close();

  zip.open("hoge.zip", "password123");
  zip.addFile("test.txt", ".");
  zip.rename("test.txt", "renamed.txt");
  zip.remove("renamed.txt");
*/
}
