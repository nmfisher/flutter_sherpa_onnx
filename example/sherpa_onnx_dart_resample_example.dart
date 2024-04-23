import 'dart:io';

import 'package:sherpa_onnx_dart/sherpa_onnx_dart.dart';

void main() async {
  var sherpaOnnx = SherpaOnnx();
  if (!await sherpaOnnx.ready) {
    throw Exception("Failed to load");
  }
  var scriptDir = File(Platform.script.toFilePath()).parent.path;

  var data = File("$scriptDir/test.pcm").readAsBytesSync();

  var resampled = await sherpaOnnx.resample(data, 16000, 24000);

  File("$scriptDir/resampled.pcm")
      .writeAsBytesSync(resampled.buffer.asUint8List(resampled.offsetInBytes));

  await sherpaOnnx.dispose();
}
