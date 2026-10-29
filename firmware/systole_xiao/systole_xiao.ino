// Systole reference firmware for Seeed XIAO nRF52840 (protocol v1, see PROTOCOL.md).
//
// Board package: "Seeed nRF52 Boards" (non-mbed), which provides Bluefruit.
// Samples an analog PPG front end on A0 and streams it to the Systole app.
// runModel() is a PLACEHOLDER: replace it with the real on-device model.
// Not compiled or tested on hardware yet; treat it as a starting point.

#include <bluefruit.h>

#define PPG_PIN        A0
#define SAMPLE_RATE_HZ 100
#define FW_MAJOR       1
#define FW_MINOR       0
#define MODEL_VERSION  0
#define WINDOW_SEC     15
#define RESULT_EVERY_MS 3000

// 7d2a000X-6c3b-4e5f-8a9b-0c1d2e3f4a5b, bytes reversed for Bluefruit.
#define SYSTOLE_UUID(x) { 0x5b, 0x4a, 0x3f, 0x2e, 0x1d, 0x0c, 0x9b, 0x8a, \
                          0x5f, 0x4e, 0x3b, 0x6c, x, 0x00, 0x2a, 0x7d }

const uint8_t UUID_SVC[]     = SYSTOLE_UUID(0x01);
const uint8_t UUID_PPG[]     = SYSTOLE_UUID(0x02);
const uint8_t UUID_BP[]      = SYSTOLE_UUID(0x03);
const uint8_t UUID_INFO[]    = SYSTOLE_UUID(0x04);
const uint8_t UUID_PROFILE[] = SYSTOLE_UUID(0x05);
const uint8_t UUID_CAL[]     = SYSTOLE_UUID(0x06);
const uint8_t UUID_CTRL[]    = SYSTOLE_UUID(0x07);

BLEService        svc(UUID_SVC);
BLECharacteristic chrPpg(UUID_PPG);
BLECharacteristic chrBp(UUID_BP);
BLECharacteristic chrInfo(UUID_INFO);
BLECharacteristic chrProfile(UUID_PROFILE);
BLECharacteristic chrCal(UUID_CAL);
BLECharacteristic chrCtrl(UUID_CTRL);
BLEBas            bas;

// --- state -----------------------------------------------------------------
struct Profile { uint8_t age = 30; uint8_t male = 1; float heightCm = 170; float weightKg = 70; } profile;
bool  streaming = false;
bool  calibrated = false;
float baseSbp = 0, baseDbp = 0;

const int WINDOW_N = SAMPLE_RATE_HZ * WINDOW_SEC;
uint16_t window_[WINDOW_N];   // ring buffer holding the model's input window
int      winHead = 0, winCount = 0;

uint16_t batch[100];
uint8_t  batchLen = 0;
uint16_t seq = 0;
uint32_t nextSampleUs, lastResultMs;

// --- model hook ------------------------------------------------------------
struct BpEstimate { float sbp, dbp; uint8_t hr, quality; bool motion; };

// PLACEHOLDER. Feed `window_` (chronological via winHead/winCount), `profile`
// and the calibration baseline into the real model here.
bool runModel(BpEstimate* out) {
  if (winCount < SAMPLE_RATE_HZ * 5) return false;   // need a few seconds of signal
  out->sbp = calibrated ? baseSbp : 120;
  out->dbp = calibrated ? baseDbp : 80;
  out->hr = 70;
  out->quality = 90;
  out->motion = false;
  return true;
}

// --- BLE write handlers ----------------------------------------------------
void onProfile(uint16_t, BLECharacteristic*, uint8_t* d, uint16_t len) {
  if (len < 6) return;
  profile.age = d[0];
  profile.male = d[1];
  profile.heightCm = (d[2] | (d[3] << 8)) / 10.0f;
  profile.weightKg = (d[4] | (d[5] << 8)) / 10.0f;
}

void onCalibration(uint16_t, BLECharacteristic*, uint8_t* d, uint16_t len) {
  if (len < 4) return;
  baseSbp = (d[0] | (d[1] << 8)) / 10.0f;
  baseDbp = (d[2] | (d[3] << 8)) / 10.0f;
  calibrated = true;   // the real model should also snapshot the current window here
}

void onControl(uint16_t, BLECharacteristic*, uint8_t* d, uint16_t len) {
  if (len < 1) return;
  if (d[0] == 0x01) streaming = true;
  if (d[0] == 0x02) streaming = false;
  if (d[0] == 0x03) calibrated = false;
}

void onDisconnect(uint16_t, uint8_t) { streaming = false; }

void setupBle() {
  Bluefruit.configPrphBandwidth(BANDWIDTH_MAX);   // allows MTU up to 247
  Bluefruit.begin();
  Bluefruit.setTxPower(4);
  char name[16];
  snprintf(name, sizeof(name), "Systole-%04X", (uint16_t)(NRF_FICR->DEVICEADDR[0] & 0xFFFF));
  Bluefruit.setName(name);
  Bluefruit.Periph.setDisconnectCallback(onDisconnect);

  svc.begin();

  chrPpg.setProperties(CHR_PROPS_NOTIFY);
  chrPpg.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
  chrPpg.setMaxLen(4 + sizeof(batch));
  chrPpg.begin();

  chrBp.setProperties(CHR_PROPS_NOTIFY);
  chrBp.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
  chrBp.setFixedLen(12);
  chrBp.begin();

  chrInfo.setProperties(CHR_PROPS_READ);
  chrInfo.setPermission(SECMODE_OPEN, SECMODE_NO_ACCESS);
  chrInfo.setFixedLen(6);
  chrInfo.begin();
  updateInfo();

  chrProfile.setProperties(CHR_PROPS_WRITE);
  chrProfile.setPermission(SECMODE_NO_ACCESS, SECMODE_OPEN);
  chrProfile.setFixedLen(6);
  chrProfile.setWriteCallback(onProfile);
  chrProfile.begin();

  chrCal.setProperties(CHR_PROPS_WRITE);
  chrCal.setPermission(SECMODE_NO_ACCESS, SECMODE_OPEN);
  chrCal.setFixedLen(4);
  chrCal.setWriteCallback(onCalibration);
  chrCal.begin();

  chrCtrl.setProperties(CHR_PROPS_WRITE);
  chrCtrl.setPermission(SECMODE_NO_ACCESS, SECMODE_OPEN);
  chrCtrl.setFixedLen(1);
  chrCtrl.setWriteCallback(onControl);
  chrCtrl.begin();

  bas.begin();
  bas.write(100);

  Bluefruit.Advertising.addFlags(BLE_GAP_ADV_FLAGS_LE_ONLY_GENERAL_DISC_MODE);
  Bluefruit.Advertising.addService(svc);
  Bluefruit.ScanResponse.addName();
  Bluefruit.Advertising.restartOnDisconnect(true);
  Bluefruit.Advertising.start(0);
}

void updateInfo() {
  uint8_t info[6] = { SAMPLE_RATE_HZ & 0xFF, SAMPLE_RATE_HZ >> 8,
                      FW_MAJOR, FW_MINOR, MODEL_VERSION, (uint8_t)(calibrated ? 1 : 0) };
  chrInfo.write(info, sizeof(info));
}

// Largest batch that fits the negotiated MTU (3 bytes ATT header, 4 bytes ours).
uint8_t maxBatch() {
  uint16_t conn = Bluefruit.connHandle();
  BLEConnection* c = Bluefruit.Connection(conn);
  uint16_t mtu = c ? c->getMtu() : 23;
  int n = (mtu - 3 - 4) / 2;
  return (uint8_t)constrain(n, 1, 40);
}

void sendBatch() {
  uint8_t pkt[4 + sizeof(batch)];
  pkt[0] = seq & 0xFF; pkt[1] = seq >> 8;
  pkt[2] = 0;          // format: u16
  pkt[3] = batchLen;
  memcpy(pkt + 4, batch, batchLen * 2);
  chrPpg.notify(pkt, 4 + batchLen * 2);
  seq++;
  batchLen = 0;
}

void sendResult(const BpEstimate& e) {
  uint32_t ms = millis();
  uint16_t sbp = (uint16_t)(e.sbp * 10), dbp = (uint16_t)(e.dbp * 10);
  uint8_t flags = (calibrated ? 0x01 : 0) | (e.motion ? 0x02 : 0) | (e.quality < 70 ? 0x04 : 0);
  uint8_t pkt[12] = { (uint8_t)ms, (uint8_t)(ms >> 8), (uint8_t)(ms >> 16), (uint8_t)(ms >> 24),
                      (uint8_t)sbp, (uint8_t)(sbp >> 8), (uint8_t)dbp, (uint8_t)(dbp >> 8),
                      e.hr, e.quality, flags, 0 };
  chrBp.notify(pkt, sizeof(pkt));
}

void setup() {
  analogReadResolution(12);
  setupBle();
  nextSampleUs = micros();
}

void loop() {
  if ((int32_t)(micros() - nextSampleUs) < 0) return;
  nextSampleUs += 1000000UL / SAMPLE_RATE_HZ;

  uint16_t s = analogRead(PPG_PIN);
  window_[winHead] = s;
  winHead = (winHead + 1) % WINDOW_N;
  if (winCount < WINDOW_N) winCount++;

  if (!streaming || !Bluefruit.connected()) { batchLen = 0; return; }

  batch[batchLen++] = s;
  if (batchLen >= maxBatch()) sendBatch();

  if (millis() - lastResultMs >= RESULT_EVERY_MS) {
    lastResultMs = millis();
    BpEstimate e;
    if (runModel(&e)) sendResult(e);
    updateInfo();
  }
}
