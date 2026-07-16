#include "bin_net.h"
#include "config.h"
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>

bool netWifiConnected() { return WiFi.status() == WL_CONNECTED; }

bool netEnsureWifi() {
    if (netWifiConnected()) return true;
    static unsigned long lastAttempt = 0;
    if (lastAttempt != 0 && millis() - lastAttempt < WIFI_RETRY_MS) return false;
    lastAttempt = millis();
    Serial.printf("[WiFi] Connecting to %s...\n", WIFI_SSID);
    WiFi.disconnect();
    WiFi.mode(WIFI_STA);
    WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
    unsigned long t0 = millis();
    while (!netWifiConnected() && millis() - t0 < WIFI_CONNECT_TIMEOUT_MS) delay(250);
    if (netWifiConnected())
        Serial.println("[WiFi] Connected: " + WiFi.localIP().toString());
    else
        Serial.println("[WiFi] Connect timed out");
    return netWifiConnected();
}

static int request(const char* method, const char* url, const char* bearer,
                   const char* contentType, const uint8_t* body, size_t len,
                   String& respOut) {
    respOut = "";
    if (!netWifiConnected()) return -1;
    WiFiClientSecure client;
    client.setInsecure();               // prototype posture (spec: accepted risk)
    HTTPClient http;
    if (!http.begin(client, url)) return -2;
    http.setTimeout(HTTP_TIMEOUT_MS);
    if (bearer && bearer[0])
        http.addHeader("Authorization", String("Bearer ") + bearer);
    if (contentType) http.addHeader("Content-Type", contentType);
    int code = (strcmp(method, "GET") == 0)
        ? http.GET()
        : http.POST(const_cast<uint8_t*>(body), len);
    if (code > 0) respOut = http.getString();
    http.end();
    return code;
}

int netPostJson(const char* url, const char* bearer,
                const uint8_t* body, size_t bodyLen, String& respOut) {
    return request("POST", url, bearer, "application/json", body, bodyLen, respOut);
}

int netPostForm(const char* url, const String& formBody, String& respOut) {
    return request("POST", url, nullptr, "application/x-www-form-urlencoded",
                   (const uint8_t*)formBody.c_str(), formBody.length(), respOut);
}

int netGet(const char* url, const char* bearerToken, String& respOut) {
    return request("GET", url, bearerToken, nullptr, nullptr, 0, respOut);
}
