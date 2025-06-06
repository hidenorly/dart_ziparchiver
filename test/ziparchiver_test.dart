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
import 'package:test/test.dart';

void main() {
  test('execute & help', () async {
    final process = await Process.start('dart', ['run', 'bin/ziparchiver.dart', '--help']);

    final result = await process.stdout.transform(SystemEncoding().decoder).join();
    final exitCode = await process.exitCode;

    expect(exitCode, equals(0));

    expect(result, contains('Usage: dart ziparchiver'));
    expect(result, contains('--password'));
  });
}
