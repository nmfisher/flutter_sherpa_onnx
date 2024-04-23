import 'dart:async';

import 'dart:typed_data';

abstract class SherpaOnnxRecognizer {
  Stream<Float64List?> get spectrum;

  Future dispose();

  Stream<String?> get result;

  Future<bool> createRecognizer(
      {required double sampleRate,
      required double chunkLengthInSecs,
      required String tokensPath,
      required String encoderPath,
      required String decoderPath,
      required String joinerPath,
      required double hotwordsScore,
      int? bufferLengthInSamples});

  Future<bool> get ready;
  bool isReadyForInput();

  Future<bool> createStream(String? hotwords);

  Future<String?> decodeWaveform(Uint8List data);

  void acceptWaveform(Uint8List data);

  Future destroyStream();

  Future destroyRecognizer();
}
