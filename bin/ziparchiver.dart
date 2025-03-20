import 'package:ziparchiver/ziparchiver.dart' as ziparchiver;
import '../lib/ziparchiver.dart';
import 'dart:ffi';
import 'package:ffi/ffi.dart';


void main(List<String> arguments) {
  final zip = ZipArchiver();
  zip.open("test/hoge.zip");//, "password123");
  zip.addFile("test/testfile.txt", "testfile.txt");
  zip.close();

/*
  zip.open("hoge.zip", "password123");
  zip.addFile("test.txt", ".");
  zip.rename("test.txt", "renamed.txt");
  zip.remove("renamed.txt");
*/
}
