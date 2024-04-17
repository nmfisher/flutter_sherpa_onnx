//
//  Generated file. Do not edit.
//

import FlutterMacOS
import Foundation

import audio_session
import flutter_ffi_asset_helper
import flutter_sherpa_onnx
import just_audio
import mic_stream
import path_provider_foundation
import record_darwin

func RegisterGeneratedPlugins(registry: FlutterPluginRegistry) {
  AudioSessionPlugin.register(with: registry.registrar(forPlugin: "AudioSessionPlugin"))
  FlutterFfiAssetHelperPlugin.register(with: registry.registrar(forPlugin: "FlutterFfiAssetHelperPlugin"))
  FlutterSherpaOnnxPlugin.register(with: registry.registrar(forPlugin: "FlutterSherpaOnnxPlugin"))
  JustAudioPlugin.register(with: registry.registrar(forPlugin: "JustAudioPlugin"))
  MicStreamPlugin.register(with: registry.registrar(forPlugin: "MicStreamPlugin"))
  PathProviderPlugin.register(with: registry.registrar(forPlugin: "PathProviderPlugin"))
  RecordPlugin.register(with: registry.registrar(forPlugin: "RecordPlugin"))
}
