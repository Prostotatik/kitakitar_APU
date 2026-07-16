#include "bin_gemini.h"
#include "bin_net.h"
#include "config.h"
#include <Arduino.h>
#include <ArduinoJson.h>
#include "mbedtls/base64.h"
#include "esp_heap_caps.h"

#define GEMINI_URL "https://generativelanguage.googleapis.com/v1beta/models/" \
    GEMINI_MODEL ":generateContent?key=" GEMINI_API_KEY

// Request body = HEAD + <base64 jpeg> + TAIL. Both halves are compile-time
// constants; the assembled body lives in PSRAM to spare internal heap.
static const char kHead[] =
    "{\"contents\":[{\"parts\":[{\"text\":\""
    "You are the vision system of a recycling smart bin. Look at the single "
    "most prominent object deposited in the chamber. Classify it as exactly "
    "one category: glass, milk_carton, metal, plastic, cardboard, can "
    "(aluminum drink can), residual (non-recyclable or heavily contaminated), "
    "or unknown (no clear object visible). Estimate weight_kg, the typical "
    "weight of this object in kilograms, and co2_kg, the kilograms of CO2-"
    "equivalent emissions avoided by recycling it (use 0 for residual or "
    "unknown). Respond with JSON only."
    "\"},{\"inlineData\":{\"mimeType\":\"image/jpeg\",\"data\":\"";
static const char kTail[] =
    "\"}}]}],\"generationConfig\":{\"temperature\":0,\"maxOutputTokens\":256,"
    "\"responseMimeType\":\"application/json\",\"responseSchema\":{"
    "\"type\":\"OBJECT\",\"properties\":{"
    "\"category\":{\"type\":\"STRING\",\"enum\":[\"glass\",\"milk_carton\","
    "\"metal\",\"plastic\",\"cardboard\",\"can\",\"residual\",\"unknown\"]},"
    "\"weight_kg\":{\"type\":\"NUMBER\"},\"co2_kg\":{\"type\":\"NUMBER\"}},"
    "\"required\":[\"category\",\"weight_kg\",\"co2_kg\"]},"
    "\"thinkingConfig\":{\"thinkingBudget\":0}}}";

struct CatRow { const char* cat; const char* slug; const char* label; };
static const CatRow kCats[] = {
    {"glass",       "glass",    "Glass"},
    {"milk_carton", "paper",    "Milk carton"},
    {"cardboard",   "paper",    "Cardboard"},
    {"metal",       "metal",    "Metal"},
    {"plastic",     "plastic",  "Plastic"},
    {"can",         "aluminum", "Can (alu)"},
    {"residual",    nullptr,    "Residual"},
    {"unknown",     nullptr,    "Unknown"},
};

const char* categoryToSlug(const char* c) {
    for (auto& r : kCats) if (strcmp(r.cat, c) == 0) return r.slug;
    return nullptr;
}
const char* categoryLabel(const char* c) {
    for (auto& r : kCats) if (strcmp(r.cat, c) == 0) return r.label;
    return "Unknown";
}
static bool isKnownCategory(const char* c) {
    for (auto& r : kCats) if (strcmp(r.cat, c) == 0) return true;
    return false;
}

bool geminiClassify(camera_fb_t* fb, GeminiResult& out) {
    if (!fb || fb->len == 0) return false;

    size_t b64Len = 0;
    mbedtls_base64_encode(nullptr, 0, &b64Len, fb->buf, fb->len);
    uint8_t* b64 = (uint8_t*)heap_caps_malloc(b64Len + 1, MALLOC_CAP_SPIRAM);
    if (!b64) { Serial.println("[GEM] PSRAM alloc failed (b64)"); return false; }
    size_t written = 0;
    if (mbedtls_base64_encode(b64, b64Len + 1, &written, fb->buf, fb->len) != 0) {
        free(b64); return false;
    }

    size_t bodyLen = sizeof(kHead) - 1 + written + sizeof(kTail) - 1;
    uint8_t* body = (uint8_t*)heap_caps_malloc(bodyLen, MALLOC_CAP_SPIRAM);
    if (!body) { free(b64); Serial.println("[GEM] PSRAM alloc failed (body)"); return false; }
    memcpy(body, kHead, sizeof(kHead) - 1);
    memcpy(body + sizeof(kHead) - 1, b64, written);
    memcpy(body + sizeof(kHead) - 1 + written, kTail, sizeof(kTail) - 1);
    free(b64);

    String resp;
    int code = netPostJson(GEMINI_URL, nullptr, body, bodyLen, resp);
    free(body);
    if (code != 200) {
        Serial.printf("[GEM] HTTP %d: %s\n", code, resp.substring(0, 200).c_str());
        return false;
    }

    // Pull only candidates[0].content.parts[0].text out of the envelope.
    JsonDocument filter;
    filter["candidates"][0]["content"]["parts"][0]["text"] = true;
    JsonDocument env;
    if (deserializeJson(env, resp, DeserializationOption::Filter(filter))
            != DeserializationError::Ok) return false;
    const char* text = env["candidates"][0]["content"]["parts"][0]["text"];
    if (!text) { Serial.println("[GEM] no text part"); return false; }

    JsonDocument inner;
    if (deserializeJson(inner, text) != DeserializationError::Ok) {
        Serial.printf("[GEM] inner parse failed: %s\n", text);
        return false;
    }
    const char* cat = inner["category"] | "";
    if (!isKnownCategory(cat)) { Serial.printf("[GEM] bad category '%s'\n", cat); return false; }

    strlcpy(out.category, cat, sizeof(out.category));
    float w = inner["weight_kg"] | 0.0f;
    float c = inner["co2_kg"] | 0.0f;
    // Spec clamp: a hallucinated estimate cannot mint outsized points.
    out.weightKg = constrain(w, CLAMP_WEIGHT_MIN_KG, CLAMP_WEIGHT_MAX_KG);
    out.co2Kg    = constrain(c, CLAMP_CO2_MIN_KG,   CLAMP_CO2_MAX_KG);
    Serial.printf("[GEM] %s  %.3f kg  %.2f kgCO2e\n", out.category, out.weightKg, out.co2Kg);
    return true;
}
