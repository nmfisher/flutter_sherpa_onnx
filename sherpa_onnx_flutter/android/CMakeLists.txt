cmake_minimum_required(VERSION 3.10)  

set(ANDROID_STL c++_shared)

include_directories(../ios/include)
link_directories(src/main/jniLibs/${ANDROID_ABI})
link_directories(${CMAKE_CURRENT_SOURCE_DIR}/../../flutter_onnx ${FLUTTER_ONNX_JNI_DIR})

add_library( 
    flutter_sherpa_onnx_plugin
    SHARED
    src/main/cpp/dummy.cpp
)

target_link_libraries(flutter_sherpa_onnx_plugin -landroid -llog -lc++ -lsherpa-onnx-core -lsherpa-onnx-fst -lsherpa-onnx-kaldifst-core -lkaldi-decoder-core -lkaldi-native-fbank-core -lsherpa-onnx-c-api)

get_cmake_property(_variableNames VARIABLES)
list (SORT _variableNames)
foreach (_variableName ${_variableNames})
    message(STATUS "FOO${_variableName}=${${_variableName}}")
endforeach()
