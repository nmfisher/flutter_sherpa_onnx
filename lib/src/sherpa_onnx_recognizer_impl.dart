import 'dart:async';

import 'package:fftea/impl.dart';
import 'dart:ffi';

import 'dart:typed_data';
import 'package:ffi/ffi.dart';

import 'package:fftea/util.dart';

import 'package:sherpa_onnx_dart/src/ring_buffer.dart';
import 'package:sherpa_onnx_dart/src/sherpa_onnx_dart.g.dart';
import 'package:sherpa_onnx_dart/src/sherpa_onnx_recognizer.dart';

class SherpaOnnxRecognizerImpl extends SherpaOnnxRecognizer {
  final ready = Future<bool>.value(true);

  final _resultController = StreamController<String?>.broadcast();
  Stream<String?> get result => _resultController.stream;

  RingBuffer? _buffer;

  int _CHUNK_LENGTH_MULTIPLE_FOR_BUFFER = 10;

  static Pointer<SherpaOnnxOnlineRecognizer>? _recognizer;
  static Pointer<SherpaOnnxOnlineStream>? _stream;

  int _chunkLengthInSamples = 0;

  Pointer<SherpaOnnxOnlineRecognizerConfig>? _config;

  late final FFT _fft;

  int? _sampleRate;
  int? _bufferLengthInSamples;

  @override
  Stream<Float64List?> get spectrum => _spectrumController.stream;

  final _spectrumController = StreamController<Float64List?>.broadcast();

  @override
  Future dispose() async {
    _buffer?.dispose();
    await _spectrumController.close();
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
      int? bufferLengthInSamples,
      double minTrailingSilence1 = 2.4,
      double minTrailingSilence2 = 1.2}) async {
    if (_recognizer != null) {
      throw Exception(
          "Recognizer already exists, make sure to call kill first.");
    }

    _bufferLengthInSamples = bufferLengthInSamples;

    _sampleRate = sampleRate.toInt();

    print(
        "Creating recognizer with sampleRate $sampleRate, chunkLengthInSecs $chunkLengthInSecs, _bufferLengthInSamples $_bufferLengthInSamples  ");

    var newChunkLengthInSamples = (chunkLengthInSecs * sampleRate);

    if (newChunkLengthInSamples != _chunkLengthInSamples) {
      _chunkLengthInSamples = newChunkLengthInSamples.toInt();

      _buffer?.dispose();

      // when [_onWaveformDataReceived] is called, we will wait until at least [_chunkLengthInSamples] samples are available before passing to the decoder
      // this means each call will write [bufferLengthInSamples] samples to a temporary storage buffer
      // this buffer must be large enough to avoid read/write under/overflow (i.e. so we can write ahead of the current read position).
      // reads will be some multiple of _chunkLengthInSamples
      // write sizes will be variable on certain platforms (e.g. Windows) as these do not have a fixed hardware buffer size
      // we therefore size our RingBuffer to some multiple of _chunkLengthInSamples
      _buffer = RingBuffer(
          readSizeInSamples: _chunkLengthInSamples,
          bufferFactor: _CHUNK_LENGTH_MULTIPLE_FOR_BUFFER);
      if (_bufferLengthInSamples == null) {
        throw Exception("TODO");
      }
      _fft = FFT(_bufferLengthInSamples!);
      print("Created FFT of size ${_bufferLengthInSamples}");
    }

    print("Using chunk length in samples : $_chunkLengthInSamples ");

    _config = calloc<SherpaOnnxOnlineRecognizerConfig>();

    _config!.ref.model_config.debug = 1;
    _config!.ref.model_config.num_threads = 1;
    var provider = "cpu";
    var providerPtr = provider.toNativeUtf8(allocator: calloc).cast<Char>();
    // var decodingMethod = "greedy_search";
    var decodingMethod = "modified_beam_search";
    var decodingMethodPtr =
        decodingMethod.toNativeUtf8(allocator: calloc).cast<Char>();
    _config!.ref.model_config.provider = providerPtr;

    _config!.ref.decoding_method = decodingMethodPtr = decodingMethodPtr;

    _config!.ref.max_active_paths = 4;

    _config!.ref.feat_config.sample_rate = 16000;
    _config!.ref.feat_config.feature_dim = 80;

    _config!.ref.enable_endpoint = 1;
    _config!.ref.rule1_min_trailing_silence = minTrailingSilence1;
    _config!.ref.rule2_min_trailing_silence = minTrailingSilence2;
    _config!.ref.rule3_min_utterance_length = 300;

    _config!.ref.model_config.model_type = nullptr;
    _config!.ref.model_config.tokens =
        tokensPath.toNativeUtf8(allocator: calloc).cast<Char>();
    _config!.ref.model_config.paraformer.encoder = nullptr;
    _config!.ref.model_config.paraformer.decoder = nullptr;

    var encoderPathPtr =
        encoderPath.toNativeUtf8(allocator: calloc).cast<Char>();
    _config!.ref.model_config.transducer.encoder = encoderPathPtr;
    var decoderPathPtr =
        decoderPath.toNativeUtf8(allocator: calloc).cast<Char>();
    _config!.ref.model_config.transducer.decoder = decoderPathPtr;
    var joinerPathPtr = joinerPath.toNativeUtf8(allocator: calloc).cast<Char>();
    _config!.ref.model_config.transducer.joiner = joinerPathPtr;

    var hotwords = "";
    var hotwordsPathPtr = hotwords.toNativeUtf8(allocator: calloc).cast<Char>();

    _config!.ref.hotwords_file = hotwordsPathPtr;

    _config!.ref.hotwords_score = hotwordsScore;

    _recognizer = CreateOnlineRecognizer(_config!);

    for (var ptr in [
      hotwordsPathPtr,
      joinerPathPtr,
      decoderPathPtr,
      encoderPathPtr,
      decodingMethodPtr,
      providerPtr
    ]) {
      calloc.free(ptr);
    }
    return _recognizer != nullptr;
  }

  @override
  bool isReadyForInput() {
    return _recognizer != null && _stream != null && _sampleRate != null;
  }

  @override
  Future<bool> createStream(String? hotwords) async {
    if (_recognizer == null) {
      print("No recognizer available, cannot create stream");
      return false;
    }

    if (_stream != null) {
      DestroyOnlineStream(_stream!);
    }
    if (hotwords == null) {
      _stream = CreateOnlineStream(_recognizer!);
    } else {
      String hotwordsString = hotwords as String;
      _stream = CreateOnlineStreamWithHotwords(_recognizer!,
          hotwordsString.toNativeUtf8(allocator: calloc).cast<Char>());
    }
    Reset(_recognizer!, _stream!);
    _buffer!.reset();
    return _stream != nullptr;
  }

  @override
  Future<String?> decodeWaveform(Uint8List data) async {
    if (_stream == null) {
      createStream(null);
    }
    final shortData = data.buffer.asInt16List(data.offsetInBytes);

    var floatPtr = calloc<Float>(shortData.length);
    for (int i = 0; i < shortData.length; i++) {
      floatPtr[i] = shortData[i] / 32768;
    }
    AcceptWaveform(_stream!, _sampleRate!, floatPtr, shortData.length);

    while (IsOnlineStreamReady(_recognizer!, _stream!) == 1) {
      DecodeOnlineStream(_recognizer!, _stream!);
    }

    var result = GetOnlineStreamResult(_recognizer!, _stream!);

    var isEndpoint = IsEndpoint(_recognizer!, _stream!) == 1;

    String? resultString;

    if (result != nullptr) {
      if (result.ref.json != nullptr) {
        var dartString = result.ref.json.cast<Utf8>().toDartString();
        resultString =
            "${dartString.substring(0, dartString.length - 1)}, \"is_endpoint\":$isEndpoint}";
      }
    }
    DestroyOnlineRecognizerResult(result);
    return resultString;
  }

  @override
  void acceptWaveform(Uint8List data) {
    var written = _buffer!.write(data);

    if (written.length >= _bufferLengthInSamples!) {
      var spectrum =
          _fft.realFft(written.take(_bufferLengthInSamples!).toList());
      _spectrumController.add(spectrum.toRealArray());
    }

    if (!_buffer!.canRead()) {
      return;
    }

    var floatPtr = _buffer!.read();

    AcceptWaveform(_stream!, _sampleRate!, floatPtr, _chunkLengthInSamples);

    while (IsOnlineStreamReady(_recognizer!, _stream!) == 1) {
      DecodeOnlineStream(_recognizer!, _stream!);
    }

    var result = GetOnlineStreamResult(_recognizer!, _stream!);
    var isEndpoint = IsEndpoint(_recognizer!, _stream!) == 1;

    String? resultString;

    if (result != nullptr) {
      if (result.ref.json != nullptr) {
        var dartString = result.ref.json.cast<Utf8>().toDartString();

        resultString =
            "${dartString.substring(0, dartString.length - 1)}, \"is_endpoint\":$isEndpoint}";
      }
      DestroyOnlineRecognizerResult(result);
    }

    if (isEndpoint) {
      Reset(_recognizer!, _stream!);
    }
    _resultController.add(resultString);
  }

  @override
  Future destroyStream() async {
    if (_stream != null) {
      DestroyOnlineStream(_stream!);
      _stream = null;
    }
  }

  @override
  Future destroyRecognizer() async {
    if (_stream != null) {
      DestroyOnlineStream(_stream!);
    }
    if (_recognizer != null) {
      DestroyOnlineRecognizer(_recognizer!);
    }
    _stream = null;
    _recognizer = null;
  }
}
