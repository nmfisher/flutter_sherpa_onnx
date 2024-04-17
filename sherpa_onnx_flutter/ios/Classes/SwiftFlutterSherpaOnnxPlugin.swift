import Flutter
import UIKit

public class SwiftFlutterSherpaOnnxPlugin: NSObject, FlutterPlugin {

  var registrar: FlutterPluginRegistrar? = nil
  var channel:FlutterMethodChannel
  
  init(channel:FlutterMethodChannel) {
    self.channel = channel
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "app.polyvox.flutter_sherpa_onnx", binaryMessenger: registrar.messenger())
    let instance = SwiftFlutterSherpaOnnxPlugin(channel:channel)
    instance.registrar = registrar
    registrar.addMethodCallDelegate(instance, channel: channel)
  }
    
}
