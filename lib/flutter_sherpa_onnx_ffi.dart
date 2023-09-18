import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter_sherpa_onnx/FlutterSherpaOnnxFFIIsolateRunner.dart';
import 'package:path_provider/path_provider.dart';

import './generated_bindings.dart';
import 'package:flutter_ffi_asset_helper/flutter_ffi_asset_helper.dart';
import 'package:flutter/services.dart';

class FlutterSherpaOnnxFFI {
  Stream<Map> get result => _resultController.stream;
  final _resultController = StreamController<Map>.broadcast();

  Isolate? _runner;

  final double chunkLengthInSecs;

  final _createdRecognizerPort = ReceivePort();
  late Stream _createdRecognizerPortStream =
      _createdRecognizerPort.asBroadcastStream();
  final _setupPort = ReceivePort();
  bool _killed = false;
  final _resultPort = ReceivePort();

  late SendPort _dataPort;
  late SendPort _createRecognizerPort;
  late SendPort _killRecognizerPort;
  late SendPort _shutdownPort;

  final FlutterFfiAssetHelper _helper = FlutterFfiAssetHelper();

  FlutterSherpaOnnxFFI({this.chunkLengthInSecs = 0.05}) {
    _setupPort.listen((msg) {
      _dataPort = msg[0];
      _createRecognizerPort = msg[1];
      _killRecognizerPort = msg[2];
      _shutdownPort = msg[3];
    });
    _resultPort.listen((result) {
      _resultController.add(json.decode(result));
    });

    Isolate.spawn(FlutterSherpaOnnxFFIIsolateRunner.create, [
      _setupPort.sendPort,
      _createdRecognizerPort.sendPort,
      _resultPort.sendPort,
      chunkLengthInSecs
    ]).then((isolate) {
      _runner = isolate;
    });
  }

  Future decodeBuffer() async {
    throw Exception("TODO");
  }

  Future createRecognizer(
      double sampleRate,
      String tokensAssetPath,
      String encoderAssetPath,
      String decoderAssetPath,
      String joinerAssetPath) async {
    final completer = Completer<bool>();
    late StreamSubscription listener;
    listener = _createdRecognizerPortStream.listen((success) {
      completer.complete(success);
      listener.cancel();
    });

    var tokensFilePath = await _helper.getFdFromAsset(tokensAssetPath);
    var encoderFilePsath = await _helper.getFdFromAsset(encoderAssetPath);
    var decoderFilePath = await _helper.getFdFromAsset(decoderAssetPath);
    var joinerFilePath = await _helper.getFdFromAsset(joinerAssetPath);

    _createRecognizerPort.send([
      sampleRate,
      tokensFilePath,
      encoderFilePsath,
      decoderFilePath,
      joinerFilePath
    ]);
    var result = await completer.future;
    if (result) {
      _killed = false;
    }
    return result;
  }

  Future resetRecognizer() async {
    throw Exception();
  }

  Future setGrammar({List<String>? grammar}) async {
    throw Exception("TODO");
  }

  Future destroyRecognizer() async {
    _killRecognizerPort.send(true);
    _killed = true;
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
