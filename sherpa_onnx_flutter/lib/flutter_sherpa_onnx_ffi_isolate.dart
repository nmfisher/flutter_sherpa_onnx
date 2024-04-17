import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';
import 'package:flutter_sherpa_onnx/ring_buffer.dart';

import 'package:path/path.dart' as p;

import './generated_bindings.dart';
import 'package:flutter/services.dart';

class FlutterSherpaOnnxFFIIsolateRunner {
  final SendPort _setupPort;

  final SendPort _createdRecognizerPort;
  final SendPort _createdStreamPort;
  final SendPort _resultPort;

  late final NativeLibrary _lib;

  RingBuffer? _buffer;

  int _CHUNK_LENGTH_MULTIPLE_FOR_BUFFER = 10;

  Pointer<SherpaOnnxOnlineRecognizer>? _recognizer;
  Pointer<SherpaOnnxOnlineStream>? _stream;

  int _chunkLengthInSamples = 0;

  Pointer<SherpaOnnxOnlineRecognizerConfig>? _config;

  FlutterSherpaOnnxFFIIsolateRunner(this._setupPort,
      this._createdRecognizerPort, this._createdStreamPort, this._resultPort) {
    var dataPort = ReceivePort();
    var createRecognizerPort = ReceivePort();
    var createStreamPort = ReceivePort();
    var killRecognizerPort = ReceivePort();

    var shutdownPort = ReceivePort();

    _setupPort.send([
      dataPort.sendPort,
      createRecognizerPort.sendPort,
      killRecognizerPort.sendPort,
      createStreamPort.sendPort,
      shutdownPort.sendPort,
    ]);

    createRecognizerPort.listen(_onCreateRecognizerCommandReceived);
    killRecognizerPort.listen(_onKillRecognizerCommandReceived);
    createStreamPort.listen(_onCreateStreamCommandReceived);

    dataPort.listen(_onWaveformDataReceived);

    shutdownPort.listen((message) {
      if (message) {
        _onKillRecognizerCommandReceived(null);

        _buffer?.dispose();
        Isolate.current.kill();
      }
    });
    if (Platform.isAndroid || Platform.isLinux) {
      _lib = NativeLibrary(
          DynamicLibrary.open("libflutter_sherpa_onnx_plugin.so"));
    } else if (Platform.isWindows) {
      var path = p.join(File(Platform.resolvedExecutable).parent.path,
          "sherpa-onnx-c-api.dll");
      _lib = NativeLibrary(DynamicLibrary.open(path));
    } else {
      _lib = NativeLibrary(DynamicLibrary.process());
    }
  }

  int? _sampleRate;
  void _onCreateRecognizerCommandReceived(dynamic args) async {
    if (_recognizer != null) {
      throw Exception(
          "Recognizer already exists, make sure to call kill first.");
    }

    var sampleRate = args[0] as double;
    _sampleRate = sampleRate.toInt();

    var chunkLengthInSecs = args[1] as double;
    print(
        "Creating recognizer with sampleRate $sampleRate/chunkLengthInSecs $chunkLengthInSecs  ");
    String tokensPath = args[2];
    String encoderPath = args[3];
    String decoderPath = args[4];
    String joinerPath = args[5];
    var hotwordsScore = args[6] as double;

    var newChunkLengthInSamples = (chunkLengthInSecs * sampleRate);

    if (newChunkLengthInSamples != _chunkLengthInSamples) {
      _chunkLengthInSamples = newChunkLengthInSamples.toInt();

      _buffer?.dispose();

      // when [_onWaveformDataReceived] is called, we will wait until at least [_chunkLengthInSamples] samples are available before passing to the decoder
      // this means each call will write [bufferSizeInSamples] samples to a temporary storage buffer
      // this buffer must be large enough to avoid read/write under/overflow (i.e. so we can write ahead of the current read position).
      // reads will be some multiple of _chunkLengthInSamples
      // write sizes will be variable on certain platforms (e.g. Windows) as these do not have a fixed hardware buffer size
      // we therefore size our RingBuffer to some multiple of _chunkLengthInSamples
      _buffer = RingBuffer(
          readSizeInSamples: _chunkLengthInSamples,
          lengthInBytes: _chunkLengthInSamples *
              _CHUNK_LENGTH_MULTIPLE_FOR_BUFFER *
              sizeOf<Int16>());
    }

    print("Using chunk length in samples : $_chunkLengthInSamples ");

    _config = calloc<SherpaOnnxOnlineRecognizerConfig>();

    _config!.ref.model_config.debug = 1;
    _config!.ref.model_config.num_threads = 1;
    var provider = "cpu";
    // var decodingMethod = "greedy_search";
    var decodingMethod = "modified_beam_search";
    _config!.ref.model_config.provider = provider.toNativeUtf8().cast<Char>();

    _config!.ref.decoding_method = decodingMethod.toNativeUtf8().cast<Char>();

    _config!.ref.max_active_paths = 4;

    _config!.ref.feat_config.sample_rate = 16000;
    _config!.ref.feat_config.feature_dim = 80;

    _config!.ref.enable_endpoint = 1;
    _config!.ref.rule1_min_trailing_silence = 2.4;
    _config!.ref.rule2_min_trailing_silence = 1.2;
    _config!.ref.rule3_min_utterance_length = 300;

    _config!.ref.model_config.model_type = nullptr;
    _config!.ref.model_config.tokens = tokensPath.toNativeUtf8().cast<Char>();
    _config!.ref.model_config.paraformer.encoder = nullptr;
    _config!.ref.model_config.paraformer.decoder = nullptr;
    _config!.ref.model_config.transducer.encoder =
        encoderPath.toNativeUtf8().cast<Char>();
    _config!.ref.model_config.transducer.decoder =
        decoderPath.toNativeUtf8().cast<Char>();
    _config!.ref.model_config.transducer.joiner =
        joinerPath.toNativeUtf8().cast<Char>();

    var hotwords = "";
    _config!.ref.hotwords_file = hotwords.toNativeUtf8().cast<Char>();
    _config!.ref.hotwords_score = hotwordsScore;

    _recognizer = _lib.CreateOnlineRecognizer(_config!);

    _createdRecognizerPort.send(_recognizer != nullptr);
  }

  bool isReadyForInput() {
    return _recognizer != null && _stream != null && _sampleRate != null;
  }

  void _onCreateStreamCommandReceived(dynamic hotwords) {
    if (_recognizer == null) {
      print("No recognizer available, cannot create stream");
      _createdStreamPort.send(false);
      return;
    }
    _readPointer = 0;
    _writePointer = 0;
    if (_stream != null) {
      _lib.DestroyOnlineStream(_stream!);
    }
    if (hotwords == null) {
      _stream = _lib.CreateOnlineStream(_recognizer!);
    } else {
      String hotwordsString = hotwords as String;
      _stream = _lib.CreateOnlineStreamWithHotwords(
          _recognizer!, hotwordsString.toNativeUtf8().cast<Char>());
    }
    _lib.Reset(_recognizer!, _stream!);
    _createdStreamPort.send(_stream != nullptr);
  }

  int _readPointer = 0;
  int _writePointer = 0;

  void _onWaveformDataReceived(dynamic data) async {
    _buffer!.write(data as Uint8List);

    if (!_buffer!.canRead()) {
      return;
    }
    var floatPtr = _buffer!.read();

    _lib.AcceptWaveform(
        _stream!, _sampleRate!, floatPtr, _chunkLengthInSamples);

    while (_lib.IsOnlineStreamReady(_recognizer!, _stream!) == 1) {
      _lib.DecodeOnlineStream(_recognizer!, _stream!);
    }

    var result = _lib.GetOnlineStreamResult(_recognizer!, _stream!);
    var isEndpoint = _lib.IsEndpoint(_recognizer!, _stream!) == 1;

    if (result != nullptr) {
      if (result.ref.json != nullptr) {
        var dartString = result.ref.json.cast<Utf8>().toDartString();
        _resultPort.send(dartString.substring(0, dartString.length - 1) +
            ", \"is_endpoint\":$isEndpoint}");
      }
      _lib.DestroyOnlineRecognizerResult(result);
    }

    if (isEndpoint) {
      _lib.Reset(_recognizer!, _stream!);
    }
  }

  void _onKillRecognizerCommandReceived(_) {
    if (_stream != null) {
      _lib.DestroyOnlineStream(_stream!);
    }
    if (_recognizer != null) {
      _lib.DestroyOnlineRecognizer(_recognizer!);
    }
    _stream = null;
    _recognizer = null;
  }

  static void create(List args) {
    SendPort setupPort = args[0];
    SendPort createdRecognizerPort = args[1];
    SendPort createdStreamPort = args[2];
    SendPort resultPort = args[3];
    BackgroundIsolateBinaryMessenger.ensureInitialized(
        args[4] as RootIsolateToken);
    var runner = FlutterSherpaOnnxFFIIsolateRunner(
        setupPort, createdRecognizerPort, createdStreamPort, resultPort);
  }
}
