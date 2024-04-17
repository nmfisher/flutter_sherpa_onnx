import 'dart:typed_data';

///
/// A fixed-size, read-write buffer for raw audio data.
/// 
class AudioBuffer {

  int get lengthInBytes => _data.length;

  int _bytesWritten = 0;
  int get bytesWritten => _bytesWritten;

  late Uint8List _data;
  Uint8List get data => _data;

  int _sampleRate;
  double _lengthInSeconds;

  ///
  /// A buffer for raw audio data (PCM)
  ///
  AudioBuffer(this._sampleRate, this._lengthInSeconds) {
    _data = Uint8List((_sampleRate * 2 * _lengthInSeconds).toInt());
  }

  bool add(Uint8List data) {
    int added = 0;
    for (int i = 0; i < data.length; i++) {
      if (_bytesWritten + i >= _data.length - 1) {
        // if buffer is filled before writing all data, discard the remainder
        break;
      }

      _data[_bytesWritten + i] = data[i];
      added++;
    }
    _bytesWritten += added;

    return added == data.length;
  }

  Uint8List read(double offsetInSeconds, double lengthInSeconds) {
    var start = (offsetInSeconds * 2 * _sampleRate).toInt();
    var lengthInBytes = (lengthInSeconds * 2 * _sampleRate).toInt();
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
