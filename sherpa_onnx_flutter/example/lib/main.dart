import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_sherpa_onnx/flutter_sherpa_onnx_ffi.dart';
import 'package:audio_session/audio_session.dart';
import 'dart:async';
import 'package:permission_handler/permission_handler.dart';
import 'package:mic_stream/mic_stream.dart';
import 'package:path_provider/path_provider.dart';
import 'package:wave_builder/wave_builder.dart';
import 'package:record/record.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  bool _micConfigured = false;

  bool _hasRecognizer = false;

  StreamSubscription<ASRResult>? _listener;
  final _results = <ASRResult>[];
  String? _partial;
  String? _decoded;
  late double microphoneSampleRate;

  late FlutterSherpaOnnxFFI plugin;

  @override
  void initState() {
    plugin = FlutterSherpaOnnxFFI();
    plugin.result.listen((result) {
      var string = _partial = result.words.map((w) => w.word).join("");
      if (result.isFinal) {
        _partial = null;
        _decoded = string;
      } else {
        _partial = string;
        _decoded = null;
      }
      setState(() {});
    });

    super.initState();
  }

  void _configureMicrophone() async {
    if (Platform.isWindows || Platform.isMacOS) {
      final record = AudioRecorder();
      final config =
          const RecordConfig(encoder: AudioEncoder.pcm16bits, numChannels: 1);
      microphoneSampleRate = config.sampleRate.toDouble();
      final stream = await record.startStream(config);
    } else if (!Platform.isLinux) {
      final session = await AudioSession.instance;
      await session.configure(AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playAndRecord,
        avAudioSessionMode: AVAudioSessionMode.spokenAudio,
        avAudioSessionRouteSharingPolicy:
            AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
      ));

      var mic = await MicStream.microphone(
          audioFormat: AudioFormat.ENCODING_PCM_16BIT,
          sampleRate: Platform.isMacOS ? 48000 : 16000);

      var listener = mic!.listen((event) {});
      listener.cancel();

      var microphone = (await MicStream.microphone(
          audioFormat: AudioFormat.ENCODING_PCM_16BIT))!;

      microphoneSampleRate = (await MicStream.sampleRate)!.toDouble();

      microphone.listen(_handleMicrophoneInput);
    } else {
      throw Exception("TODO");
    }

    setState(() {
      _micConfigured = true;
    });
  }

  void createRecognizer(double sampleRate) async {
    await plugin.createRecognizer(
        sampleRate,
        0.1,
        "assets/asr/tokens.txt",
        "assets/asr/encoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
        "assets/asr/decoder-epoch-99-avg-1.int8.with_runtime_opt.ort",
        "assets/asr/joiner-epoch-99-avg-1.int8.with_runtime_opt.ort");

    setState(() {
      _decoded = "";
      _hasRecognizer = true;
    });
  }

  void destroyRecognizer() async {
    await stopListening();
    await plugin.destroyRecognizer();
    setState(() {
      _hasRecognizer = false;
    });
  }

  bool _listening = false;

  void _handleMicrophoneInput(Uint8List data) async {
    if (!_listening) {
      return;
    }
    plugin.acceptWaveform(data);
  }

  ///
  /// Immediately ignore all audio from the microphone.
  ///
  Future stopListening() async {
    print("Pausing pipeline");
    _listening = false;
  }

  ///
  /// Instructs the underlying pipeline to start (or resume) processing data from the microphone.
  ///
  void listen() async {
    print("Unpausing pipeline");
    _listening = true;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
            appBar: AppBar(
              title: const Text('Plugin example app'),
            ),
            body: Wrap(children: [
              ElevatedButton(
                  onPressed: () {
                    _configureMicrophone();
                  },
                  child: const Text("Initialize microphone")),
              ElevatedButton(
                  child: const Text("Create Recognizer"),
                  onPressed: !_hasRecognizer
                      ? () async {
                          createRecognizer(microphoneSampleRate);
                        }
                      : null),
              ElevatedButton(
                  child: const Text("Create stream (no hotwords)"),
                  onPressed: _hasRecognizer
                      ? () async {
                          await plugin.createStream(null);
                        }
                      : null),
              ElevatedButton(
                  child: const Text("Create stream (hotwords)"),
                  onPressed: _hasRecognizer
                      ? () async {
                          await plugin.createStream(["会 话"]);
                        }
                      : null),
              ElevatedButton(
                  child: const Text("Start microphone"),
                  onPressed: _hasRecognizer && _micConfigured
                      ? () async {
                          _results.clear();
                          listen();
                        }
                      : null),
              ElevatedButton(
                  child: const Text("Play source audio from transcription"),
                  onPressed: _results.isNotEmpty
                      ? () async {
                          for (int i = 0; i < _results.length; i++) {
                            for (final word in _results[i].words) {
                              var file = File(
                                  (await getTemporaryDirectory()).path +
                                      "/test.wav");
                              print(
                                  "Word ${word.word} start: ${word.start} end: ${word.end}");
                              var waveBuilder = WaveBuilder(
                                  frequency:
                                      (await MicStream.sampleRate)!.toInt(),
                                  stereo: false);
                              // var data = _results[i].getAudio(word);
                              // waveBuilder.appendFileContents(data);

                              // file.writeAsBytesSync(waveBuilder.fileBytes);

                              // final player = AudioPlayer();
                              // final comp = Completer();
                              // player.playerStateStream.listen((event) {
                              //   if (event.processingState ==
                              //       ProcessingState.completed) {
                              //     comp.complete();
                              //   }
                              // });
                              // player.setVolume(100.0);
                              // player.setFilePath(file.path, preload: true);
                              // await player.play();
                              // await comp.future;
                            }
                          }
                        }
                      : null),
              ElevatedButton(
                  child: const Text("Destroy Recognizer"),
                  onPressed: _hasRecognizer
                      ? () async {
                          await _listener?.cancel();
                          destroyRecognizer();
                        }
                      : null),
              ElevatedButton(
                  child: const Text("Stop listening"),
                  onPressed: _hasRecognizer
                      ? () async {
                          _listener?.cancel();
                          stopListening();
                        }
                      : null),
              ElevatedButton(
                  child: const Text("Decode from buffer"),
                  onPressed: _hasRecognizer
                      ? () async {
                          throw Exception("TODO");
                        }
                      : null),
              ElevatedButton(
                  child: const Text("Decode from file"),
                  onPressed: _hasRecognizer
                      ? () async {
                          setState(() {
                            _decoded = "";
                          });
                          // var bd = await rootBundle.load("assets/test.wav");
                          // var decoded = await _flutterVosk.acceptWaveform(
                          //     _hasRecognizer!,
                          //     bd.buffer.asUint8List(bd.offsetInBytes));

                          // setState(() {
                          //   _decoded =
                          //       decoded?["result"] ?? decoded?["partial"];
                          // });
                          // TODO - we moved the sample project to use Transcriber rather than FlutterSherpaOnnx directly, so decodeBuffer isn't available
                        }
                      : null),
              Text("PARTIAL: $_partial"),
              Text(_decoded ?? "")
            ])));
  }
}
