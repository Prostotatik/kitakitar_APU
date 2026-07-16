#pragma once
#include <Arduino.h>

// One deposited item held in the session (slug is a material slug).
struct SessionItem {
    char slug[16];
    float weightKg;
    float co2Kg;
};

// Identity Toolkit signInWithPassword with the bin's dedicated account.
bool fbSignIn();
// Refreshes ~5 min before expiry (securetoken). True if a valid token is held.
bool fbEnsureToken();
// 20-char Firestore-style auto-ID (out must hold 21 bytes).
void fbGenerateDocId(char out[21]);
// Atomic commit: create qr_codes/{newDocId} from items[0..count) and, when
// supersededDocId is non-null/non-empty, delete qr_codes/{supersededDocId}
// guarded by supersededUpdateTime (RFC3339 from the last GET). On HTTP 200
// fills newUpdateTimeOut with the new doc's updateTime.
// Non-200 (incl. 400/409 FAILED_PRECONDITION when a claim raced) = no writes.
int fbCommitQr(const SessionItem* items, int count, const char* newDocId,
               const char* supersededDocId, const char* supersededUpdateTime,
               String& newUpdateTimeOut);
// Field-masked GET of qr_codes/{docId}: fills usedOut + updateTimeOut.
// Returns HTTP status (200 exists, 404 deleted/absent, other = error).
int fbGetQrUsed(const char* docId, bool& usedOut, String& updateTimeOut);
