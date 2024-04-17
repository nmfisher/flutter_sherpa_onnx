#include "include/flutter_sherpa_onnx/flutter_sherpa_onnx_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_sherpa_onnx_plugin.h"

void FlutterSherpaOnnxPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_sherpa_onnx::FlutterSherpaOnnxPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
