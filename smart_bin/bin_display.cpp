#include "bin_display.h"
#include "config.h"
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include "qrcode.h"   // ESP-IDF bundled "qrcode" component (esp_qrcode_*) — see fix-forward note in task report

static Adafruit_SSD1306 s_oled(128, 64, &Wire, -1);
static bool s_ready = false;

static const char kQrPrefix[] = "KITAKITAR_QR:";

bool dispInit() {
    Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
    s_ready = s_oled.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR);
    if (!s_ready) { Serial.println("[OLED] init failed"); return false; }
    s_oled.setTextColor(SSD1306_WHITE);
    return true;
}

static void twoLines(const char* l1, const char* l2) {
    if (!s_ready) return;
    s_oled.clearDisplay();
    s_oled.setTextSize(1);
    s_oled.setCursor(0, 24);
    s_oled.println(l1);
    if (l2) { s_oled.setCursor(0, 36); s_oled.println(l2); }
    s_oled.display();
}

void dispBoot(const char* line2)  { twoLines("KitaKitar Bin", line2); }
void dispReady()                  { twoLines("Ready for", "next item"); }
void dispAnalyzing()              { twoLines("Analyzing...", "hold on"); }
void dispClaimed()                { twoLines("Points Claimed!", "Thank you!"); }
void dispError(const char* l1, const char* l2) { twoLines(l1, l2); }

void dispResult(const char* label, float weightKg, float co2Kg) {
    if (!s_ready) return;
    s_oled.clearDisplay();
    s_oled.setTextSize(1);
    s_oled.setCursor(0, 8);  s_oled.print("Detected: "); s_oled.print(label);
    s_oled.setCursor(0, 24); s_oled.printf("Weight: %.3f kg", weightKg);
    s_oled.setCursor(0, 36); s_oled.printf("CO2e:   %.2f kg", co2Kg);
    s_oled.setCursor(0, 52); s_oled.print("-> recyclable side");
    s_oled.display();
}

void dispResidual(const char* label) {
    if (!s_ready) return;
    s_oled.clearDisplay();
    s_oled.setTextSize(1);
    s_oled.setCursor(0, 16); s_oled.print("Detected: "); s_oled.print(label);
    s_oled.setCursor(0, 32); s_oled.print("-> residual side");
    s_oled.setCursor(0, 44); s_oled.print("No points for this");
    s_oled.display();
}

static void drawCountdown(int secondsLeft) {
    if (secondsLeft < 0) secondsLeft = 0;
    s_oled.fillRect(66, 56, 62, 8, SSD1306_BLACK);
    s_oled.setTextSize(1);
    s_oled.setCursor(66, 56);
    s_oled.printf("%2ds left", secondsLeft);
}

// esp_qrcode_generate() is callback-based and takes no user-data pointer, so
// the modules are drawn directly into s_oled here, synchronously, during the
// call below — the qrcode handle is only valid for the duration of this callback.
static void qrDrawCallback(esp_qrcode_handle_t qrcode) {
    int size = esp_qrcode_get_size(qrcode);
    s_oled.clearDisplay();
    // 29 modules x 2 px = 58 px, offset (3,3) — fits the 64-px height.
    for (int y = 0; y < size; y++)
        for (int x = 0; x < size; x++)
            if (esp_qrcode_get_module(qrcode, x, y))
                s_oled.fillRect(3 + x * 2, 3 + y * 2, 2, 2, SSD1306_WHITE);
}

void dispQr(const char* docId, long points, int secondsLeft) {
    if (!s_ready) return;
    char payload[64];
    snprintf(payload, sizeof(payload), "%s%s", kQrPrefix, docId);

    // Version cap 3 (29x29 max), ECC LOW: byte-mode capacity 53 — payload is 33.
    esp_qrcode_config_t cfg = {};
    cfg.display_func = qrDrawCallback;
    cfg.max_qrcode_version = 3;
    cfg.qrcode_ecc_level = ESP_QRCODE_ECC_LOW;
    if (esp_qrcode_generate(&cfg, payload) != ESP_OK) {
        dispError("QR encode failed", payload);
        return;
    }

    s_oled.setTextSize(1);
    s_oled.setCursor(66, 0);  s_oled.print("Kitar Pts");
    s_oled.setTextSize(2);
    s_oled.setCursor(66, 12); s_oled.print(points);
    s_oled.setTextSize(1);
    s_oled.setCursor(66, 34); s_oled.print("Scan in");
    s_oled.setCursor(66, 44); s_oled.print("the app");
    drawCountdown(secondsLeft);
    s_oled.display();
}

void dispQrTick(int secondsLeft) {
    if (!s_ready) return;
    drawCountdown(secondsLeft);
    s_oled.display();
}
