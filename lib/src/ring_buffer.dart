import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

///
/// A ring buffer for writing Int16 byte data and reading into a Pointer<Float>.
/// Writes can be any size, but reading must occur in chunks of [readSize] bytes.
/// write(..) will write data to the buffer
/// (internally, if the end of the backing buffer is reached, the write will begin at index 0, but reads will return a pointer to a contiguous block of memory).
/// Call [read] to read from the buffer.
///
class RingBuffer {
  int _readPointer = 0;
  int _writePointer = 0;

  late Float32List _buf;
  late Pointer<Float> _output;

  late final int readSizeInSamples;

  RingBuffer({required this.readSizeInSamples, required int bufferFactor}) {
    _buf = Float32List(bufferFactor * readSizeInSamples);
    _output = calloc<Float>(readSizeInSamples);
  }

  List<double> write(Uint8List data) {
    var offset = data.offsetInBytes;
    if (offset % 2 != 0) {
      offset++;
    }
    // var length = (data.length - offset) ~/ 2;
    var floatData = Int16List.sublistView(data)
        .map((x) => x / 32768.0)
        .cast<double>()
        .toList();

    for (int i = 0; i < floatData.length; i++) {
      _buf[(_writePointer + i) % _buf.length] = floatData[i];
    }
    _writePointer += floatData.length;
    return floatData;
  }

  bool canRead() {
    return _readPointer + readSizeInSamples <= _writePointer;
  }

  Pointer<Float> read() {
    for (int i = 0; i < readSizeInSamples; i++) {
      _output[i] = _buf[_readPointer % _buf.length];
      _readPointer++;
    }
    return _output;
  }

  void reset() {
    _writePointer = 0;
    _readPointer = 0;
  }

  void dispose() {
    calloc.free(_output);
  }
}
