#include <ESP8266WiFi.h>
#include <WebSocketsServer.h>

// =============================
// Motor Driver Pins (L298N)
// NodeMCU V3 — all on safe GPIOs
// =============================
#define ENA  D5   // GPIO14 (PWM)
#define IN1  D6   // GPIO12
#define IN2  D7   // GPIO13

#define ENB  D2   // GPIO4  (PWM)
#define IN3  D3   // GPIO0
#define IN4  D4   // GPIO2

// =============================
// Ultrasonic Sensors
// Shared trigger, separate echoes
// D8 = trigger (GPIO15 pulldown keeps LOW at boot = safe)
// D1 = front echo (boot-safe input)
// D0 = back echo (boot-safe input)
// =============================
#define TRIG  D8   // GPIO15 (shared trigger)
#define ECHO_FRONT  D1   // GPIO5 (front sensor)
#define ECHO_BACK   D0   // GPIO16 (back sensor)

// =============================
// Settings
// =============================
const int safeDistance = 10;     // cm
int currentSpeed = 180;         // adjustable from app

// =============================
// WiFi AP Settings
// =============================
const char* apSSID = "NodeMCU-Car";
const char* apPassword = "12345678";

// =============================
// WebSocket Server
// =============================
WebSocketsServer ws = WebSocketsServer(81);

// Current command from app
char currentCmd = 'S';
char lastNonStopCmd = 'S';
unsigned long lastNonStopTime = 0;
const unsigned long MIN_RUN_TIME = 100;

// Sensor data
float frontDistance = -1;
float backDistance = -1;

// =============================
// Setup
// =============================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n=== NodeMCU Car Controller ===");

  // Motor pins
  pinMode(IN1, OUTPUT);
  pinMode(IN2, OUTPUT);
  pinMode(IN3, OUTPUT);
  pinMode(IN4, OUTPUT);

  // Ultrasonic pins (shared trigger, dual echo)
  pinMode(TRIG, OUTPUT);
  digitalWrite(TRIG, LOW);
  pinMode(ECHO_FRONT, INPUT);
  pinMode(ECHO_BACK, INPUT);

  // Set PWM range and frequency for ESP8266
  analogWriteRange(255);
  analogWriteFreq(1000);

  stopMotors();

  // Motor test — brief pulse to verify wiring
  Serial.println("Motor test...");
  analogWrite(ENA, 200);
  analogWrite(ENB, 200);
  digitalWrite(IN1, HIGH); digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH); digitalWrite(IN4, LOW);
  delay(300);
  stopMotors();
  Serial.println("Motor test done.");

  // Start WiFi Access Point
  WiFi.softAP(apSSID, apPassword);
  Serial.print("AP IP: ");
  Serial.println(WiFi.softAPIP());

  // Start WebSocket server
  ws.begin();
  ws.onEvent(webSocketEvent);
  Serial.println("WebSocket started on port 81");
  Serial.println("Ready!");
}

// =============================
// WebSocket Event Handler
// =============================
void webSocketEvent(uint8_t num, WStype_t type, uint8_t* payload, size_t length) {
  switch (type) {
    case WStype_DISCONNECTED:
      Serial.printf("[%u] Disconnected\n", num);
      currentCmd = 'S';
      stopMotors();
      break;
    case WStype_CONNECTED:
      Serial.printf("[%u] Connected from %s\n", num, ws.remoteIP(num).toString().c_str());
      break;
    case WStype_TEXT:
      if (length > 0) {
        char cmd = (char)payload[0];

        // Speed command: "Vxxx" where xxx is 0-255
        if (length > 1 && cmd == 'V') {
          int speed = atoi((char*)(payload + 1));
          currentSpeed = constrain(speed, 0, 255);
          Serial.printf("Speed: %d\n", currentSpeed);
          return;
        }

        currentCmd = cmd;
        if (cmd != 'S') {
          lastNonStopCmd = cmd;
          lastNonStopTime = millis();
        }
        Serial.printf("Cmd: %c\n", cmd);
      }
      break;
    default:
      break;
  }
}

// =============================
// Main Loop
// =============================
unsigned long lastSensorUpdate = 0;

bool readFrontNext = true;

void loop() {
  ws.loop();

  // Read sensors (shared trigger, alternating echoes)
  readSensors();

  // Execute command with safety checks
  executeCommand();

  // Send sensor data to app every 100ms
  if (millis() - lastSensorUpdate > 100) {
    sendSensorData();
    lastSensorUpdate = millis();
  }

  delay(50);
}

// =============================
// Read Sensors (Alternating)
// =============================
void readSensors() {
  if (readFrontNext) {
    frontDistance = getDistance(ECHO_FRONT);
  } else {
    backDistance = getDistance(ECHO_BACK);
  }
  readFrontNext = !readFrontNext;
}

float getDistance(int echoPin) {
  digitalWrite(TRIG, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG, LOW);

  long duration = pulseIn(echoPin, HIGH, 30000);
  if (duration == 0) return -1;
  return duration * 0.0343 / 2;
}

// =============================
// Execute Command with Safety
// =============================
void executeCommand() {
  bool frontBlocked = (frontDistance > 0 && frontDistance < safeDistance);
  bool backBlocked = (backDistance > 0 && backDistance < safeDistance);

  char effectiveCmd = currentCmd;
  if (effectiveCmd == 'S' && lastNonStopCmd != 'S' && millis() - lastNonStopTime < MIN_RUN_TIME) {
    effectiveCmd = lastNonStopCmd;
  }

  switch (effectiveCmd) {
    case 'F':
      if (frontBlocked) {
        stopMotors();
        Serial.println("BLOCKED: Wall ahead!");
      } else {
        moveForward(currentSpeed);
      }
      break;
    case 'B':
      if (backBlocked) {
        stopMotors();
        Serial.println("BLOCKED: Wall behind!");
      } else {
        moveBackward(currentSpeed);
      }
      break;
    case 'L':
      turnLeft(currentSpeed);
      break;
    case 'R':
      turnRight(currentSpeed);
      break;
    case 'S':
    default:
      stopMotors();
      break;
  }
}

// =============================
// Send Sensor Data to App
// =============================
void sendSensorData() {
  String json = "{\"front\":";
  json += (frontDistance < 0) ? -1 : (int)frontDistance;
  json += ",\"back\":";
  json += (backDistance < 0) ? -1 : (int)backDistance;
  json += ",\"frontBlocked\":";
  json += (frontDistance > 0 && frontDistance < safeDistance) ? "true" : "false";
  json += ",\"backBlocked\":";
  json += (backDistance > 0 && backDistance < safeDistance) ? "true" : "false";
  json += ",\"speed\":";
  json += currentSpeed;
  json += "}";

  ws.broadcastTXT(json);
}

// =============================
// Motor Functions
// =============================
void moveForward(int speedVal) {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
  analogWrite(ENA, speedVal);
  analogWrite(ENB, speedVal);
}

void moveBackward(int speedVal) {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
  analogWrite(ENA, speedVal);
  analogWrite(ENB, speedVal);
}

void turnRight(int speedVal) {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, HIGH);
  digitalWrite(IN3, HIGH);
  digitalWrite(IN4, LOW);
  analogWrite(ENA, speedVal);
  analogWrite(ENB, speedVal);
}

void turnLeft(int speedVal) {
  digitalWrite(IN1, HIGH);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, HIGH);
  analogWrite(ENA, speedVal);
  analogWrite(ENB, speedVal);
}

void stopMotors() {
  digitalWrite(IN1, LOW);
  digitalWrite(IN2, LOW);
  digitalWrite(IN3, LOW);
  digitalWrite(IN4, LOW);
  analogWrite(ENA, 0);
  analogWrite(ENB, 0);
}