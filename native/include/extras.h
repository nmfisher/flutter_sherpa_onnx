#include <stddef.h>
#include <stdint.h>

void sherpa_onnx_dart_resample(const float* data, int length, int sampleRateFrom, int sampleRateTo, float** outPtr, int* outLen);
void sherpa_onnx_dart_free(float* data);