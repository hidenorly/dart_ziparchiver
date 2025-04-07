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

// iterate files
Stream<FileSystemEntity> listEntities(Directory directory) async* {
  try {
    await for (final entity in directory.list()) {
      yield entity;
    }
  } catch (e) {
    print('Error listing directory ${directory.path}: $e');
  }
}

Future<void> findFilesRecursively(String targetPath, void Function(File file) onFileFound) async {
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
  var targetZipFile = argResults.rest[0];
  var targets = [];
  var targetFiles = [];
  if( argResults.rest.length == 1){
    // --- one file case. hoge.txt -> hoge.zip, hoge/ -> hoge.zip
    final path = argResults.rest[0];
    targets = [path];

    final file = File(path);
    final dir = Directory(path);
    final isFile = await file.exists();
    final parentDir = isFile ? file.parent.path : dir.parent.path;
    final baseName = isFile ? file.uri.pathSegments.last.split('.').first : p.basename(dir.path);
    targetZipFile = "$parentDir/$baseName.zip";
  } else {
    // --- multiple case: args[0]:target.zip, arg[1..]:specified files, directories
    targets = argResults.rest.sublist(1);
  }

  if( await File(targetZipFile).exists() ){
    print("${targetZipFile} already exitst.");
    exit(-1);
  }

  // convert to files
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

  final zip = ZipArchiver();
  if( argResults["password"]!=null ){
    zip.open(targetZipFile, argResults['password']);
  } else {
    zip.open(targetZipFile);
  }

  for (var targetFile in targetFiles) {
    print("zip ${targetFile} to ${targetZipFile}");
    final file = File(targetFile);
    final dir = Directory(targetFile);
    final isFile = await file.exists();
    final isDir = await dir.exists();
    if( isFile ){
      zip.addFile(targetFile, targetFile); //TODO:make it relative path
    }
  }
  zip.close();



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
