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

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

// load libzip shared library
final dylib = DynamicLibrary.open(
    Platform.isMacOS ? "/opt/homebrew/lib/libzip.dylib" :
    Platform.isLinux ? "libzip.so" :
    "libzip.dll");

typedef ZipOpenNative = Pointer<Void> Function(Pointer<Utf8>, Int32, Pointer<Int32>);
typedef ZipOpenDart = Pointer<Void> Function(Pointer<Utf8>, int, Pointer<Int32>);

typedef ZipCloseNative = Int32 Function(Pointer<Void>);
typedef ZipCloseDart = int Function(Pointer<Void>);

typedef ZipSourceBufferNative = Pointer<Void> Function(Pointer<Void>, Pointer<Void>, Int64, Int32);
typedef ZipSourceBufferDart = Pointer<Void> Function(Pointer<Void>, Pointer<Void>, int, int);

typedef ZipSourceFreeNative = Void Function(Pointer<Void>);
typedef ZipSourceFreeDart = void Function(Pointer<Void>);

typedef ZipFileAddNative = Int32 Function(Pointer<Void>, Pointer<Utf8>, Pointer<Void>, Int32);
typedef ZipFileAddDart = int Function(Pointer<Void>, Pointer<Utf8>, Pointer<Void>, int);

typedef ZipSetFileEncryptionNative = Int32 Function(Pointer<Void>, Int32, Int32, Pointer<Utf8>);
typedef ZipSetFileEncryptionDart = int Function(Pointer<Void>, int, int, Pointer<Utf8>);

typedef ZipRenameNative = Int32 Function(Pointer<Void>, Int32, Pointer<Utf8>);
typedef ZipRenameDart = int Function(Pointer<Void>, int, Pointer<Utf8>);

typedef ZipDeleteNative = Int32 Function(Pointer<Void>, Int32);
typedef ZipDeleteDart = int Function(Pointer<Void>, int);

typedef ZipGetNumEntryNative = Int32 Function(Pointer<Void>, Int32);
typedef ZipGetNumEntryDart = int Function(Pointer<Void>, int);

typedef ZipGetNameNative = Pointer<Utf8> Function(Pointer<Void>, Int32, Int32);
typedef ZipGetNameDart = Pointer<Utf8> Function(Pointer<Void>, int, int);

typedef ZipNameLocateNative = Int32 Function(Pointer<Void>, Pointer<Utf8>, Int32);
typedef ZipNameLocateDart = int Function(Pointer<Void>, Pointer<Utf8>, int);


base class ZipError extends Struct {
  @Int32()
  external int zip_err;

  @Int32()
  external int sys_err;

  external Pointer<Utf8> str;
}

typedef ZipGetErrorNative = Pointer<ZipError> Function(Pointer<Void>);
typedef ZipGetErrorDart = Pointer<ZipError> Function(Pointer<Void>);


class ZipArchiver {
  final zip_open = dylib.lookupFunction<ZipOpenNative, ZipOpenDart>('zip_open');
  final zip_close = dylib.lookupFunction<ZipCloseNative, ZipCloseDart>('zip_close');
  final zip_source_buffer = dylib.lookupFunction<ZipSourceBufferNative, ZipSourceBufferDart>('zip_source_buffer');
  final zip_source_free = dylib.lookupFunction<ZipSourceFreeNative, ZipSourceFreeDart>('zip_source_free');

  final zip_file_add = dylib.lookupFunction<ZipFileAddNative, ZipFileAddDart>('zip_file_add');
  final zip_set_file_encryption = dylib.lookupFunction<ZipSetFileEncryptionNative, ZipSetFileEncryptionDart>('zip_file_set_encryption');
  final zip_file_rename = dylib.lookupFunction<ZipRenameNative, ZipRenameDart>('zip_file_rename');
  final zip_delete = dylib.lookupFunction<ZipDeleteNative, ZipDeleteDart>('zip_delete');

  final zip_get_num_entries = dylib.lookupFunction<ZipGetNumEntryNative, ZipGetNumEntryDart>('zip_get_num_entries');
  final zip_get_name = dylib.lookupFunction<ZipGetNameNative, ZipGetNameDart>('zip_get_name');
  final zip_name_locate = dylib.lookupFunction<ZipNameLocateNative, ZipNameLocateDart>('zip_name_locate');
  final zip_get_error = dylib.lookupFunction<ZipGetErrorNative, ZipGetErrorDart>('zip_get_error');

  final ZIP_EM_AES_128 = 0x0101; // Winzip AES encryption
  final ZIP_EM_AES_192 = 0x0102;
  final ZIP_EM_AES_256 = 0x0103;

  final ZIP_CREATE = 1;
  final ZIP_EXCL = 2;
  final ZIP_CHECKCONS = 4;
  final ZIP_TRUNCATE = 8;
  final ZIP_RDONLY = 16;

  final ZIP_FL_ENC_UTF_8 = 2048; // string is UTF-8 encoded


  late Pointer<Void> _zipFile;
  bool _isOpen = false;
  String? _password;

  ZipArchiver();

  void open(String zipPath, [String? password]) {
    _password = password;
    final errorPtr = calloc<Int32>();
    final zipPathNative = zipPath.toNativeUtf8();
    _zipFile = zip_open(zipPathNative, ZIP_CREATE | ZIP_EXCL, errorPtr);
    print("Error: ${errorPtr.value}");
    malloc.free(zipPathNative);
    malloc.free(errorPtr);
    if (_zipFile.address == 0) {
      throw Exception("Failed to open ZIP: Error code ${errorPtr.value}");
    }
    _isOpen = true;
  }

  void addFile(String filePath, String targetPath) {
    print("addFile:${filePath} to ${targetPath}");
    if (!_isOpen) throw Exception("ZIP file is not open.");

    final sourceFile = File(filePath);
    if (!sourceFile.existsSync()) throw Exception("File not found: $filePath");

    final sourceBytes = sourceFile.readAsBytesSync();
    final sourceData = malloc<Uint8>(sourceBytes.length);
    sourceData.asTypedList(sourceBytes.length).setAll(0, sourceBytes);

    final source = zip_source_buffer(_zipFile, sourceData.cast(), sourceBytes.length, 0);
    if (source == nullptr) {
      malloc.free(sourceData);
      dumpError();
      throw Exception("Failed to create zip_source_buffer");
    }

    final targetPathNative = targetPath.toNativeUtf8();
    final fileIndex = zip_file_add(_zipFile, targetPathNative, source, 1);//ZIP_FL_ENC_UTF_8);
    //zip_source_free(source);
    malloc.free(sourceData);
    malloc.free(targetPathNative);

    if (fileIndex < 0) {
      dumpError();
      throw Exception("Failed to add file: $filePath");
    }

    if (_password != null) {
      final passwordNative = _password!.toNativeUtf8();
      final result = zip_set_file_encryption(_zipFile, fileIndex, ZIP_EM_AES_128, passwordNative);
      malloc.free(passwordNative);
      if (result != 0) {
        dumpError();
        throw Exception("Failed to encrypt file: $filePath");
      }
    }
  }

  void rename(String oldName, String newName) {
    if (!_isOpen) throw Exception("ZIP file is not open.");
    final fileIndex = _getFileIndex(oldName);
    int result = -1;
    if( fileIndex >= 0 ){
      final newNameNative = newName.toNativeUtf8();
      result = zip_file_rename(_zipFile, fileIndex, newName.toNativeUtf8());
      malloc.free(newNameNative);
    }
    if (result != 0) {
      throw Exception("Failed to rename file: $oldName to $newName");
    }
  }

  void renameFolder(int zipPointer, String oldFolder, String newFolder) {
    if (!_isOpen) throw Exception("ZIP file is not open.");

    final fileList = getListFiles();

    for (final file in fileList) {
      if (file.startsWith("$oldFolder/")) {
        final newFileName = file.replaceFirst("$oldFolder/", "$newFolder/");
        rename(file, newFileName);
      }
    }
  }

  void remove(String fileName) {
    if (!_isOpen) throw Exception("ZIP file is not open.");
    int result = -1;
    final fileIndex = _getFileIndex(fileName);
    if( fileIndex >=0 ){
      result = zip_delete(_zipFile, fileIndex);
    }
    if (result != 0) {
      throw Exception("Failed to remove file: $fileName");
    }
  }

  void dumpError(){
    if (_isOpen && _zipFile.address != 0) {
      final errorPtr = zip_get_error(_zipFile).cast<ZipError>();
      if (errorPtr != nullptr) {
        final zipError = errorPtr.ref;
        final zipErr = zipError.zip_err;
        final sysErr = zipError.sys_err;
        final strPtr = zipError.str;
        final str = strPtr != nullptr ? strPtr.toDartString() : "(no error message)"; // toDartString()を使用
        print("Libzip error: $zipErr");
        print("System error: $sysErr");
        print("Error message: $str");
      }
    }
  }

  void close() {
    if (_isOpen && _zipFile.address != 0) {
      final result = zip_close(_zipFile);
      if( result!=0 ){
        print("Close error code: $result");
        dumpError();
      }

      _isOpen = false;
    } else {
      print("ZIP file is not open or already closed.");
    }
  }

  int _getFileIndex(String fileName) {
    if (!_isOpen) throw Exception("ZIP file is not open.");

    final fileNameNative = fileName.toNativeUtf8();
    final index = zip_name_locate(_zipFile, fileNameNative, 0); // 0: case-sensitive search
    malloc.free(fileNameNative);

    return index; // -1 : Not found
  }


  List<String> getListFiles() {
    if (!_isOpen) throw Exception("ZIP file is not open.");
    final List<String> fileList = [];

    final numEntries = zip_get_num_entries(_zipFile, 0);
    for (int i = 0; i < numEntries; i++) {
      final fileNamePtr = zip_get_name(_zipFile, i, 0);
      if (fileNamePtr != nullptr) {
        fileList.add(fileNamePtr.toDartString());
      }
    }

    return fileList;
  }
}
