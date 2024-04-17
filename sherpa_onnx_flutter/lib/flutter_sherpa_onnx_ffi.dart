import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_sherpa_onnx/flutter_sherpa_onnx_ffi_isolate.dart';
import 'package:flutter_ffi_asset_helper/flutter_ffi_asset_helper.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class WordTranscription {
  final String word;
  final double? start;
  final double? end;

  WordTranscription(this.word, this.start, this.end);
}

class ASRResult {
  final bool isFinal;
  final List<WordTranscription> words;

  ASRResult(this.isFinal, this.words);
}

class FlutterSherpaOnnxFFI {
  Stream<ASRResult> get result => _resultController.stream;
  final _resultController = StreamController<ASRResult>.broadcast();

  Isolate? _runner;

  final _createdRecognizerPort = ReceivePort();
  late Stream _createdRecognizerPortStream =
      _createdRecognizerPort.asBroadcastStream();
  final _createdStreamPort = ReceivePort();
  Completer? _createdStream;

  final _setupPort = ReceivePort();
  bool _killed = false;
  final _resultPort = ReceivePort();

  late SendPort _dataPort;
  late SendPort _createRecognizerPort;
  late SendPort _killRecognizerPort;
  late SendPort _createStreamPort;
  late SendPort _shutdownPort;
  final _isolateSetupComplete = Completer();

  final FlutterFfiAssetHelper _helper = FlutterFfiAssetHelper();

  late final StreamSubscription _setupListener;
  late final StreamSubscription _resultListener;
  late final StreamSubscription _createdStreamListener;

  FlutterSherpaOnnxFFI() {
    _setupListener = _setupPort.listen((msg) {
      _dataPort = msg[0];
      _createRecognizerPort = msg[1];
      _killRecognizerPort = msg[2];
      _createStreamPort = msg[3];
      _shutdownPort = msg[4];
      _isolateSetupComplete.complete(true);
    });

    _resultListener = _resultPort.listen(_onResult);

    _createdStreamListener = _createdStreamPort.listen((success) {
      try {
        _createdStream!.complete(success as bool);
      } catch (err) {
        print(err);
      }
    });

    Isolate.spawn(FlutterSherpaOnnxFFIIsolateRunner.create, [
      _setupPort.sendPort,
      _createdRecognizerPort.sendPort,
      _createdStreamPort.sendPort,
      _resultPort.sendPort,
      ServicesBinding.rootIsolateToken
    ]).then((isolate) {
      _runner = isolate;
    });
  }

  void _onResult(dynamic result) {
    var resultMap = json.decode(result);

    bool isFinal = resultMap["is_endpoint"] == true;

    if (isFinal) {
      if (resultMap["text"].isNotEmpty) {
        var numTokens = resultMap["tokens"].length;
        var words = <WordTranscription>[];
        for (int i = 0; i < numTokens; i++) {
          words.add(WordTranscription(
              resultMap["tokens"][i], resultMap["timestamps"][i], -1));
        }
        _resultController.add(ASRResult(isFinal, words));
      }
    } else {
      if (resultMap["text"].isNotEmpty) {
        _resultController.add(ASRResult(
            isFinal, [WordTranscription(resultMap["text"], null, null)]));
      }
    }
  }

  Future decodeBuffer() async {
    throw Exception("TODO");
  }

  bool _hasRecognizer = false;

  Future createRecognizer(
      double sampleRate,
      double chunkLengthInSecs,
      String tokensAssetPath,
      String encoderAssetPath,
      String decoderAssetPath,
      String joinerAssetPath,
      {double hotwordsScore = 20.0}) async {
    await _isolateSetupComplete.future;
    final completer = Completer<bool>();
    late StreamSubscription listener;
    listener = _createdRecognizerPortStream.listen((success) {
      completer.complete(success);
      listener.cancel();
    });

    var tokensFilePath = await _helper.assetToFilepath(tokensAssetPath);
    var encoderFilePath = await _helper.assetToFilepath(encoderAssetPath);
    var decoderFilePath = await _helper.assetToFilepath(decoderAssetPath);
    var joinerFilePath = await _helper.assetToFilepath(joinerAssetPath);

    _createRecognizerPort.send([
      sampleRate,
      chunkLengthInSecs,
      tokensFilePath,
      encoderFilePath,
      decoderFilePath,
      joinerFilePath,
      hotwordsScore
    ]);

    var result = await completer.future;
    _hasRecognizer = true;
    return result;
  }

  Future createStream(List<String>? phrases) async {
    if (_createdStream != null) {
      throw Exception("A request to create a stream is already pending.");
    }
    _createdStream = Completer();
    _createStreamPort
        .send(phrases?.map((x) => x.split("").join(" ")).toList().join("\n"));
    var result = await _createdStream!.future;
    if (result) {
      _killed = false;
    } else {
      throw Exception("Failed to create stream. Is a recognizer available?");
    }
    _createdStream = null;
    return result;
  }

  Future destroyStream() {
    throw Exception("TODO");
  }

  Future destroyRecognizer() async {
    if (_hasRecognizer) {
      _killRecognizerPort.send(true);
      _killed = true;
    }
    _hasRecognizer = false;
  }

  void acceptWaveform(Uint8List data) async {
    if (_killed) {
      return;
    }
    _dataPort.send(data);
  }

  Future dispose() async {
    _shutdownPort.send(true);
  }
}
