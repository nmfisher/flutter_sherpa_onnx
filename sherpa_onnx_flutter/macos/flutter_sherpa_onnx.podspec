#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_sherpa_onnx.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_sherpa_onnx'
  s.version          = '0.0.1'
  s.summary          = 'A new Flutter plugin project.'
  s.description      = <<-DESC
A new Flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }

  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*'
  s.dependency 'FlutterMacOS'

  s.platform = :osx, '13'
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES' }
  s.swift_version = '5.0'
  s.library = 'c++'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',     
    "FRAMEWORK_SEARCH_PATHS" => '"${PODS_TARGET_SRCROOT}/../../flutter_onnx/macos/lib"',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/include" "$(inherited)"',
    'OTHER_LDFLAGS' => '-v -framework Accelerate -framework onnxruntime -lsherpa-onnx-fst -force_load ${PODS_TARGET_SRCROOT}/lib/libsherpa-onnx-fst.a -lsherpa-onnx-c-api -force_load ${PODS_TARGET_SRCROOT}/lib/libsherpa-onnx-c-api.a -lsherpa-onnx-core -force_load ${PODS_TARGET_SRCROOT}/lib/libsherpa-onnx-core.a -lkaldi-decoder-core -force_load ${PODS_TARGET_SRCROOT}/lib/libkaldi-decoder-core.a -lkaldi-native-fbank-core -force_load ${PODS_TARGET_SRCROOT}/lib/libkaldi-native-fbank-core.a -lsherpa-onnx-kaldifst-core -force_load ${PODS_TARGET_SRCROOT}/lib/libsherpa-onnx-kaldifst-core.a -lcargs -force_load ${PODS_TARGET_SRCROOT}/lib/libcargs.a $(inherited)',
    'LIBRARY_SEARCH_PATHS' => '"${PODS_TARGET_SRCROOT}/lib" "$(inherited)"',
  }
end
