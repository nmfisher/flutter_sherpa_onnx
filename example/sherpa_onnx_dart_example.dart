import 'dart:ffi';
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

  await sherpaOnnx.createRecognizer(
      16000,
      "$scriptDir/model/tokens.txt",
      "$scriptDir/model/encoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
      "$scriptDir/model/decoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
      "$scriptDir/model/joiner-epoch-99-avg-1.int8.with_runtime_opt.ort");

  /********************************/
  /* first simulate streaming     */
  /****************************** */
  await sherpaOnnx.createStream(null);

  var data = File("$scriptDir/test.pcm").readAsBytesSync();
  var sampleRate = 16000;

  var results = <ASRResult>[];
  var audioBuffer = AudioBuffer(sampleRate);

  var listener = sherpaOnnx.result.listen((ASRResult asrResult) {
    results.add(asrResult);
  });
  for (int i = 0; i < data.length; i += 1024) {
    var segment = data.sublist(i, min(data.length, i + 1024));
    sherpaOnnx.acceptWaveform(segment);
    audioBuffer.add(segment);
  }

  // add two seconds of trailing silence

  var silence = Uint8List(32000);
  sherpaOnnx.acceptWaveform(silence);
  audioBuffer.add(silence);

  // this can take some time if we're running on a crappy device, so let's give it a chance to breathe
  await Future.delayed(Duration(milliseconds: 5000));

  if ("你的妈妈叫什么名字" != results.last.words.map((w) => w.word).join()) {
    throw Exception("Decode failure");
  }

  // print(results.last.words
  //     .map((w) => "${w.start}:${w.end} ${w.word}")
  //     .join("\n"));

  await sherpaOnnx.destroyStream();
  results.clear();
  /********************************/
  /* now decode the whole file    */
  /****************************** */
  await sherpaOnnx.decodeWaveform(data);
  await Future.delayed(Duration.zero);
  print(results);

  // cleanup
  await listener.cancel();
  await sherpaOnnx.dispose();

  // int i = 0;
  // for (final word in results.last.words) {
  //   print("Getting segment ${word.start}->${word.end}");
  //   var segment = audioBuffer.getSegment(word.start!, word.end! - word.start!);
  //   var outfile = File("/tmp/segment_$i.pcm");
  //   outfile.writeAsBytesSync(segment);
  //   print("Wrote to ${outfile.path}");
  //   i += 1;
  // }
}
