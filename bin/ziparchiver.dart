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
