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
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:path/path.dart' as p;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ZipEncryptor(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ZipEncryptor extends StatefulWidget {
  @override
  _ZipEncryptorState createState() => _ZipEncryptorState();
}



class IZipArchiver {
  void open(String zipName, [String? password]){}
  void addFile(String path, String targetPath) async{}
  void rename(String oldName, String newName) {}
  void renameFolder(int zipPointer, String oldFolder, String newFolder) {}
  void remove(String fileName) {}
  void close() {}
}

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


class ZipArchiver extends IZipArchiver {
  late IZipArchiver impl;

  ZipArchiver(){
    impl = new ZipArchiverExtCmd();
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


class _ZipEncryptorState extends State<ZipEncryptor> {
  String password = "";
  bool isDragging = false;

  void _createEncryptedZip(String path) async {
    final file = File(path);
    final dir = Directory(path);
    final isFile = await file.exists();
    final isDir = await dir.exists();

    if (!isFile && !isDir) return;

    final parentDir = isFile ? file.parent.path : dir.parent.path;
    final baseName = isFile 
        ? file.uri.pathSegments.last.split('.').first
        : p.basename(dir.path);
    final zipName = "$parentDir/$baseName.zip";
    final zipTarget = isFile ? file.uri.pathSegments.last : p.basename(dir.path);

    final zip = ZipArchiver();
    zip.open(zipName, password=="" ? null : password);
    zip.addFile(path, zipTarget);

    /*
    List<String> args;
    args = password.isNotEmpty ? 
              isFile ? ['-P', password, zipName, zipTarget] : ['-P', password, zipName, '-r', zipTarget]
           : ['-r', zipName, zipTarget];
    print("Running command: zip ${args.join(' ')}");
    final process = await Process.start('zip', args, workingDirectory: parentDir, runInShell: true);
    await _printProcessOutput(process);
    * */
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Encrypted Zip Creator')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Enter Password'),
              onChanged: (value) => setState(() => password = value),
            ),
          ),
          Expanded(
            child: DropTarget(
              onDragEntered: (_) => setState(() => isDragging = true),
              onDragExited: (_) => setState(() => isDragging = false),
              onDragDone: (detail) {
                setState(() {
                  isDragging = false;
                  for (var file in detail.files) {
                    if (file.path.isNotEmpty) {
                      _createEncryptedZip(file.path);
                    }
                  }
                });
              },
              child: Container(
                color: isDragging ? Colors.blue[100] : Colors.grey[300],
                child: const Center(child: Text('Drag & Drop files/folders here')),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
