// Copyright (c) 2023, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

import 'dart:io';

import 'package:logging/logging.dart';
import 'package:native_assets_cli/native_assets_cli.dart';
import 'package:native_toolchain_c/native_toolchain_c.dart';

void main(List<String> args) async {
  await build(args, (config, output) async {
    var platform = config.targetOS.toString().toLowerCase();
    var onnxDir = File(config.packageRoot.path).parent.path + "/flutter_onnx";
    var onnxLibDir = "$onnxDir/$platform/lib";
    var libDir = "${config.packageRoot.toFilePath()}/native/lib/$platform/";

    final packageName = config.packageName;

    final cbuilder = CBuilder.library(
      name: packageName,
      language: Language.cpp,
      assetName: '$packageName.dart',
      sources: [
        'native/src/extras.cpp',
      ],
      includes: ['native/include', '${onnxDir}/ios/include'],
      flags: [
        '-std=c++17',
        "-F$onnxLibDir",
        '-framework',
        'onnxruntime',
        '-framework',
        'Foundation',
        "-lkaldi-decoder-core",
        "-lsherpa-onnx-fst",
        "-lsherpa-onnx-c-api",
        "-lsherpa-onnx-core",
        "-lkaldi-native-fbank-core",
        "-lsherpa-onnx-kaldifst-core",
        "-L$libDir",
        "-force_load",
        "$libDir/libsherpa-onnx-fst.a",
        "-force_load",
        "$libDir/libsherpa-onnx-c-api.a",
        "-force_load",
        "$libDir/libsherpa-onnx-core.a",
        "-force_load",
        "$libDir/libkaldi-decoder-core.a",
        "-force_load",
        "$libDir/libkaldi-native-fbank-core.a",
        "-force_load",
        "$libDir/libsherpa-onnx-kaldifst-core.a"
      ],
      dartBuildFiles: ['hook/build.dart'],
    );

    await cbuilder.run(
      buildConfig: config,
      buildOutput: output,
      logger: Logger('')
        ..level = Level.ALL
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}
