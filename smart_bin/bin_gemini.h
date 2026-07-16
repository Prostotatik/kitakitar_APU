#pragma once
#include "esp_camera.h"

struct GeminiResult {
    char category[16];   // one of the fixed schema enum values
    float weightKg;      // clamped to CLAMP_WEIGHT_MIN/MAX_KG
    float co2Kg;         // clamped to CLAMP_CO2_MIN/MAX_KG
};

// Sends the JPEG to Gemini (strict-JSON schema, thinking budget 0).
// True on success with a valid category; false on ANY failure (fail-closed).
bool geminiClassify(camera_fb_t* fb, GeminiResult& out);

// Category → platform material slug; nullptr for residual/unknown.
const char* categoryToSlug(const char* category);
// Category → short human label for the OLED.
const char* categoryLabel(const char* category);
