// ╔══════════════════════════════════════════════════════════════════╗
// ║  KitaKitar Smart Bin — standalone ESP32-CAM firmware             ║
// ║  Ultrasonic → camera → Gemini → Firestore QR → OLED → servo      ║
// ║  Spec: SPEC-smart-bin-standalone.md                              ║
// ╚══════════════════════════════════════════════════════════════════╝
#include <Arduino.h>
#include "config.h"
#include "bin_hw.h"
#include "bin_display.h"
#include "bin_net.h"
#include "bin_firebase.h"
#include "bin_gemini.h"

enum BinState { ST_IDLE, ST_SETTLE, ST_RESULT, ST_QR_ACTIVE, ST_CLAIMED, ST_ERROR };

static BinState state = ST_IDLE;
static BinState afterTimed = ST_IDLE;     // where timed screens return to
static unsigned long stateUntil = 0;      // timed-screen deadline

static SessionItem session[MAX_SESSION_ITEMS];
static int sessionCount = 0;
static char curDocId[21] = "";
static String curUpdateTime;
static unsigned long sessionDeadline = 0; // 30 s inactivity window

static bool armed = false;                // chamber must read clear to re-arm
static int aboveCount = 0, belowCount = 0;
static unsigned long lastDistanceRead = 0;
static unsigned long settleAt = 0;
static unsigned long lastPoll = 0;
static int lastTickSec = -1;

// ── Session helpers ──────────────────────────────────────────────────
static bool sessionActive() { return sessionCount > 0 && curDocId[0] != '\0'; }

static void clearSession() {
    sessionCount = 0;
    curDocId[0] = '\0';
    curUpdateTime = "";
}

// Display-only estimate mirroring mobile QRService (all bin items isFree).
static long estimatePoints() {
    float sum = 0;
    for (int i = 0; i < sessionCount; i++)
        sum += session[i].weightKg * POINTS_BASE_MULTIPLIER * POINTS_FREE_BONUS +
               session[i].co2Kg * POINTS_CO2_MULTIPLIER;
    return lroundf(sum);
}

static int secondsLeft() {
    long ms = (long)(sessionDeadline - millis());
    return ms > 0 ? (int)(ms / 1000) : 0;
}

static void enterTimed(BinState timedState, unsigned long durMs, BinState next) {
    state = timedState;
    stateUntil = millis() + durMs;
    afterTimed = next;
}

static void showQrScreen() {
    lastTickSec = -1;
    lastPoll = millis();
    dispQr(curDocId, estimatePoints(), secondsLeft());
    state = ST_QR_ACTIVE;
}

// Fail-closed: residual side, nothing written, session QR stays alive.
static void failDeposit(const char* msg) {
    Serial.printf("[BIN] deposit failed: %s\n", msg);
    hwServoSort(false);
    dispError(msg, "Item -> residual");
    // a slow/failed deposit must not eat the user's scan window
    if (sessionActive()) sessionDeadline = millis() + SESSION_TIMEOUT_MS;
    enterTimed(ST_ERROR, ERROR_SCREEN_MS, sessionActive() ? ST_QR_ACTIVE : ST_IDLE);
}

// ── Deposit pipeline (synchronous: capture → Gemini → commit → sort) ─
static void processDeposit() {
    dispAnalyzing();
    camera_fb_t* fb = hwCaptureJpeg();
    if (!fb) { failDeposit("Camera error"); return; }
    GeminiResult r;
    bool ok = geminiClassify(fb, r);  // consumes fb (returned before upload)
    if (!ok) { failDeposit("AI unavailable"); return; }

    const char* slug = categoryToSlug(r.category);
    if (!slug) {
        hwServoSort(false);
        dispResidual(categoryLabel(r.category));
        // a slow/failed deposit must not eat the user's scan window
        if (sessionActive()) sessionDeadline = millis() + SESSION_TIMEOUT_MS;
        enterTimed(ST_RESULT, RESULT_SCREEN_MS,
                   sessionActive() ? ST_QR_ACTIVE : ST_IDLE);
        return;
    }

    // Merging into an active session: re-read `used` first (spec race guard).
    const char* superseded = nullptr;
    if (sessionActive()) {
        bool used = false; String t;
        int st = fbGetQrUsed(curDocId, used, t);
        if (st == 200 && used) {
            dispClaimed();
            delay(1500);              // rare race — brief blocking ack is fine
            clearSession();
        } else if (st == 200) {
            curUpdateTime = t;        // freshest updateTime → delete precondition
            superseded = curDocId;
        } else if (st == 404) {
            clearSession();           // only firmware deletes docs
        } else {
            failDeposit("Network error");
            return;
        }
    }

    if (sessionCount >= MAX_SESSION_ITEMS) { failDeposit("Session full"); return; }
    SessionItem& it = session[sessionCount];
    strlcpy(it.slug, slug, sizeof(it.slug));
    it.weightKg = r.weightKg;
    it.co2Kg = r.co2Kg;
    sessionCount++;

    char newId[21];
    fbGenerateDocId(newId);
    String newTime;
    int st = fbCommitQr(session, sessionCount, newId,
                        superseded, superseded ? curUpdateTime.c_str() : nullptr,
                        newTime);

    if (st != 200 && superseded) {
        // Atomic commit lost its precondition: the shown QR was claimed
        // between our GET and the commit. Acknowledge, restart the session
        // with only the new item (spec, session model).
        bool used = false; String t;
        if (fbGetQrUsed(superseded, used, t) == 200 && used) {
            dispClaimed();
            delay(1500);
            session[0] = session[sessionCount - 1];
            sessionCount = 1;
            curDocId[0] = '\0';
            fbGenerateDocId(newId);
            st = fbCommitQr(session, 1, newId, nullptr, nullptr, newTime);
        }
    }
    // A transport error (st < 0) does not prove the write never landed: the
    // commit may have succeeded server-side with only the response lost. Ask
    // Firestore before dropping the item (spec: a failure must write nothing).
    // newId holds the last attempted doc ID, so this covers both commits above.
    if (st != 200) {
        bool landed = false;
        String landedTime;
        if (fbGetQrUsed(newId, landed, landedTime) == 200) {
            st = 200;                 // the doc exists — the commit did land
            newTime = landedTime;     // adopt its updateTime for the next delete
        }
    }

    if (st != 200) {
        sessionCount--;               // nothing was written — drop the item
        failDeposit("Save failed");
        return;
    }

    strlcpy(curDocId, newId, sizeof(curDocId));
    curUpdateTime = newTime;
    sessionDeadline = millis() + SESSION_TIMEOUT_MS;
    hwServoSort(true);                // sort only AFTER the commit succeeded
    dispResult(categoryLabel(r.category), r.weightKg, r.co2Kg);
    enterTimed(ST_RESULT, RESULT_SCREEN_MS, ST_QR_ACTIVE);
}

// ── Setup ────────────────────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    delay(300);
    Serial.println("\n=== KitaKitar Smart Bin (standalone) ===");
    hwServoInit();
    hwUltraInit();
    dispInit();
    dispBoot("starting...");
    if (!hwCameraInit()) { dispBoot("CAMERA FAILED"); delay(ERROR_SCREEN_MS); }
    if (!psramFound())
        Serial.println("[MEM] WARNING: PSRAM missing — enable Tools > PSRAM");
    dispBoot("wifi...");
    while (!netWifiConnected()) { netEnsureWifi(); delay(1000); }
    netBootDiag();
    dispBoot("signing in...");
    if (!fbSignIn()) { dispBoot("auth failed"); delay(ERROR_SCREEN_MS); }  // deposits fail-closed until OK
    clearSession();
    dispReady();
    state = ST_IDLE;
}

// ── Main loop ────────────────────────────────────────────────────────
void loop() {
    hwServoUpdate();
    netEnsureWifi();                  // throttled reconnect (story 26)
    unsigned long now = millis();

    // Timed screens (result / claimed / error) → next state.
    if ((state == ST_RESULT || state == ST_CLAIMED || state == ST_ERROR) &&
        (long)(now - stateUntil) >= 0) {
        if (afterTimed == ST_QR_ACTIVE && sessionActive()) showQrScreen();
        else { clearSession(); dispReady(); state = ST_IDLE; }
    }

    // QR screen: countdown, expiry, redemption polling.
    if (state == ST_QR_ACTIVE) {
        int sl = secondsLeft();
        if (sl <= 0) {
            Serial.println("[BIN] session expired");
            clearSession();
            dispReady();
            state = ST_IDLE;
        } else {
            if (sl != lastTickSec) { lastTickSec = sl; dispQrTick(sl); }
            if (now - lastPoll >= QR_POLL_INTERVAL_MS) {
                lastPoll = now;
                bool used = false; String t;
                int st = fbGetQrUsed(curDocId, used, t);
                if (st == 200) {
                    curUpdateTime = t;
                    if (used) {
                        Serial.println("[BIN] points claimed");
                        clearSession();
                        dispClaimed();
                        enterTimed(ST_CLAIMED, CLAIMED_SCREEN_MS, ST_IDLE);
                    }
                } else if (st == 404) {
                    clearSession();
                    dispReady();
                    state = ST_IDLE;
                } // transient errors: ignore, countdown continues
            }
        }
    }

    // Ultrasonic watch (idle or while a QR is showing), servo at rest.
    if ((state == ST_IDLE || state == ST_QR_ACTIVE) && hwServoIdle() &&
        now - lastDistanceRead >= DISTANCE_POLL_MS) {
        lastDistanceRead = now;
        float d = hwReadDistanceCm();
#if DEBUG_ULTRA_LOG
        // 1 Hz summary of the ~10 reads since the last line. `timeout` counts
        // reads with no echo at all (reported as 999 = "chamber clear").
        static unsigned long ultraLogAt = 0;
        static int ultraOk = 0, ultraTimeout = 0;
        static float ultraLast = -1.0f;
        if (d >= 998.0f) ultraTimeout++; else { ultraOk++; ultraLast = d; }
        if ((long)(now - ultraLogAt) >= 1000) {
            ultraLogAt = now;
            int idle = -1, trans = 0;
            hwUltraProbe(idle, trans);
            Serial.printf("[ULTRA] last=%.1fcm ok=%d timeout=%d idle=%d trans=%d armed=%d above=%d below=%d\n",
                          ultraLast, ultraOk, ultraTimeout, idle, trans,
                          (int)armed, aboveCount, belowCount);
            ultraOk = ultraTimeout = 0;
        }
#endif
        if (!armed) {
            if (d >= CLEAR_DISTANCE_CM) {
                if (++aboveCount >= CLEAR_CONSECUTIVE) { armed = true; aboveCount = 0; }
            } else aboveCount = 0;
        } else if (d > 0 && d <= TRIGGER_DISTANCE_CM) {
            if (++belowCount >= DETECT_CONSECUTIVE) {
                belowCount = 0;
                armed = false;        // re-arm requires the chamber to clear
                settleAt = now + SETTLE_DELAY_MS;
                state = ST_SETTLE;    // QR (if any) stays on screen meanwhile
                Serial.printf("[BIN] deposit detected at %.1f cm\n", d);
            }
        } else belowCount = 0;
    }

    if (state == ST_SETTLE && (long)(now - settleAt) >= 0) processDeposit();
}
