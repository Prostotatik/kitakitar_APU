#include "bin_firebase.h"
#include "bin_net.h"
#include "config.h"
#include <ArduinoJson.h>

#define FS_DOC_PREFIX "projects/" FIREBASE_PROJECT_ID \
    "/databases/(default)/documents/qr_codes/"
#define FS_COMMIT_URL "https://firestore.googleapis.com/v1/projects/" \
    FIREBASE_PROJECT_ID "/databases/(default)/documents:commit"
#define FS_DOC_URL "https://firestore.googleapis.com/v1/projects/" \
    FIREBASE_PROJECT_ID "/databases/(default)/documents/qr_codes/"
#define AUTH_SIGNIN_URL \
    "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" \
    FIREBASE_API_KEY
#define AUTH_REFRESH_URL \
    "https://securetoken.googleapis.com/v1/token?key=" FIREBASE_API_KEY

static String s_idToken;
static String s_refreshToken;
static unsigned long s_tokenBornMs = 0;
static long s_expiresSec = 0;

bool fbSignIn() {
    JsonDocument req;
    req["email"] = BIN_AUTH_EMAIL;
    req["password"] = BIN_AUTH_PASSWORD;
    req["returnSecureToken"] = true;
    String body; serializeJson(req, body);
    String resp;
    int code = netPostJson(AUTH_SIGNIN_URL, nullptr,
                           (const uint8_t*)body.c_str(), body.length(), resp);
    if (code != 200) {
        Serial.printf("[AUTH] signIn failed: %d %s\n", code, resp.c_str());
        return false;
    }
    JsonDocument doc;
    if (deserializeJson(doc, resp) != DeserializationError::Ok) return false;
    s_idToken = doc["idToken"].as<String>();
    s_refreshToken = doc["refreshToken"].as<String>();
    s_expiresSec = atol(doc["expiresIn"] | "3600");
    s_tokenBornMs = millis();
    Serial.println("[AUTH] Signed in");
    return s_idToken.length() > 0;
}

static bool refreshToken() {
    if (s_refreshToken.isEmpty()) return false;
    String form = String("grant_type=refresh_token&refresh_token=") + s_refreshToken;
    String resp;
    int code = netPostForm(AUTH_REFRESH_URL, form, resp);
    if (code != 200) {
        Serial.printf("[AUTH] refresh failed: %d\n", code);
        return false;
    }
    JsonDocument doc;
    if (deserializeJson(doc, resp) != DeserializationError::Ok) return false;
    s_idToken = doc["id_token"].as<String>();
    s_refreshToken = doc["refresh_token"].as<String>();
    s_expiresSec = atol(doc["expires_in"] | "3600");
    s_tokenBornMs = millis();
    Serial.println("[AUTH] Token refreshed");
    return s_idToken.length() > 0;
}

bool fbEnsureToken() {
    if (s_idToken.isEmpty()) return fbSignIn();
    unsigned long age = millis() - s_tokenBornMs;               // wrap-safe
    if (age > (unsigned long)(s_expiresSec > 300 ? s_expiresSec - 300 : 60) * 1000UL) {
        if (refreshToken()) return true;
        s_idToken = "";
        return fbSignIn();
    }
    return true;
}

void fbGenerateDocId(char out[21]) {
    static const char alphabet[] =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
    for (int i = 0; i < 20; i++) out[i] = alphabet[esp_random() % 62];
    out[20] = '\0';
}

int fbCommitQr(const SessionItem* items, int count, const char* newDocId,
               const char* supersededDocId, const char* supersededUpdateTime,
               String& newUpdateTimeOut) {
    if (!fbEnsureToken()) return -10;
    JsonDocument doc;
    JsonArray writes = doc["writes"].to<JsonArray>();

    JsonObject w0 = writes.add<JsonObject>();
    JsonObject upd = w0["update"].to<JsonObject>();
    upd["name"] = String(FS_DOC_PREFIX) + newDocId;
    JsonObject f = upd["fields"].to<JsonObject>();
    f["centerId"]["stringValue"] = BIN_CENTER_ID;
    f["used"]["booleanValue"] = false;
    JsonObject draft = f["transactionDraft"]["mapValue"]["fields"].to<JsonObject>();
    JsonArray vals = draft["materials"]["arrayValue"]["values"].to<JsonArray>();
    float total = 0;
    for (int i = 0; i < count; i++) {
        JsonObject mf = vals.add<JsonObject>()["mapValue"]["fields"].to<JsonObject>();
        mf["type"]["stringValue"] = items[i].slug;
        mf["weight"]["doubleValue"] = items[i].weightKg;
        mf["pricePerKg"]["doubleValue"] = 0.0;
        mf["isFree"]["booleanValue"] = true;
        mf["co2"]["doubleValue"] = items[i].co2Kg;
        total += items[i].weightKg;
    }
    draft["totalWeight"]["doubleValue"] = total;
    w0["currentDocument"]["exists"] = false;
    JsonObject tr = w0["updateTransforms"].to<JsonArray>().add<JsonObject>();
    tr["fieldPath"] = "createdAt";
    tr["setToServerValue"] = "REQUEST_TIME";

    if (supersededDocId && supersededDocId[0]) {
        JsonObject w1 = writes.add<JsonObject>();
        w1["delete"] = String(FS_DOC_PREFIX) + supersededDocId;
        if (supersededUpdateTime && supersededUpdateTime[0])
            w1["currentDocument"]["updateTime"] = supersededUpdateTime;
    }

    String body; serializeJson(doc, body);
    String resp;
    int code = netPostJson(FS_COMMIT_URL, s_idToken.c_str(),
                           (const uint8_t*)body.c_str(), body.length(), resp);
    if (code == 401 && fbEnsureToken())   // expired mid-flight: retry once
        code = netPostJson(FS_COMMIT_URL, s_idToken.c_str(),
                           (const uint8_t*)body.c_str(), body.length(), resp);
    if (code == 200) {
        JsonDocument r;
        if (deserializeJson(r, resp) == DeserializationError::Ok)
            newUpdateTimeOut = r["writeResults"][0]["updateTime"].as<String>();
    } else {
        Serial.printf("[FS] commit failed: %d %s\n", code, resp.c_str());
    }
    return code;
}

int fbGetQrUsed(const char* docId, bool& usedOut, String& updateTimeOut) {
    if (!fbEnsureToken()) return -10;
    String url = String(FS_DOC_URL) + docId + "?mask.fieldPaths=used";
    String resp;
    int code = netGet(url.c_str(), s_idToken.c_str(), resp);
    if (code == 401 && fbEnsureToken())
        code = netGet(url.c_str(), s_idToken.c_str(), resp);
    if (code == 200) {
        JsonDocument doc;
        if (deserializeJson(doc, resp) != DeserializationError::Ok) return -11;
        usedOut = doc["fields"]["used"]["booleanValue"] | false;
        updateTimeOut = doc["updateTime"].as<String>();
    }
    return code;
}
