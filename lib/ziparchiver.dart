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
import 'package:path/path.dart' as p;

class IZipArchiver {
  void open(String zipName, [String? password]){}
  void addFile(String path, String targetPath) async{}
  void rename(String oldName, String newName) {}
  void renameFolder(int zipPointer, String oldFolder, String newFolder) {}
  void remove(String fileName) {}
  void close() {}
}


// --- LibZipArchiver
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


class LibZipArchiver extends IZipArchiver {
  late final zip_open;
  late final zip_close;
  late final zip_source_buffer;
  late final zip_source_free;

  late final zip_file_add;
  late final zip_set_file_encryption;
  late final zip_file_rename;
  late final zip_delete;

  late final zip_get_num_entries;
  late final zip_get_name;
  late final zip_name_locate;
  late final zip_get_error;

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

  final DynamicLibrary? _dylib;

  static DynamicLibrary? _loadLibZip() {
    try {
      return DynamicLibrary.open(
        Platform.isMacOS ? "/opt/homebrew/lib/libzip.dylib" :
        Platform.isLinux ? "libzip.so" :
        "libzip.dll",
      );
    } catch (e) {
      print('Failed to open libzip: $e');
      return null;
    }
  }

  LibZipArchiver() : _dylib = _loadLibZip() {
    if(_dylib == null){
      throw Exception("libzip isn't available.");
    }

    zip_open = _dylib.lookupFunction<ZipOpenNative, ZipOpenDart>('zip_open');
    zip_close = _dylib.lookupFunction<ZipCloseNative, ZipCloseDart>('zip_close');
    zip_source_buffer = _dylib.lookupFunction<ZipSourceBufferNative, ZipSourceBufferDart>('zip_source_buffer');
    zip_source_free = _dylib.lookupFunction<ZipSourceFreeNative, ZipSourceFreeDart>('zip_source_free');

    zip_file_add = _dylib.lookupFunction<ZipFileAddNative, ZipFileAddDart>('zip_file_add');
    zip_set_file_encryption = _dylib.lookupFunction<ZipSetFileEncryptionNative, ZipSetFileEncryptionDart>('zip_file_set_encryption');
    zip_file_rename = _dylib.lookupFunction<ZipRenameNative, ZipRenameDart>('zip_file_rename');
    zip_delete = _dylib.lookupFunction<ZipDeleteNative, ZipDeleteDart>('zip_delete');

    zip_get_num_entries = _dylib.lookupFunction<ZipGetNumEntryNative, ZipGetNumEntryDart>('zip_get_num_entries');
    zip_get_name = _dylib.lookupFunction<ZipGetNameNative, ZipGetNameDart>('zip_get_name');
    zip_name_locate = _dylib.lookupFunction<ZipNameLocateNative, ZipNameLocateDart>('zip_name_locate');
    zip_get_error = _dylib.lookupFunction<ZipGetErrorNative, ZipGetErrorDart>('zip_get_error');
  }

  void open(String zipPath, [String? password]) {
    if(_dylib == null){
      throw Exception("libzip isn't available.");
      // note that _isOpen is kept to be false.
    }

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


// --- ZipArchiverExtCmd
class ZipArchiverExtCmd extends IZipArchiver {
  Future<void> _printProcessOutput(Process process) async {
    await for (var line in process.stdout.transform(SystemEncoding().decoder)) {
      print("stdout: $line");
    }
    await for (var line in process.stderr.transform(SystemEncoding().decoder)) {
      print("stderr: $line");
    }

    final exitCode = await process.exitCode;
    print("Process exited with code: $exitCode");
  }

  late String zipName;
  String? password;
  bool _isOpen = false;

  ZipArchiverExtCmd();

  void open(String zipName, [String? password]) {
    _isOpen = true;
    this.zipName = zipName;
    this.password = password;
  }

  void addFile(String path, String targetPath) async {
    if (!_isOpen) throw Exception("ZIP file is not open.");

    print("addFile:${path} to ${targetPath}");

    final file = File(path);
    final dir = Directory(path);
    final isFile = await file.exists();
    final parentDir = isFile ? file.parent.path : dir.parent.path;
    final zipTarget = isFile ? file.uri.pathSegments.last : p.basename(dir.path);

    List<String> args;
    if( password?.isNotEmpty == true ){
      args = isFile ? ['-P', password!, zipName, zipTarget] : ['-P', password!, zipName, '-r', zipTarget];
    } else {
      args = ['-r', zipName, zipTarget];
    }
    
    print("Running command: zip ${args.join(' ')}");

    final process = await Process.start('zip', args, workingDirectory: parentDir, runInShell: true);
    await _printProcessOutput(process);

  }

  void rename(String oldName, String newName) {
    throw Exception("Not implemented.");
  }

  void renameFolder(int zipPointer, String oldFolder, String newFolder) {
    throw Exception("Not implemented.");
  }

  void remove(String fileName) {
    throw Exception("Not implemented.");
  }

  void close() {
    _isOpen = false;
  }
}


// ZipArchiver (API provider)
class ZipArchiver extends IZipArchiver {
  late IZipArchiver impl;

  ZipArchiver(){
    try{
      impl = new LibZipArchiver();
      print("using LibZipArchiver");
    } catch(e){
      impl = new ZipArchiverExtCmd();
      print("fallback mode... using ZipArchiverExtCmd.");
    }
  }

  void open(String zipName, [String? password]){
    impl.open(zipName, password);
  }

  void addFile(String path, String targetPath) async{
    impl.addFile(path, targetPath);
  }

  void rename(String oldName, String newName) {
    impl.rename(oldName, newName);
  }

  void renameFolder(int zipPointer, String oldFolder, String newFolder) {
    impl.renameFolder(zipPointer, oldFolder, newFolder);
  }

  void remove(String fileName) {
    impl.remove(fileName);
  }

  void close() {
    impl.close();
  }
}


// helper
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
