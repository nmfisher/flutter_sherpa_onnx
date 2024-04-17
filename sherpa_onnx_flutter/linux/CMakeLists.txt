# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "flutter_sherpa_onnx")
project(${PROJECT_NAME} LANGUAGES CXX C)

# This value is used when generating builds using this plugin, so it must
# not be changed.
set(PLUGIN_NAME "flutter_sherpa_onnx_plugin")

include_directories(../ios/include/)
include_directories(../ios/include/dart)
include_directories(../ios/include/kaldi)

set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17")

# Define the plugin library target. Its name must not be changed (see comment
# on PLUGIN_NAME above).
#
# Any new source files that you add to the plugin should be added here.
add_library(${PLUGIN_NAME} SHARED
  "flutter_sherpa_onnx_plugin.cc"
  "../ios/Classes/model.cc"
  "../ios/Classes/recognizer.cc"
  "../ios/Classes/custom_api.cc"
  "../ios/Classes/spk_model.cc"
  "../ios/Classes/language_model.cc"
  "../ios/Classes/dart_api_dl.c"
)

add_link_options(-dead_strip)

# Apply a standard set of build settings that are configured in the
# application-level CMakeLists.txt. This can be removed for plugins that want
# full control over build settings.
apply_standard_settings(${PLUGIN_NAME})

# Symbols are hidden by default to reduce the chance of accidental conflicts
# between plugins. This should not be removed; any symbols that should be
# exported should be explicitly exported with the FLUTTER_PLUGIN_EXPORT macro.
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)

# Source include directories and library dependencies. Add any plugin-specific
# dependencies here.
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)

target_link_libraries(${PLUGIN_NAME} PRIVATE ${flutter_kaldi_libs_bundled_libraries})

target_link_libraries(${PLUGIN_NAME} PRIVATE /opt/intel/oneapi/mkl/latest/lib/pkgconfig/../../lib/intel64/libmkl_intel_lp64.a /opt/intel/oneapi/mkl/latest/lib/pkgconfig/../../lib/intel64/libmkl_sequential.a /opt/intel/oneapi/mkl/latest/lib/pkgconfig/../../lib/intel64/libmkl_core.a gfortran)

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(flutter_sherpa_onnx_bundled_libraries
  ""
  PARENT_SCOPE  
)

