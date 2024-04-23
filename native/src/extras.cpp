#include "c-api.h"
#include "sherpa-onnx/csrc/resample.h"
#include <vector>
#include <iostream> 
extern "C" {
void const sherpa_onnx_dart_resample(const float* data, int length, int sampleRateFrom, int sampleRateTo, float** outPtr, int* outLen) {
  auto resampler = sherpa_onnx::LinearResample(sampleRateFrom, sampleRateTo, float(std::min(sampleRateTo, sampleRateFrom)) / 2, 4); 
  auto out = std::vector<float>();
  resampler.Resample(data, length, true, &out);
  *outPtr = (float*) malloc(out.size() * sizeof(float));
  *outLen = out.size();
  memcpy(*outPtr, out.data(), out.size() * sizeof(float));
}
void const sherpa_onnx_dart_free(const float* data) {
  free((void*)data);
}
}
    