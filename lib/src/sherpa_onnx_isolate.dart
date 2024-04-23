import 'dart:async';

import 'dart:isolate';
import 'dart:typed_data';

import 'package:sherpa_onnx_dart/src/sherpa_onnx_recognizer.dart';
import 'package:sherpa_onnx_dart/src/sherpa_onnx_recognizer_impl.dart';

class SherpaOnnxIsolate extends SherpaOnnxRecognizer {
  final _resultController = StreamController<String?>.broadcast();
  Stream<String?> get result => _resultController.stream;

  final _createdRecognizerPort = ReceivePort();
  late final Stream _createdRecognizerPortStream =
      _createdRecognizerPort.asBroadcastStream();
  bool _hasRecognizer = false;

  final _createdStreamPort = ReceivePort();
  Completer? _createdStream;
  bool _hasStream = false;

  final _setupPort = ReceivePort();
  bool _killed = false;
  final _resultPort = ReceivePort();
  final _spectrumPort = ReceivePort();
  @override
  Stream<Float64List?> get spectrum =>
      _spectrumPort.map((s) => s as Float64List);

  Future<bool> get ready async {
    if (_runner == null) {
      return false;
    }
    await _runner;
    return true;
  }

  late SendPort _waveformStreamPort;
  late SendPort _decodeWaveformPort;
  late SendPort _createRecognizerPort;
  late SendPort _killRecognizerPort;
  late SendPort _createStreamPort;
  late SendPort _destroyStreamPort;
  late SendPort _shutdownPort;
  final _isolateSetupComplete = Completer();

  late final StreamSubscription _setupListener;
  late final StreamSubscription _resultListener;
  late final StreamSubscription _createdStreamListener;

  late Future<Isolate>? _runner;

  SherpaOnnxIsolate() {
    _setupListener = _setupPort.listen((msg) {
      _waveformStreamPort = msg[0];
      _decodeWaveformPort = msg[1];
      _createRecognizerPort = msg[2];
      _killRecognizerPort = msg[3];
      _createStreamPort = msg[4];
      _destroyStreamPort = msg[5];
      _shutdownPort = msg[6];
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

    _runner = Isolate.spawn(SherpaOnnxIsolateRunner.create, [
      _setupPort.sendPort,
      _createdRecognizerPort.sendPort,
      _createdStreamPort.sendPort,
      _resultPort.sendPort,
      _spectrumPort.sendPort
    ]);
  }

  void _onResult(dynamic result) {
    if (result == null) {
      return;
    }
    _resultController.sink.add(result as String);
  }

  bool isReadyForInput() {
    return _runner != null && _hasRecognizer && _hasStream;
  }

  @override
  Future<bool> createRecognizer(
      {required double sampleRate,
      required double chunkLengthInSecs,
      required String tokensPath,
      required String encoderPath,
      required String decoderPath,
      required String joinerPath,
      required double hotwordsScore,
      int? bufferLengthInSamples}) async {
    await _isolateSetupComplete.future;
    final completer = Completer<bool>();
    late StreamSubscription listener;
    listener = _createdRecognizerPortStream.listen((success) {
      completer.complete(success);
      listener.cancel();
    });

    _createRecognizerPort.send([
      sampleRate,
      chunkLengthInSecs,
      tokensPath,
      encoderPath,
      decoderPath,
      joinerPath,
      hotwordsScore,
      bufferLengthInSamples
    ]);

    var result = await completer.future;
    _hasRecognizer = true;
    return result;
  }

  @override
  Future<bool> createStream(String? hotwords) async {
    if (_createdStream != null) {
      throw Exception("A request to create a stream is already pending.");
    }
    _createdStream = Completer();
    _createStreamPort.send(hotwords ?? "");
    var result = await _createdStream!.future;
    if (result) {
      _killed = false;
    } else {
      throw Exception("Failed to create stream. Is a recognizer available?");
    }
    _createdStream = null;
    _hasStream = true;
    return result;
  }

  @override
  Future destroyStream() async {
    _destroyStreamPort.send(true);
    await Future.delayed(Duration.zero);
    _hasStream = false;
  }

  @override
  Future destroyRecognizer() async {
    if (_hasRecognizer) {
      _killRecognizerPort.send(true);
      _killed = true;
    }
    _hasRecognizer = false;
  }

  @override
  void acceptWaveform(Uint8List data) async {
    if (_killed) {
      print(
          "Warning - recognizer has been destroyed, this data will be ignored");
      return;
    }
    _waveformStreamPort.send(data);
  }

  @override
  Future<String?> decodeWaveform(Uint8List data) async {
    if (_hasStream) {
      throw Exception("Stream already exists. Call [destroyStream] first");
    }
    final completer = Completer<String>();

    await createStream(null);
    var resultListener = result.listen((result) {
      completer.complete(result);
    });
    _decodeWaveformPort.send(data);
    await completer.future;
    resultListener.cancel();
    await destroyStream();

    return completer.future;
  }

  @override
  Future dispose() async {
    (await _runner)?.kill();
    await _setupListener.cancel();
    await _resultListener.cancel();
    await _createdStreamListener.cancel();
    _shutdownPort.send(true);
    _createdRecognizerPort.close();
    _createdStreamPort.close();
    _resultPort.close();
    _spectrumPort.close();
  }
}

class SherpaOnnxIsolateRunner {
  final SendPort _setupPort;

  final SendPort _createdRecognizerPort;
  final SendPort _createdStreamPort;
  final SendPort _resultPort;
  final SendPort _spectrumPort;

  SherpaOnnxRecognizerImpl? _recognizer;

  SherpaOnnxIsolateRunner(this._setupPort, this._createdRecognizerPort,
      this._createdStreamPort, this._resultPort, this._spectrumPort) {
    var waveformStreamPort = ReceivePort();
    var decodeWaveformPort = ReceivePort();
    var createRecognizerPort = ReceivePort();
    var createStreamPort = ReceivePort();
    var killRecognizerPort = ReceivePort();
    var destroyStreamPort = ReceivePort();
    var shutdownPort = ReceivePort();

    _setupPort.send([
      waveformStreamPort.sendPort,
      decodeWaveformPort.sendPort,
      createRecognizerPort.sendPort,
      killRecognizerPort.sendPort,
      createStreamPort.sendPort,
      destroyStreamPort.sendPort,
      shutdownPort.sendPort,
    ]);

    createRecognizerPort.listen(_onCreateRecognizerCommandReceived);
    killRecognizerPort.listen(_onKillRecognizerCommandReceived);
    createStreamPort.listen(_onCreateStreamCommandReceived);
    destroyStreamPort.listen(_onDestroyStreamCommandReceived);
    waveformStreamPort.listen(_onWaveformDataReceived);
    decodeWaveformPort.listen(_onDecodeWaveform);

    shutdownPort.listen((message) {
      if (message) {
        _onKillRecognizerCommandReceived(null);

        Isolate.current.kill();
      }
    });
    _recognizer = SherpaOnnxRecognizerImpl();

    _recognizer!.result.listen(_resultPort.send);
  }

  void _onCreateRecognizerCommandReceived(dynamic args) async {
    var sampleRate = args[0] as double;

    var chunkLengthInSecs = args[1] as double;

    String tokensPath = args[2];
    String encoderPath = args[3];
    String decoderPath = args[4];
    String joinerPath = args[5];
    var hotwordsScore = args[6] as double;
    var bufferLengthInSamples = args[7];

    print(
        "Creating recognizer with sampleRate $sampleRate, chunkLengthInSecs $chunkLengthInSecs, _bufferLengthInSamples $bufferLengthInSamples  ");

    var result = _recognizer!.createRecognizer(
        sampleRate: sampleRate,
        chunkLengthInSecs: chunkLengthInSecs,
        tokensPath: tokensPath,
        encoderPath: encoderPath,
        decoderPath: decoderPath,
        joinerPath: joinerPath,
        hotwordsScore: hotwordsScore,
        bufferLengthInSamples: bufferLengthInSamples);

    _createdRecognizerPort.send(result);
  }

  void _onCreateStreamCommandReceived(dynamic hotwords) {
    if (_recognizer == null) {
      print("No recognizer available, cannot create stream");
      _createdStreamPort.send(false);
      return;
    }

    var created = _recognizer!.createStream(hotwords as String?);
    _createdStreamPort.send(created);
  }

  void _onDecodeWaveform(dynamic data) async {
    var result = _recognizer!.decodeWaveform(data as Uint8List);
    _resultPort.send(result);
  }

  void _onWaveformDataReceived(dynamic data) async {
    _recognizer!.acceptWaveform(data as Uint8List);
  }

  void _onDestroyStreamCommandReceived(_) {
    _recognizer!.destroyStream();
  }

  void _onKillRecognizerCommandReceived(_) {
    _recognizer!.destroyRecognizer();
  }

  static SherpaOnnxIsolateRunner? current;
  static void create(List args) {
    SendPort setupPort = args[0];
    SendPort createdRecognizerPort = args[1];
    SendPort createdStreamPort = args[2];
    SendPort resultPort = args[3];
    SendPort spectrumPort = args[4];
    current = SherpaOnnxIsolateRunner(setupPort, createdRecognizerPort,
        createdStreamPort, resultPort, spectrumPort);
  }
}
