import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:sherpa_onnx_dart/src/sherpa_onnx_dart.g.dart';
import 'package:sherpa_onnx_dart/src/sherpa_onnx_isolate.dart';
import 'package:sherpa_onnx_dart/src/sherpa_onnx_recognizer.dart';
import 'package:sherpa_onnx_dart/src/sherpa_onnx_recognizer_impl.dart';
import 'package:sherpa_onnx_dart/src/word_transcription.dart';

///
/// A Dart wrapper around a sherpa-onnx Recognizer/Stream
/// Calling the constructor only sets up the wrapper; you will need
/// to call [createRecognizer], [createStream], then [acceptWaveform] to start
/// processing audio data.
///
class SherpaOnnx {
  Stream<ASRResult> get result => _resultController.stream;
  final _resultController = StreamController<ASRResult>.broadcast();

  SherpaOnnxRecognizer? _recognizer;

  Stream<Float64List?> get spectrum =>
      _recognizer!.spectrum.cast<Float64List?>();

  Future<bool> get ready => _recognizer!.ready;

  SherpaOnnx({bool useIsolate = false}) {
    _recognizer = useIsolate ? SherpaOnnxIsolate() : SherpaOnnxRecognizerImpl();

    _recognizer!.result.listen(_onResult);
  }

  ASRResult _decodeStringResult(String result) {
    var resultMap = json.decode(result);
    bool isFinal = resultMap["is_endpoint"] == true;

    var numTokens = resultMap["tokens"].length;
    var words = <WordTranscription>[];
    for (int i = 0; i < numTokens; i++) {
      words.add(WordTranscription(
          resultMap["tokens"][i],
          resultMap["start_time"] + resultMap["timestamps"][i],
          i == numTokens - 1
              ? null
              : resultMap["start_time"] + resultMap["timestamps"][i + 1]));
    }
    return ASRResult(isFinal, words);
  }

  void _onResult(String? result) {
    if (result == null) {
      return;
    }
    var decoded = _decodeStringResult(result);
    _resultController.add(decoded);
  }

  Future decodeBuffer() async {
    throw Exception("TODO");
  }

  ///
  /// Creates a recognizer using the tokens, encoder, decoder and joiner at the specified paths.
  /// [sampleRate] is the sample rate of the PCM-encoded data that will be passed into [acceptWaveform].
  /// When [acceptWaveform] is called, the audio data is not directly passed to the recognizer.
  /// Rather, we buffer the incoming data until [chunkLengthInSecs] is available, and then pass that chunk the recognizer.
  /// Use this parameter to increase/decrease the frequency with which the recognizer attempts to decode the stream.
  ///
  Future<bool> createRecognizer(double sampleRate, String tokensFilePath,
      String encoderFilePath, String decoderFilePath, String joinerFilePath,
      {double chunkLengthInSecs = 0.25,
      double hotwordsScore = 20.0,
      int? bufferLengthInSamples, 
      double minTrailingSilence1 = 2.4,
      double minTrailingSilence2 = 1.2}) async {
    return _recognizer!.createRecognizer(
        sampleRate: sampleRate,
        chunkLengthInSecs: chunkLengthInSecs,
        tokensPath: tokensFilePath,
        encoderPath: encoderFilePath,
        decoderPath: decoderFilePath,
        joinerPath: joinerFilePath,
        hotwordsScore: hotwordsScore,
        bufferLengthInSamples: bufferLengthInSamples ?? 512,
        minTrailingSilence1:minTrailingSilence1,
      minTrailingSilence2:minTrailingSilence2);
  }

  Future createStream(List<String>? phrases) async {
    var hotwords =
        phrases?.map((x) => x.split("").join(" ")).toList().join("\n");

    return _recognizer!.createStream(hotwords);
  }

  Future destroyStream() async {
    _recognizer!.destroyStream();
  }

  Future destroyRecognizer() async {
    _recognizer!.destroyRecognizer();
  }

  void acceptWaveform(Uint8List data) async {
    if (data.offsetInBytes % 2 != 0) {
      data = Uint8List.fromList(data);
    }
    _recognizer!.acceptWaveform(data);
  }

  Future<ASRResult?> decodeWaveform(Uint8List data) async {
    var result = await _recognizer!.decodeWaveform(data);
    if (result == null) {
      return null;
    }
    var decoded = _decodeStringResult(result);
    return decoded;
  }

  Future dispose() async {
    await _recognizer!.dispose();
  }

  Future<Uint8List> resample(
      Uint8List data, int oldSampleRate, int newSampleRate) async {
    var length = data.length ~/ 2;
    final floatPtr = calloc<Float>(length);
    var int16Data = data.buffer.asInt16List(data.offsetInBytes, length);
    floatPtr
        .asTypedList(length)
        .setRange(0, length, int16Data.map((i) => i / 32768.0));
    final outPtr = calloc<Pointer<Float>>(1);
    final outLenPtr = calloc<Int>(1);
    sherpa_onnx_dart_resample(
        floatPtr, length, oldSampleRate, newSampleRate, outPtr, outLenPtr);
    final outData = Int16List.fromList(outPtr[0]
        .asTypedList(outLenPtr.value)
        .map((i) => (i * 32768.0).toInt())
        .toList());
    sherpa_onnx_dart_free(outPtr.value);
    calloc.free(outPtr);
    calloc.free(outLenPtr);
    return outData.buffer.asUint8List(outData.offsetInBytes);
  }
}
