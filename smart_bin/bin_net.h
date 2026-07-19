#pragma once
#include <Arduino.h>

bool netWifiConnected();
// Throttled reconnect (WIFI_RETRY_MS between attempts). True when connected.
bool netEnsureWifi();
// One-shot boot report: IP/gateway/DNS/RSSI/heap + DNS resolution and TLS
// connect probes of both Google API hosts. Falls back to public DNS
// (8.8.8.8/1.1.1.1) when the router's DNS fails to resolve them.
void netBootDiag();
// Opens and immediately closes a TLS connection to host:443, logging the
// outcome and duration. Diagnostic only.
bool netTlsProbe(const char* host);
// All calls use TLS with setInsecure() — documented prototype risk (spec).
// Return HTTP status code, or negative on transport error. Body → respOut.
int netPostJson(const char* url, const char* bearerToken,
                const uint8_t* body, size_t bodyLen, String& respOut);
int netPostForm(const char* url, const String& formBody, String& respOut);
int netGet(const char* url, const char* bearerToken, String& respOut);
