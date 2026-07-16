#pragma once
#include <Arduino.h>

bool dispInit();
void dispBoot(const char* line2);          // "KitaKitar Bin" + status line
void dispReady();                          // idle screen
void dispAnalyzing();                      // during capture + Gemini
void dispResult(const char* label, float weightKg, float co2Kg); // recyclable outcome
void dispResidual(const char* label);      // residual/unknown outcome
void dispError(const char* line1, const char* line2);
// Full QR screen: QR (left) + points/countdown column (right).
void dispQr(const char* docId, long points, int secondsLeft);
// Repaints only the countdown line (no QR flicker).
void dispQrTick(int secondsLeft);
void dispClaimed();                        // "Points Claimed!"
