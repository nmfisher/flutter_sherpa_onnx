import 'dart:io';
import 'dart:math';

import 'dart:ffi';
import 'package:ffi/ffi.dart';
import 'package:sherpa_onnx_dart/src/ring_buffer.dart';
import 'package:test/test.dart';

void main() {
  var tol = 0.0001;

  var outfile = File("test/output.pcm");

  setUp(() {
    if (outfile.existsSync()) {
      outfile.deleteSync();
    }
  });

  // tearDown(() {
  //   if(outfile.existsSync()) {
  //     outfile.deleteSync();
  //   }
  // });

  test('canRead returns false when no data written', () {
    final rBuffer = RingBuffer(readSizeInSamples: 1, bufferFactor: 8);
    expect(rBuffer.canRead(), false);
  });

  test('write/read data to the buffer without wraparound', () {
    final rBuffer = RingBuffer(readSizeInSamples: 1, bufferFactor: 8);
    final data = calloc<Int16>(4);
    data.elementAt(0).value = 1;
    data.elementAt(1).value = 2;
    data.elementAt(2).value = 3;
    data.elementAt(3).value = 4;
    expect(data.asTypedList(4).offsetInBytes, 0);
    var input = data.asTypedList(4).buffer.asUint8List();
    expect(input.length, 8);
    expect(input[0] | input[1] << 8, 1);
    expect(input[2] | input[3] << 8, 2);

    rBuffer.write(input);
    expect(rBuffer.canRead(), true);

    expect(rBuffer.read().value - (1 / 32768.0) < tol, true);
    expect(rBuffer.read().value - (2 / 32768.0) < tol, true);
    expect(rBuffer.read().value - (3 / 32768.0) < tol, true);
    expect(rBuffer.read().value - (4 / 32768.0) < tol, true);
  });

  test('write/read data to the buffer with wraparound', () {
    final data = calloc<Int16>(8);
    for (int i = 0; i < 8; i++) {
      data.elementAt(i).value = i + 1;
    }

    final rBuffer = RingBuffer(readSizeInSamples: 1, bufferFactor: 8);
    // write the first 8 bytes
    rBuffer.write(data.asTypedList(4).buffer.asUint8List());
    expect(rBuffer.canRead(), true);

    expect(rBuffer.read().value - (1 / 32768.0) < tol, true);
    expect(rBuffer.read().value - (2 / 32768.0) < tol, true);
    expect(rBuffer.read().value - (3 / 32768.0) < tol, true);
    expect(rBuffer.read().value - (4 / 32768.0) < tol, true);

    // write the next 8 bytes
    rBuffer.write(data.elementAt(4).asTypedList(4).buffer.asUint8List());
    expect(rBuffer.canRead(), true);
    expect(rBuffer.read().value - (5 / 32768.0) < tol, true);
    expect(rBuffer.read().value - (6 / 32768.0) < tol, true);
    expect(rBuffer.read().value - (7 / 32768.0) < tol, true);
    expect(rBuffer.read().value - (8 / 32768.0) < tol, true);
  });

  test('different size writes/reads data to the buffer with wraparound', () {
    final data = calloc<Int16>(8);
    for (int i = 0; i < 8; i++) {
      data.elementAt(i).value = i + 1;
    }

    final rBuffer = RingBuffer(readSizeInSamples: 2, bufferFactor: 8);

    // write 2 bytes
    rBuffer.write(data.asTypedList(1).buffer.asUint8List());
    // insufficient for reading
    expect(rBuffer.canRead(), false);

    // write the next 2 bytes
    rBuffer.write(data.elementAt(1).asTypedList(1).buffer.asUint8List());
    // now can read 2 floats (i.e. 2 int16 == 4 bytes)
    expect(rBuffer.canRead(), true);
    var readPtr = rBuffer.read();
    expect(readPtr.value - (1 / 32768.0) < tol, true);
    expect(readPtr.elementAt(1).value - (2 / 32768.0) < tol, true);
    expect(rBuffer.canRead(), false);

    // write the next 2 bytes
    rBuffer.write(data.elementAt(2).asTypedList(1).buffer.asUint8List());
    // insufficient for reading
    expect(rBuffer.canRead(), false);

    // write the next 2 bytes
    rBuffer.write(data.elementAt(3).asTypedList(1).buffer.asUint8List());
    // now can read 4 bytes == 1 float
    expect(rBuffer.canRead(), true);
    readPtr = rBuffer.read();
    expect(readPtr.value - (3 / 32768.0) < tol, true);
    expect(readPtr.elementAt(1).value - (4 / 32768.0) < tol, true);
  });

  test('write/read from entire file', () {
    final pcmData = File("example/test.pcm").readAsBytesSync();
    final rBuffer =
        RingBuffer(readSizeInSamples: pcmData.length ~/ 2, bufferFactor: 1);
    rBuffer.write(pcmData);
    expect(rBuffer.canRead(), true);
    final pointer = rBuffer.read();

    outfile.writeAsBytesSync(
        pointer.asTypedList(pcmData.length ~/ 2).buffer.asUint8List());
  });

  test('write from entire file & read back in chunks', () {
    final pcmData = File("example/test.pcm").readAsBytesSync();
    final rBuffer = RingBuffer(readSizeInSamples: 1024, bufferFactor: 2);
    rBuffer.write(pcmData);

    while (rBuffer.canRead()) {
      final pointer = rBuffer.read();
      var buf = pointer.asTypedList(1024).buffer.asUint8List();
      expect(buf.length, 1024 * 4);
      outfile.writeAsBytesSync(buf, mode: FileMode.append);
    }
  });

  test('write file in chunks & read back in entirety', () {
    final pcmData = File("example/test.pcm").readAsBytesSync();

    final rBuffer =
        RingBuffer(readSizeInSamples: pcmData.length ~/ 2, bufferFactor: 8);

    for (int i = 0; i < pcmData.length; i += 1024) {
      rBuffer.write(pcmData.sublist(i, min(i + 1024, pcmData.length)));
    }
    expect(rBuffer.canRead(), true);
    final pointer = rBuffer.read();
    var buf = pointer.asTypedList(pcmData.length ~/ 2).buffer.asUint8List();
    outfile.writeAsBytesSync(buf, mode: FileMode.append);
  });
}
