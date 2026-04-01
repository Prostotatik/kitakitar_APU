// ╔══════════════════════════════════════════════════════════════════╗
// ║  Smart Recycle Bin — ESP32-CAM + Edge Impulse                   ║
// ║  • WebSocket  →  JSON metadata  (label, confidence)             ║
// ║  • HTTP POST  →  raw JPEG photo  (avoids RAM crash)             ║
// ╚══════════════════════════════════════════════════════════════════╝
//
// Root cause of previous crash:
//   WebSocketsClient::sendBIN() copies the entire JPEG into a second
//   heap buffer for WebSocket framing. With the EI snapshot_buf already
//   allocated (~230 KB), that extra copy pushes the ESP32-CAM past its
//   available heap → hard reset → "no close frame received".
//
// Fix:
//   • Free snapshot_buf BEFORE grabbing the JPEG for upload.
//   • Use HTTPClient to stream fb->buf directly — zero extra copy.
//   • WebSocket carries only the lightweight JSON metadata.

#include <KitaKitar_inferencing.h>
#include "edge-impulse-sdk/dsp/image/image.hpp"
#include "esp_camera.h"
#include <ESP32Servo.h>
#include <WiFi.h>
#include <WebSocketsClient.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>

// ── Camera model ─────────────────────────────────────────────────
#define CAMERA_MODEL_AI_THINKER

// ── WiFi / Server config  (edit these) ──────────────────────────
const char* WIFI_SSID     = "YOUR WIFI";
const char* WIFI_PASSWORD = "YOUR PASSWORD";
const char* SERVER_HOST   = "YOUR IP";   // PC's LAN IP
const int   WS_PORT       = 8765;             // WebSocket metadata
const int   HTTP_PORT     = 8766;             // HTTP photo upload
const char* WS_PATH       = "/";
const char* DEVICE_ID     = "esp32-cam-01";

// ── Camera pins ───────────────────────────────────────────────────
#if defined(CAMERA_MODEL_AI_THINKER)
#define PWDN_GPIO_NUM     32
#define RESET_GPIO_NUM    -1
#define XCLK_GPIO_NUM      0
#define SIOD_GPIO_NUM     26
#define SIOC_GPIO_NUM     27
#define Y9_GPIO_NUM       35
#define Y8_GPIO_NUM       34
#define Y7_GPIO_NUM       39
#define Y6_GPIO_NUM       36
#define Y5_GPIO_NUM       21
#define Y4_GPIO_NUM       19
#define Y3_GPIO_NUM       18
#define Y2_GPIO_NUM        5
#define VSYNC_GPIO_NUM    25
#define HREF_GPIO_NUM     23
#define PCLK_GPIO_NUM     22
#else
#error "Camera model not selected"
#endif

#define SERVO_PIN 12

// ── EI frame buffer constants ─────────────────────────────────────
#define EI_CAMERA_RAW_FRAME_BUFFER_COLS   320
#define EI_CAMERA_RAW_FRAME_BUFFER_ROWS   240
#define EI_CAMERA_FRAME_BYTE_SIZE         3

// ── Globals ───────────────────────────────────────────────────────
static bool debug_nn       = false;
static bool is_initialised = false;
static bool ws_connected   = false;
uint8_t*    snapshot_buf   = nullptr;

Servo            myServo;
WebSocketsClient wsClient;

static camera_config_t camera_config = {
    .pin_pwdn     = PWDN_GPIO_NUM,
    .pin_reset    = RESET_GPIO_NUM,
    .pin_xclk     = XCLK_GPIO_NUM,
    .pin_sscb_sda = SIOD_GPIO_NUM,
    .pin_sscb_scl = SIOC_GPIO_NUM,
    .pin_d7       = Y9_GPIO_NUM,
    .pin_d6       = Y8_GPIO_NUM,
    .pin_d5       = Y7_GPIO_NUM,
    .pin_d4       = Y6_GPIO_NUM,
    .pin_d3       = Y5_GPIO_NUM,
    .pin_d2       = Y4_GPIO_NUM,
    .pin_d1       = Y3_GPIO_NUM,
    .pin_d0       = Y2_GPIO_NUM,
    .pin_vsync    = VSYNC_GPIO_NUM,
    .pin_href     = HREF_GPIO_NUM,
    .pin_pclk     = PCLK_GPIO_NUM,
    .xclk_freq_hz = 20000000,
    .ledc_timer   = LEDC_TIMER_0,
    .ledc_channel = LEDC_CHANNEL_0,
    .pixel_format = PIXFORMAT_JPEG,
    .frame_size   = FRAMESIZE_QVGA,   // 320×240 — keeps heap usage manageable
    .jpeg_quality = 12,
    .fb_count     = 1,
    .fb_location  = CAMERA_FB_IN_PSRAM,
    .grab_mode    = CAMERA_GRAB_WHEN_EMPTY,
};

// ── Forward declarations ──────────────────────────────────────────
bool ei_camera_init(void);
void ei_camera_deinit(void);
bool ei_camera_capture(uint32_t img_width, uint32_t img_height, uint8_t* out_buf);
void connectWiFi(void);
void onWebSocketEvent(WStype_t type, uint8_t* payload, size_t length);
void sendDetection(const char* label, float confidence);

// ════════════════════════════════════════════════════════════════
// WebSocket event handler
// ════════════════════════════════════════════════════════════════
void onWebSocketEvent(WStype_t type, uint8_t* payload, size_t length) {
    switch (type) {
        case WStype_CONNECTED:
            ws_connected = true;
            Serial.println("[WS] Connected");
            break;
        case WStype_DISCONNECTED:
            ws_connected = false;
            Serial.println("[WS] Disconnected — retrying...");
            break;
        case WStype_TEXT:
            Serial.printf("[WS] Server: %s\n", payload);
            break;
        case WStype_ERROR:
            Serial.printf("[WS] Error: %s\n", payload ? (char*)payload : "null");
            break;
        default: break;
    }
}

// ════════════════════════════════════════════════════════════════
// WiFi connect
// ════════════════════════════════════════════════════════════════
void connectWiFi() {
    Serial.printf("[WiFi] Connecting to %s", WIFI_SSID);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
    }
    Serial.println("\n[WiFi] Connected — IP: " + WiFi.localIP().toString());
}

// ════════════════════════════════════════════════════════════════
// sendDetection
//
//  IMPORTANT: call this AFTER free(snapshot_buf) so the heap is clear.
//
//  Step 1 — WebSocket text:  JSON { device_id, label, confidence }
//  Step 2 — HTTP POST:       JPEG streamed straight from camera PSRAM
//             URL: http://<host>:8766/upload
//             Query params:  label, device_id, confidence
//             Body:          raw JPEG bytes (Content-Type: image/jpeg)
// ════════════════════════════════════════════════════════════════
void sendDetection(const char* label, float confidence) {

    // ── Step 1: WebSocket metadata ────────────────────────────────
    if (ws_connected) {
        StaticJsonDocument<128> doc;
        doc["device_id"]  = DEVICE_ID;
        doc["label"]      = label;
        doc["confidence"] = round(confidence * 1000.0f) / 10.0f;  // → % 1dp

        String meta;
        serializeJson(doc, meta);
        wsClient.sendTXT(meta);
        Serial.printf("[WS]  Meta sent: %s\n", meta.c_str());
    } else {
        Serial.println("[WS]  Not connected — metadata skipped");
    }

    // ── Step 2: HTTP POST JPEG ─────────────────────────────────────
    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) {
        Serial.println("[CAM] Failed to grab JPEG for upload");
        return;
    }
    if (fb->format != PIXFORMAT_JPEG) {
        Serial.println("[CAM] Frame not JPEG — skipping upload");
        esp_camera_fb_return(fb);
        return;
    }

    char url[220];
    snprintf(url, sizeof(url),
        "http://%s:%d/upload?label=%s&device_id=%s&confidence=%.1f",
        SERVER_HOST, HTTP_PORT, label, DEVICE_ID, confidence * 100.0f);

    HTTPClient http;
    http.begin(url);
    http.addHeader("Content-Type", "image/jpeg");

    // fb->buf lives in PSRAM — POST streams it without an extra heap copy
    int code = http.POST(fb->buf, fb->len);
    Serial.printf("[HTTP] Upload %s — code %d  size %u B\n",
                  code == 200 ? "OK" : "FAILED", code, fb->len);

    esp_camera_fb_return(fb);   // return PSRAM buffer ASAP
    http.end();
}

// ════════════════════════════════════════════════════════════════
// Setup
// ════════════════════════════════════════════════════════════════
void setup() {
    Serial.begin(115200);
    while (!Serial);

    myServo.attach(SERVO_PIN);
    myServo.write(90);  // Neutral on boot

    Serial.println("\n=== Smart Recycle Bin ===");
    Serial.printf("[Heap] Free at boot: %u bytes\n", ESP.getFreeHeap());

    if (!ei_camera_init()) {
        ei_printf("[ERR] Camera init failed\r\n");
    } else {
        ei_printf("[OK]  Camera ready\r\n");
    }

    connectWiFi();

    wsClient.begin(SERVER_HOST, WS_PORT, WS_PATH, "");
    wsClient.onEvent(onWebSocketEvent);
    wsClient.setReconnectInterval(3000);

    ei_printf("\nStarting inference in 2 s...\n");
    ei_sleep(2000);
}

// ════════════════════════════════════════════════════════════════
// Main loop
// ════════════════════════════════════════════════════════════════
void loop() {
    wsClient.loop();

    static unsigned long lastLog = 0;
    if (millis() - lastLog >= 5000) {
        lastLog = millis();
        Serial.printf("[DEBUG] WiFi:%s  WS:%s  Heap:%u B\n",
            WiFi.status() == WL_CONNECTED ? "OK" : "LOST",
            ws_connected ? "YES" : "NO",
            ESP.getFreeHeap());
    }

    if (ei_sleep(5) != EI_IMPULSE_OK) return;

    // ── Allocate snapshot buffer for classifier ───────────────────
    snapshot_buf = (uint8_t*)malloc(
        EI_CAMERA_RAW_FRAME_BUFFER_COLS *
        EI_CAMERA_RAW_FRAME_BUFFER_ROWS *
        EI_CAMERA_FRAME_BYTE_SIZE);

    if (!snapshot_buf) {
        ei_printf("[ERR] Snapshot alloc failed — heap: %u B\n", ESP.getFreeHeap());
        return;
    }

    ei::signal_t signal;
    signal.total_length = EI_CLASSIFIER_INPUT_WIDTH * EI_CLASSIFIER_INPUT_HEIGHT;
    signal.get_data     = &ei_camera_get_data;

    if (!ei_camera_capture(
            (size_t)EI_CLASSIFIER_INPUT_WIDTH,
            (size_t)EI_CLASSIFIER_INPUT_HEIGHT,
            snapshot_buf)) {
        ei_printf("[ERR] Capture failed\r\n");
        free(snapshot_buf);
        snapshot_buf = nullptr;
        return;
    }

    ei_impulse_result_t result = { 0 };
    EI_IMPULSE_ERROR err = run_classifier(&signal, &result, debug_nn);

    // ── Free snapshot buffer BEFORE HTTP upload ───────────────────
    // This is the critical fix: reclaim ~230 KB before grabbing a new
    // JPEG frame, so the HTTP POST never competes for the same heap.
    free(snapshot_buf);
    snapshot_buf = nullptr;

    if (err != EI_IMPULSE_OK) {
        ei_printf("[ERR] Classifier (%d)\n", err);
        return;
    }

    ei_printf("Predictions (DSP:%d ms  Class:%d ms  Anomaly:%d ms):\n",
        result.timing.dsp, result.timing.classification, result.timing.anomaly);

#if EI_CLASSIFIER_OBJECT_DETECTION == 1
    for (uint32_t i = 0; i < result.bounding_boxes_count; i++) {
        ei_impulse_result_bounding_box_t bb = result.bounding_boxes[i];
        if (bb.value == 0) continue;

        ei_printf("  %s (%.2f%%) [x:%u y:%u w:%u h:%u]\r\n",
            bb.label, bb.value * 100, bb.x, bb.y, bb.width, bb.height);

        // snapshot_buf is already NULL here — safe to upload
        sendDetection(bb.label, bb.value);

        // Actuate servo
        String lbl = String(bb.label);
        if (lbl == "paper") {
            myServo.write(0);
            delay(2000);
            myServo.write(90);
        } else if (lbl == "can") {
            myServo.write(180);
            delay(2000);
            myServo.write(90);
        }
    }

#else
    for (uint16_t i = 0; i < EI_CLASSIFIER_LABEL_COUNT; i++) {
        ei_printf("  %s: %.5f\r\n",
            ei_classifier_inferencing_categories[i],
            result.classification[i].value);
    }
#endif

#if EI_CLASSIFIER_HAS_ANOMALY
    ei_printf("Anomaly: %.3f\r\n", result.anomaly);
#endif
}

// ════════════════════════════════════════════════════════════════
// Camera helpers
// ════════════════════════════════════════════════════════════════
bool ei_camera_init(void) {
    if (is_initialised) return true;

    esp_err_t err = esp_camera_init(&camera_config);
    if (err != ESP_OK) {
        Serial.printf("[CAM] Init failed: 0x%x\n", err);
        return false;
    }

    sensor_t* s = esp_camera_sensor_get();
    if (s->id.PID == OV3660_PID) {
        s->set_vflip(s, 1);
        s->set_brightness(s, 1);
        s->set_saturation(s, 0);
    }

    is_initialised = true;
    return true;
}

void ei_camera_deinit(void) {
    if (esp_camera_deinit() != ESP_OK)
        ei_printf("[CAM] Deinit failed\n");
    is_initialised = false;
}

bool ei_camera_capture(uint32_t img_width, uint32_t img_height, uint8_t* out_buf) {
    if (!is_initialised) {
        ei_printf("[ERR] Camera not initialised\r\n");
        return false;
    }

    camera_fb_t* fb = esp_camera_fb_get();
    if (!fb) {
        ei_printf("[CAM] Grab failed\n");
        return false;
    }

    bool ok = fmt2rgb888(fb->buf, fb->len, PIXFORMAT_JPEG, snapshot_buf);
    esp_camera_fb_return(fb);

    if (!ok) {
        ei_printf("[CAM] JPEG→RGB conversion failed\n");
        return false;
    }

    if (img_width  != EI_CAMERA_RAW_FRAME_BUFFER_COLS ||
        img_height != EI_CAMERA_RAW_FRAME_BUFFER_ROWS) {
        ei::image::processing::crop_and_interpolate_rgb888(
            out_buf,
            EI_CAMERA_RAW_FRAME_BUFFER_COLS,
            EI_CAMERA_RAW_FRAME_BUFFER_ROWS,
            out_buf, img_width, img_height);
    }

    return true;
}

static int ei_camera_get_data(size_t offset, size_t length, float* out_ptr) {
    size_t pixel_ix    = offset * 3;
    size_t pixels_left = length;
    size_t out_ix      = 0;

    while (pixels_left--) {
        out_ptr[out_ix++] =
            (snapshot_buf[pixel_ix + 2] << 16) +
            (snapshot_buf[pixel_ix + 1] <<  8) +
             snapshot_buf[pixel_ix];
        pixel_ix += 3;
    }
    return 0;
}

#if !defined(EI_CLASSIFIER_SENSOR) || EI_CLASSIFIER_SENSOR != EI_CLASSIFIER_SENSOR_CAMERA
#error "Invalid model for current sensor"
#endif
