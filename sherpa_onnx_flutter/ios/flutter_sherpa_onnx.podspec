#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint flutter_sherpa_onnx.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'flutter_sherpa_onnx'
  s.version          = '0.0.1'
  s.summary          = 'A new flutter plugin project.'
  s.description      = <<-DESC
A new flutter plugin project.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*.*', 'include/*.h'
  s.public_header_files = 'include/*.h'
  s.static_framework = true
  s.dependency 'Flutter'
  s.platform = :ios, '9.0'

  s.pod_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',     
    "FRAMEWORK_SEARCH_PATHS" => '"${PODS_ROOT}/../../flutter_onnx/ios/lib" "${PODS_ROOT}/../../../../flutter_onnx/ios/lib" "${PODS_ROOT}/../flutter_onnx/ios/lib" "$(inherited)"',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/include" "$(inherited)"',
    'OTHER_LDFLAGS' => '-v -framework Accelerate -framework onnxruntime -L${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/ -lsherpa-onnx-fst -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libsherpa-onnx-fst.a -lsherpa-onnx-c-api -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libsherpa-onnx-c-api.a -lsherpa-onnx-core -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libsherpa-onnx-core.a -lkaldi-decoder-core -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libkaldi-decoder-core.a -lkaldi-native-fbank-core -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libkaldi-native-fbank-core.a -lsherpa-onnx-kaldifst-core -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libsherpa-onnx-kaldifst-core.a $(inherited)'
  }
  s.user_target_xcconfig = { 
    'DEFINES_MODULE' => 'YES', 
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',     
    "FRAMEWORK_SEARCH_PATHS" => '"${PODS_ROOT}/../../flutter_onnx/ios/lib" "${PODS_ROOT}/../../../../flutter_onnx/ios/lib" "${PODS_ROOT}/../flutter_onnx/ios/lib" "$(inherited)"',
    'USER_HEADER_SEARCH_PATHS' => '"${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/include" "$(inherited)"',
    'OTHER_LDFLAGS' => '-v -framework Accelerate -framework onnxruntime -L${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/ -lsherpa-onnx-fst -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libsherpa-onnx-fst.a -lsherpa-onnx-c-api -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libsherpa-onnx-c-api.a -lsherpa-onnx-core -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libsherpa-onnx-core.a -lkaldi-decoder-core -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libkaldi-decoder-core.a -lkaldi-native-fbank-core -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libkaldi-native-fbank-core.a -lsherpa-onnx-kaldifst-core -force_load ${PODS_ROOT}/../.symlinks/plugins/flutter_sherpa_onnx/ios/lib/libsherpa-onnx-kaldifst-core.a $(inherited)'
  }
 
  s.swift_version = '5.0'


end
