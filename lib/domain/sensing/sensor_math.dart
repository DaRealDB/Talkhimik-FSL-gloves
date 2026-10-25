/// Divider → ohms → angle math shared by the Live screen (display), the
/// calibration summary, and the dataset recorder (recompute from raw).
///
/// Wiring (concept C1, master §3): 3.3 V → flex sensor → ADC pin → R_DIV →
/// GND, so R_sensor = R_DIV × (4095 − adc) / adc. R_flat / R_bent90 / R_DIV
/// always come from CAL_INFO — never hard-coded.
library;

/// 12-bit SAR ADC full scale.
const int adcMax = 4095;

/// Divider ratio → sensor resistance. Rail readings saturate:
/// adc ≤ 0 → huge (open circuit), adc ≥ max → ~0 (short).
double adcToOhms(double rDiv, int adc) {
  if (adc <= 0) return double.maxFinite;
  if (adc >= adcMax) return 0.0;
  return rDiv * (adcMax - adc) / adc;
}

/// Two-point linear map resistance → angle. Works whether resistance rises
/// OR falls with bend (the sign cancels in the ratio); degenerate span → 0.
double ohmsToAngle(double r, double flat, double bent90) {
  final span = bent90 - flat;
  if (span == 0) return 0.0;
  return (90 * (r - flat) / span).clamp(0.0, 90.0).toDouble();
}

/// Wrap-safe: frames missed between two sequence numbers (u16 wraparound).
int seqGap(int last, int now) => (now - last - 1) & 0xFFFF;
