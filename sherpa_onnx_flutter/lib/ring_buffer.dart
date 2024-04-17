import 'dart:ffi';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

///
/// A ring buffer for writing Int16 byte data and reading into a Pointer<Float>. 
/// Writes can be any size, but reading must occur in chunks of [readSize] bytes.
/// Call [write] to write data to the buffer. If the end of the buffer is reached, the write will begin at index 0.
/// Call [read] to read from the buffer.
/// 
class RingBuffer {

  late Uint8List _data;

  int _readPointer = 0;
  int _writePointer = 0;

  late Pointer<Float> _output;

  late final int readSizeInSamples;
  late final int _readSizeInBytes;

  RingBuffer({required this.readSizeInSamples,required int lengthInBytes}) {
    _data = Uint8List(lengthInBytes);
    _output = calloc<Float>(readSizeInSamples);
    
    // to clarify, each read will convert [readSizeInSamples] int16 values to the same number of float32
    // therefore although we return a Pointer to a chunk of memory sized [readSizeInSamples * sizeOf<Float>()], 
    // internally, we are only reading [readSizeInSamples * sizeOf<Int16>()] at each step.
    _readSizeInBytes = readSizeInSamples * sizeOf<Int16>();

    print("Ring buffer length : $lengthInBytes bytes, read size : $_readSizeInBytes bytes / $readSizeInSamples samples");
  }

  void write(Uint8List data) {
    for (int i = 0; i < data.length; i++) {
      _data[(_writePointer + i) % _data.lengthInBytes] = data[i];
    }
    _writePointer += data.length;    
  }

  bool canRead() {
    return _readPointer + _readSizeInBytes <= _writePointer;
  }

  Pointer<Float> read() {
    for(int i = 0; i < readSizeInSamples; i++) {
      var int16Val = _data.buffer.asInt16List(_readPointer % _data.lengthInBytes).elementAt(0);
      _output.elementAt(i).value = int16Val / 32768.0;
      _readPointer += 2;
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
