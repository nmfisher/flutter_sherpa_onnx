#import "FlutterSherpaOnnxPlugin.h"
#if __has_include(<flutter_sherpa_onnx/flutter_sherpa_onnx-Swift.h>)
#import <flutter_sherpa_onnx/flutter_sherpa_onnx-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
//#import "flutter_sherpa_onnx-Swift.h"
#endif

@implementation FlutterSherpaOnnxPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
    [SwiftFlutterSherpaOnnxPlugin registerWithRegistrar:registrar];
}
@end


