import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:flutter_sherpa_onnx/flutter_sherpa_onnx_ffi.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  group('Recognizer tests', () {
    testWidgets('successfully recognize from a file', (tester) async {
      var plugin = FlutterSherpaOnnxFFI();
      await plugin.createRecognizer(
          16000,
          0.1,
          "assets/asr/tokens.txt",
          "assets/asr/encoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
          "assets/asr/decoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
          "assets/asr/joiner-epoch-99-avg-1.int8.with_runtime_opt.ort");
      await plugin.createStream(null);
      var byteData = await rootBundle.load("assets/test.pcm");
      var data = byteData.buffer.asUint8List(byteData.offsetInBytes);
      var results = <String>[];
      plugin.result.listen((ASRResult asrResult) {
        results.add(asrResult.words.map((w) => w.word).join(" "));
      });
      for (int i = 0; i < data.length; i += 1024) {
        plugin.acceptWaveform(data.sublist(i, min(data.length, i + 1024)));
      }
      // this can take some time if we're running on a crappy device, so let's give it a chance to breathe
      await Future.delayed(Duration(milliseconds: 5000));
      expect(results.last, "你的妈妈叫什么名字");

      // now do the same thing with hotwords
      // await plugin.destroyStream();
      await plugin.createStream(["你的妈妈叫什么名字"]);

      results = <String>[];
      plugin.result.listen((ASRResult asrResult) {
        results.add(asrResult.words.map((w) => w.word).join(" "));
      });
      for (int i = 0; i < data.length; i += 1024) {
        plugin.acceptWaveform(data.sublist(i, min(data.length, i + 1024)));
      }
      await Future.delayed(Duration(milliseconds: 5000));
      expect(results.last, "你的妈妈叫什么名字");
    });
  });
}
