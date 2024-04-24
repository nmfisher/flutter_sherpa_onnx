import 'dart:typed_data';

///
/// A fixed-size buffer for raw (16-bit PCM) audio data, with a method to retrieve audio segments based on timestamps.
///
class AudioBuffer {
  late Uint8List _data;
  final int _sampleRate;
  int get sampleRate => _sampleRate;

  int _bytesWritten = 0;
  int get written => _bytesWritten;

  AudioBuffer(this._sampleRate, {int capacityInSeconds = 30}) {
    _data = Uint8List(_sampleRate * 2 * capacityInSeconds);
  }

  AudioBuffer.fixed(this._data, this._sampleRate) {
    this._bytesWritten = _data.length;
  }

  Uint8List get data => _data.sublist(0, _bytesWritten);

  void add(Uint8List data) {
    int added = 0;
    for (int i = 0; i < data.length; i++) {
      if (_bytesWritten + i >= _data.length - 1) {
        throw Exception("Buffer overflow");
      }

      _data[_bytesWritten + i] = data[i];
      added++;
    }
    _bytesWritten += added;

    if (added != data.length) {
      throw Exception("Buffer overflow");
    }
  }

  Uint8List getSegment(double offsetInSeconds, double? lengthInSeconds) {
    var start = (offsetInSeconds * 2 * _sampleRate).toInt();
    late int lengthInBytes;

    if (lengthInSeconds == null) {
      lengthInBytes = _data.length - start;
    } else {
      lengthInBytes = (lengthInSeconds! * 2 * _sampleRate).toInt();
    }
    if (start + lengthInBytes > _data.length) {
      throw Exception(
          "Requested offset/length would exceed the size of the audio buffer");
    }
    return Uint8List.sublistView(_data, start, start + lengthInBytes);
  }

  void reset() {
    _bytesWritten = 0;
  }
}
