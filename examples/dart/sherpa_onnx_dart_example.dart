import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:sherpa_onnx_dart/sherpa_onnx_dart.dart';

void main() async {
  var sherpaOnnx = SherpaOnnx();
  if (!await sherpaOnnx.ready) {
    throw Exception("Failed to load");
  }
  var scriptDir = File(Platform.script.toFilePath()).parent.path;

  var bufferLengthInBytes = 1024;
  var bufferLengthInSamples = bufferLengthInBytes ~/ 2;

  await sherpaOnnx.createRecognizer(
      16000,
      "$scriptDir/../assets/model/tokens.txt",
      "$scriptDir/../assets/model/encoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
      "$scriptDir/../assets/model/decoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
      "$scriptDir/../assets/model/joiner-epoch-99-avg-1.int8.with_runtime_opt.ort",
      bufferLengthInSamples: bufferLengthInSamples);

  /********************************/
  /* first simulate streaming     */
  /****************************** */
  await sherpaOnnx.createStream(null);

  var data = File("$scriptDir/../assets/test.pcm").readAsBytesSync();
  var sampleRate = 16000;

  var results = <ASRResult>[];
  var audioBuffer = AudioBuffer(sampleRate);

  var listener = sherpaOnnx.result.listen((ASRResult asrResult) {
    results.add(asrResult);
  });

  for (int i = 0; i < data.length; i += bufferLengthInBytes) {
    var segment = data.sublist(i, min(data.length, i + bufferLengthInBytes));
    sherpaOnnx.acceptWaveform(segment);
    audioBuffer.add(segment);
  }

  // add two seconds of trailing silence

  var silence = Uint8List(32000);
  sherpaOnnx.acceptWaveform(silence);
  audioBuffer.add(silence);

  // this can take some time if we're running on a crappy device, so let's give it a chance to breathe
  await Future.delayed(Duration(milliseconds: 5000));

  var resultString = results.last.words.map((w) => w.word).join();
  if ("你的妈妈叫什么名字" != resultString) {
    throw Exception("Decode failure, got $resultString");
  }

  print(results.last.words
      .map((w) => "${w.start}:${w.end} ${w.word}")
      .join("\n"));

  await sherpaOnnx.destroyStream();
  results.clear();
  /********************************/
  /* now decode the whole file    */
  /****************************** */
  var result = await sherpaOnnx.decodeWaveform(data);
  await Future.delayed(Duration.zero);
  print("Decoded file to $result");

  // cleanup
  await listener.cancel();

  var resampled = await sherpaOnnx.resample(data, 16000, 24000);

  File("$scriptDir/output/resampled.pcm")
      .writeAsBytesSync(resampled.buffer.asUint8List(resampled.offsetInBytes));

  await sherpaOnnx.dispose();
}
