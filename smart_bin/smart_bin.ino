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

// ── SSD1306 OLED Display ──────────────────────────────────────────
#include <Adafruit_SSD1306.h>
#include <Adafruit_GFX.h>

#define OLED_SDA_PIN 14
#define OLED_SCL_PIN 15
#define OLED_WIDTH  128
#define OLED_HEIGHT 64
#define OLED_ADDRESS 0x3C

Adafruit_SSD1306 display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);
bool oled_initialized = false;

// ── Display State Machine ──────────────────────────────────────────
enum DisplayState {
  DISPLAY_IDLE,      // Ready for next item
  DISPLAY_QR_ACTIVE, // Showing QR with timer
  DISPLAY_ERROR      // Connection error
};

DisplayState current_state = DISPLAY_IDLE;
unsigned long qr_timer_start = 0;
unsigned int qr_points = 0;
String qr_timer_seconds = "30";

// ── Connection State ──────────────────────────────────────────────
bool last_ws_connected = false;
unsigned long last_reconnect_display = 0;
unsigned long connection_display_time = 0;  // For "Connected!" → "Ready for next" transition

// ── Servo State Machine (non-blocking) ──────────────────────────────
enum ServoState { SERVO_IDLE, SERVO_MOVING, SERVO_WAITING, SERVO_RETURNING };
ServoState servo_state = SERVO_IDLE;
unsigned long servo_action_start = 0;
int servo_target_angle = 90;
int servo_next_action = 0;  // 0 = move to angle, 1 = return to center

// ── QR Bitmap Buffer ──────────────────────────────────────────────
// 64x64 pixels = 4096 bits = 512 bytes
#define QR_BITMAP_SIZE 512
uint8_t qr_bitmap[QR_BITMAP_SIZE];
bool qr_bitmap_ready = false;
String qr_id_current = "";

// ── JSON parsing buffer ───────────────────────────────────────────
StaticJsonDocument<4096> jsonDoc;  // Large enough for QR bitmap array

// ── Camera model ─────────────────────────────────────────────────
#define CAMERA_MODEL_AI_THINKER

// ── WiFi / Server config  (edit these) ──────────────────────────
const char* WIFI_SSID     = "YOUR WIFI";
const char* WIFI_PASSWORD = "YOUR PASSWORD";
const char* SERVER_HOST   = "YOUR PC's LAN IP";
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
void renderQrDisplay();
void displayText(const char* line1, const char* line2 = nullptr);
void triggerServo(const char* label);  // Non-blocking servo trigger
void updateServo();                     // Call in loop to update servo state

// ════════════════════════════════════════════════════════════════
// QR Event Handlers
// ════════════════════════════════════════════════════════════════
void handleQrGenerated() {
    // Extract QR data from jsonDoc
    qr_id_current = jsonDoc["qr_id"].as<String>();
    qr_points = jsonDoc["points"] | 0;
    int timer_secs = jsonDoc["timer_seconds"] | 30;

    // Extract bitmap array
    JsonArray bitmapArray = jsonDoc["qr_bitmap"].as<JsonArray>();
    if (bitmapArray.size() != QR_BITMAP_SIZE) {
        Serial.printf("[OLED] Invalid bitmap size: %d expected %d\n",
                      bitmapArray.size(), QR_BITMAP_SIZE);
        return;
    }

    // Copy bitmap to buffer
    for (int i = 0; i < QR_BITMAP_SIZE && i < bitmapArray.size(); i++) {
        qr_bitmap[i] = bitmapArray[i];
    }
    qr_bitmap_ready = true;

    // Update state
    current_state = DISPLAY_QR_ACTIVE;
    qr_timer_start = millis();
    qr_timer_seconds = String(timer_secs);

    // Render QR on display
    renderQrDisplay();
    Serial.printf("[OLED] QR generated: id=%s points=%u\n",
                  qr_id_current.c_str(), qr_points);
}

void handleQrScanned() {
    Serial.println("[OLED] QR scanned by user");
    current_state = DISPLAY_IDLE;
    qr_bitmap_ready = false;
    qr_id_current = "";
    qr_points = 0;
    displayText("Points Claimed!", "Ready for next");
    // Removed blocking delay - display updates naturally in loop
}

void handleTimerExpired() {
    Serial.println("[OLED] Timer expired");
    current_state = DISPLAY_IDLE;
    qr_bitmap_ready = false;
    qr_id_current = "";
    qr_points = 0;
    displayText("Ready for", "next item");
}

void displayConnectionError() {
    if (!oled_initialized) return;
    current_state = DISPLAY_ERROR;
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 20);
    display.println("No Connection");
    display.setCursor(0, 40);
    display.println("Retrying...");
    display.display();
}

// ════════════════════════════════════════════════════════════════
// WebSocket event handler
// ════════════════════════════════════════════════════════════════
void onWebSocketEvent(WStype_t type, uint8_t* payload, size_t length) {
    switch (type) {
        case WStype_CONNECTED:
            ws_connected = true;
            Serial.println("[WS] Connected");
            displayText("Connected to", "server");
            // Removed blocking delay - let main loop handle display refresh
            break;
        case WStype_DISCONNECTED:
            ws_connected = false;
            Serial.println("[WS] Disconnected — retrying...");
            current_state = DISPLAY_ERROR;
            displayText("No Connection", "Retrying...");
            break;
        case WStype_TEXT: {
            // Parse incoming JSON from server
            DeserializationError err = deserializeJson(jsonDoc, payload, length);
            if (err) {
                Serial.printf("[WS] JSON parse error: %s\n", err.c_str());
                break;
            }

            const char* event = jsonDoc["event"];
            if (!event) {
                // Old-style detection confirmation (backward compat)
                Serial.printf("[WS] Server: %s\n", (char*)payload);
                break;
            }

            if (strcmp(event, "qr_generated") == 0) {
                handleQrGenerated();
            } else if (strcmp(event, "qr_scanned") == 0) {
                handleQrScanned();
            } else if (strcmp(event, "timer_expired") == 0) {
                handleTimerExpired();
            } else if (strcmp(event, "error") == 0) {
                const char* msg = jsonDoc["message"] | "Unknown error";
                Serial.printf("[WS] Server error: %s\n", msg);
                displayText("Error:", msg);
            }
            break;
        }
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
// OLED Display Helpers
// ════════════════════════════════════════════════════════════════
void displayClear() {
    if (!oled_initialized) return;
    display.clearDisplay();
}

void displayText(const char* line1, const char* line2) {
    if (!oled_initialized) return;
    display.clearDisplay();
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, 24);
    display.println(line1);
    if (line2) {
        display.setCursor(0, 36);
        display.println(line2);
    }
    display.display();
}

// ════════════════════════════════════════════════════════════════
// Non-Blocking Servo Control
// ════════════════════════════════════════════════════════════════
void triggerServo(const char* label) {
    // Start servo movement (non-blocking)
    if (strcmp(label, "paper") == 0) {
        servo_target_angle = 0;
    } else if (strcmp(label, "can") == 0) {
        servo_target_angle = 180;
    } else {
        return;  // Unknown label
    }

    myServo.write(servo_target_angle);
    servo_state = SERVO_MOVING;
    servo_action_start = millis();
    Serial.printf("[SERVO] Moving to %d degrees\n", servo_target_angle);
}

void updateServo() {
    // Non-blocking servo state machine - call this in loop()
    // Also keeps WebSocket alive during servo movement
    wsClient.loop();  // Keep WebSocket connection alive

    if (servo_state == SERVO_IDLE) {
        return;
    }

    unsigned long elapsed = millis() - servo_action_start;

    switch (servo_state) {
        case SERVO_MOVING:
            // Wait 2 seconds at target position
            if (elapsed >= 2000) {
                myServo.write(90);  // Return to center
                servo_state = SERVO_RETURNING;
                servo_action_start = millis();
                Serial.println("[SERVO] Returning to center");
            }
            break;

        case SERVO_RETURNING:
            // Wait for return to complete
            if (elapsed >= 500) {
                servo_state = SERVO_IDLE;
                Serial.println("[SERVO] Movement complete");
            }
            break;

        default:
            servo_state = SERVO_IDLE;
            break;
    }
}

// ════════════════════════════════════════════════════════════════
// QR Bitmap Rendering
// ════════════════════════════════════════════════════════════════
void renderQrDisplay() {
    if (!oled_initialized || !qr_bitmap_ready) return;

    display.clearDisplay();

    // Calculate QR position (centered horizontally)
    int qr_width = 64;
    int qr_height = 64;
    int qr_x = (OLED_WIDTH - qr_width) / 2;  // Center: (128-64)/2 = 32
    int qr_y = 0;  // Top of display

    // Draw QR bitmap (1-bit per pixel, 8 pixels per byte)
    for (int y = 0; y < qr_height; y++) {
        for (int x = 0; x < qr_width; x++) {
            int byte_index = (y * qr_width + x) / 8;
            int bit_index = (y * qr_width + x) % 8;

            // Check if pixel is set (MSB first in each byte)
            if (qr_bitmap[byte_index] & (1 << (7 - bit_index))) {
                display.drawPixel(qr_x + x, qr_y + y, SSD1306_WHITE);
            }
        }
    }

    // Draw points text below QR
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.setCursor(0, qr_height + 2);
    display.printf("Points: %u", qr_points);

    // Timer will be updated separately
    display.display();
}

void updateTimerDisplay(int seconds_remaining) {
    if (!oled_initialized || current_state != DISPLAY_QR_ACTIVE) return;

    // Only update the timer line (row 56-64)
    display.fillRect(0, 56, OLED_WIDTH, 8, SSD1306_BLACK);  // Clear timer area
    display.setCursor(0, 56);
    display.setTextSize(1);
    display.setTextColor(SSD1306_WHITE);
    display.printf("Timer: %02d", seconds_remaining);
    display.display();
}

// For testing only - call in setup() to verify OLED rendering
void testOledBitmap() {
    if (!oled_initialized) return;

    // Create checkerboard test pattern
    for (int i = 0; i < QR_BITMAP_SIZE; i++) {
        qr_bitmap[i] = (i % 2 == 0) ? 0xAA : 0x55;  // Alternating pattern
    }
    qr_bitmap_ready = true;
    qr_points = 100;
    current_state = DISPLAY_QR_ACTIVE;
    renderQrDisplay();
    Serial.println("[OLED] Test pattern displayed");
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

    // ── Keep WebSocket alive after HTTP ───────────────────────────
    wsClient.loop();  // Process any pending WebSocket messages
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

    // ── Initialize SSD1306 OLED ────────────────────────────────────
    Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);

    if (!display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDRESS)) {
        Serial.println("[OLED] SSD1306 initialization failed");
        oled_initialized = false;
    } else {
        oled_initialized = true;
        display.clearDisplay();
        display.setTextSize(1);
        display.setTextColor(SSD1306_WHITE);
        display.setCursor(0, 0);
        display.println("Smart Bin Ready");
        display.display();
        Serial.println("[OLED] SSD1306 initialized");
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
    updateServo();  // Non-blocking servo state machine

    static unsigned long lastLog = 0;
    if (millis() - lastLog >= 5000) {
        lastLog = millis();
        Serial.printf("[DEBUG] WiFi:%s  WS:%s  Heap:%u B\n",
            WiFi.status() == WL_CONNECTED ? "OK" : "LOST",
            ws_connected ? "YES" : "NO",
            ESP.getFreeHeap());
    }

    // ── Track WebSocket connection changes ───────────────────────────
    if (ws_connected != last_ws_connected) {
        last_ws_connected = ws_connected;
        if (ws_connected) {
            // Reconnected
            if (current_state == DISPLAY_ERROR) {
                current_state = DISPLAY_IDLE;
                displayText("Connected!", "Ready for next");
                connection_display_time = millis();
            }
        } else {
            // Disconnected
            displayConnectionError();
        }
    }

    // ── Transition "Connected!" → "Ready for next item" after 2s ───────
    if (ws_connected && current_state == DISPLAY_IDLE && connection_display_time > 0) {
        if (millis() - connection_display_time >= 2000) {
            displayText("Ready for", "next item");
            connection_display_time = 0;  // Stop transitioning
        }
    }

    // ── Update timer countdown every second ─────────────────────────
    if (current_state == DISPLAY_QR_ACTIVE && qr_bitmap_ready) {
        unsigned long elapsed = (millis() - qr_timer_start) / 1000;
        int remaining = 30 - elapsed;

        if (remaining <= 0) {
            // Timer expired - clear QR immediately (don't wait for server)
            handleTimerExpired();
        } else {
            static unsigned long last_timer_update = 0;
            if (millis() - last_timer_update >= 1000) {
                last_timer_update = millis();
                updateTimerDisplay(remaining);
            }
        }
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

        // Actuate servo (non-blocking)
        triggerServo(bb.label);
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
