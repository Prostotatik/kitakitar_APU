#pragma once
#include <Arduino.h>

bool netWifiConnected();
// Throttled reconnect (WIFI_RETRY_MS between attempts). True when connected.
bool netEnsureWifi();
// All calls use TLS with setInsecure() — documented prototype risk (spec).
// Return HTTP status code, or negative on transport error. Body → respOut.
int netPostJson(const char* url, const char* bearerToken,
                const uint8_t* body, size_t bodyLen, String& respOut);
int netPostForm(const char* url, const String& formBody, String& respOut);
int netGet(const char* url, const char* bearerToken, String& respOut);
