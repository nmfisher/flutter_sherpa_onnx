# Dart Sherpa-ONNX

A Dart package to use the [k2/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) speech recognition platform.

> ⛔ NOTE ⛔
> There is now an official Dart/Flutter package published in the `sherpa-onnx` repository.
> I strongly suggest you use that instead.
> 

See `examples/flutter` for how to integrate this into a running Flutter application (basically, you just need to pass a stream of 16-bit PCM encoded data).

This is undergoing some heavy restructuring at the moment so things may be a bit disorderly.

## Example (Dart)

```
dart --enable-experiment=native-assets run examples/dart/sherpa_onnx_dart_example.dart
```

## Example (Flutter)
```
cd examples/flutter && flutter run -d <your_device>
```

## ONNXRuntime

You need to provide compiled libraries/frameworks for the ONNX Runtime.

The easiest way is to use the version I have uploaded here.

## Usage (Dart)

## Usage (Flutter)

Some extra steps are required to use this in a Flutter app.



### iOS

```
open ios/Runner.xcworkspace
```
Set FRAMEWORK_SEARCH_PATHS to the folder 

