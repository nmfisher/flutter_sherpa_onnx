import 'dart:io';
import 'dart:math';

import 'package:sherpa_onnx_dart/sherpa_onnx_dart.dart';

void main() async {
  var sherpaOnnx = SherpaOnnx();
  if (!await sherpaOnnx.ready) {
    throw Exception("Failed to load");
  }
  var scriptDir = File(Platform.script.toFilePath()).parent.path;

  await sherpaOnnx.createRecognizer(
      16000,
      "$scriptDir/model/tokens.txt",
      "$scriptDir/model/encoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
      "$scriptDir/model/decoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
      "$scriptDir/model/joiner-epoch-99-avg-1.int8.with_runtime_opt.ort");

  await sherpaOnnx.createStream(null);

  var data = File("$scriptDir/test.pcm").readAsBytesSync();

  var results = <String>[];
  sherpaOnnx.result.listen((ASRResult asrResult) {
    results.add(asrResult.words.map((w) => w.word).join(" "));
  });
  for (int i = 0; i < data.length; i += 1024) {
    sherpaOnnx.acceptWaveform(data.sublist(i, min(data.length, i + 1024)));
  }
  // this can take some time if we're running on a crappy device, so let's give it a chance to breathe
  await Future.delayed(Duration(milliseconds: 5000));
  //"你的妈妈叫什么名字"
  print(results.last);
  await sherpaOnnx.dispose();
}
