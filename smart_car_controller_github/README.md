<div align="center">

<h1>🚗 Smart Car Controller</h1>

<p>
  <strong>A real-time, Wi-Fi controlled RC car built on NodeMCU (ESP8266) with a Flutter mobile app.</strong><br/>
  Drive your car from your phone — no internet, no router required.
</p>

<p>
  <img src="https://img.shields.io/badge/Platform-ESP8266-blue?logo=arduino&logoColor=white" alt="ESP8266"/>
  <img src="https://img.shields.io/badge/Mobile-Flutter-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Protocol-WebSocket-4A90D9?logo=websocket&logoColor=white" alt="WebSocket"/>
  <img src="https://img.shields.io/badge/Motor%20Driver-L298N-green" alt="L298N"/>
  <img src="https://img.shields.io/badge/Sensors-HC--SR04%20×2-orange" alt="HC-SR04"/>
  <img src="https://img.shields.io/badge/License-MIT-lightgrey" alt="MIT License"/>
</p>

</div>

---

## 📖 Table of Contents

- [Overview](#-overview)
- [Features](#-features)
- [System Architecture](#-system-architecture)
- [Repository Structure](#-repository-structure)
- [Hardware](#-hardware)
  - [Bill of Materials](#bill-of-materials)
  - [Wiring Diagram](#wiring-diagram)
- [Getting Started](#-getting-started)
  - [1. Flash the Firmware](#1-flash-the-firmware)
  - [2. Build & Run the App](#2-build--run-the-app)
  - [3. Connect & Drive](#3-connect--drive)
- [Communication Protocol](#-communication-protocol)
- [Configuration](#️-configuration)
- [Project Roadmap](#-project-roadmap)
- [License](#-license)

---

## 🔍 Overview

**Smart Car Controller** is a complete, end-to-end embedded IoT system that turns a NodeMCU V3 (ESP8266) into a self-hosted wireless robot car. The microcontroller runs a **WebSocket server** over its own Wi-Fi Access Point, while the **Flutter** mobile application acts as the real-time control panel — no external infrastructure needed.

The system also features **autonomous collision prevention**: dual HC-SR04 ultrasonic sensors continuously monitor the front and rear proximity, automatically halting the car when an obstacle is detected within the configurable safe distance.

---

## ✨ Features

| Feature | Details |
|---|---|
| 📡 **Standalone Wi-Fi AP** | The car creates its own hotspot — connect directly from your phone |
| 🎮 **Real-time D-Pad Control** | Forward, Backward, Left, Right and Stop over WebSocket |
| 🚧 **Collision Prevention** | Dual HC-SR04 sensors (front & rear) auto-stop the car at < 10 cm |
| ⚡ **Adjustable Speed** | PWM speed (0–255) controlled from an in-app slider |
| 📊 **Live Sensor Telemetry** | Distance values and blocked/clear status streamed every 100 ms |
| 🌙 **Dark Mode Flutter UI** | Clean, responsive interface with animated status cards |
| 🔄 **Auto-stop on Disconnect** | Motors are immediately cut when the app disconnects |

---

## 🏗 System Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Mobile App (Flutter)                      │
│                                                             │
│   ┌───────────┐   ┌──────────────────┐   ┌─────────────┐   │
│   │  D-Pad    │   │  Sensor Panel    │   │   Speed     │   │
│   │  Buttons  │   │  Front / Rear    │   │   Slider    │   │
│   └─────┬─────┘   └────────┬─────────┘   └──────┬──────┘   │
│         │                  │                    │           │
│         └──────────────────▼────────────────────┘           │
│                      WebSocket Client                        │
└──────────────────────────┬──────────────────────────────────┘
                           │  Wi-Fi  •  192.168.4.1:81
┌──────────────────────────▼──────────────────────────────────┐
│                NodeMCU V3 (ESP8266) Firmware                 │
│                                                             │
│   ┌────────────────┐  ┌──────────────┐  ┌───────────────┐  │
│   │  WebSocket     │  │  Motor Ctrl  │  │ HC-SR04 Read  │  │
│   │  Server :81    │  │  L298N PWM   │  │ Front & Rear  │  │
│   └────────────────┘  └──────────────┘  └───────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

**Data Flow:**

- **App → Car:** Single-character commands (`F`, `B`, `L`, `R`, `S`) or speed updates (`V<0-255>`) sent as WebSocket text frames.
- **Car → App:** JSON telemetry broadcast every 100 ms:
  ```json
  { "front": 25, "back": 42, "frontBlocked": false, "backBlocked": false, "speed": 180 }
  ```

---

## 📂 Repository Structure

```
smart_car_controller/
│
├── firmware/
│   └── smart_car_controller/
│       └── smart_car_controller.ino   # ESP8266 Arduino sketch
│
├── flutter_app/
│   ├── lib/
│   │   └── main.dart                  # Complete Flutter application
│   ├── analysis_options.yaml
│   └── pubspec.yaml
│
├── .gitignore
└── README.md
```

---

## 🔩 Hardware

### Bill of Materials

| # | Component | Qty | Notes |
|---|---|---|---|
| 1 | **NodeMCU V3 (ESP8266)** | 1 | Main controller + Wi-Fi chip |
| 2 | **L298N Motor Driver Module** | 1 | Dual H-bridge, handles up to 2 A |
| 3 | **HC-SR04 Ultrasonic Sensor** | 2 | Front & rear obstacle detection |
| 4 | **DC Gear Motor (TT Motor)** | 2 | ~200 RPM, 3–6 V |
| 5 | **Rubber Wheels** | 2 | Matching wheel hub for TT motor |
| 6 | **Caster Wheel** | 1 | Front balance wheel |
| 7 | **18650 Battery Pack (2S)** | 1 | ~7.4 V → L298N VIN; 5 V regulator for NodeMCU |
| 8 | **Jumper Wires** | — | Male-to-male & male-to-female |
| 9 | **Chassis** | 1 | 2WD acrylic or aluminum robot chassis |

### Wiring Diagram

```
NodeMCU Pin    →   Component
─────────────────────────────────────────────────────
D5 (GPIO14)    →   L298N ENA   (Motor A PWM)
D6 (GPIO12)    →   L298N IN1
D7 (GPIO13)    →   L298N IN2
D2 (GPIO4)     →   L298N ENB   (Motor B PWM)
D3 (GPIO0)     →   L298N IN3
D4 (GPIO2)     →   L298N IN4
D8 (GPIO15)    →   HC-SR04 TRIG  (shared, both sensors)
D1 (GPIO5)     →   HC-SR04 ECHO  (front sensor)
D0 (GPIO16)    →   HC-SR04 ECHO  (rear sensor)
3.3 V          →   HC-SR04 VCC  (both)
GND            →   GND (L298N, HC-SR04, common ground)
```

> [!NOTE]
> GPIO15 (D8) has a built-in pull-down resistor on NodeMCU, making it safe to use as TRIG — it stays LOW at boot, preventing unintended pulses during startup.

---

## 🚀 Getting Started

### 1. Flash the Firmware

**Prerequisites:**
- [Arduino IDE 2.x](https://www.arduino.cc/en/software)
- ESP8266 board package installed (`https://arduino.esp8266.com/stable/package_esp8266com_index.json`)
- Libraries: `WebSockets` by Markus Sattler (install via Library Manager)

**Steps:**

```bash
# 1. Clone the repository
git clone https://github.com/<your-username>/smart_car_controller.git
cd smart_car_controller
```

1. Open `firmware/smart_car_controller/smart_car_controller.ino` in Arduino IDE.
2. Select **Board:** `NodeMCU 1.0 (ESP-12E Module)`.
3. Select the correct **Port**.
4. Click **Upload** (⇧⌘U / Ctrl+U).
5. Open Serial Monitor at **115200 baud** — you should see:
   ```
   === NodeMCU Car Controller ===
   Motor test done.
   AP IP: 192.168.4.1
   WebSocket started on port 81
   Ready!
   ```

---

### 2. Build & Run the App

**Prerequisites:**
- [Flutter SDK ≥ 3.11](https://docs.flutter.dev/get-started/install)
- Android device or emulator (Android 5.0+)

```bash
cd flutter_app

# Install dependencies
flutter pub get

# Run on connected device
flutter run
```

To build a release APK:
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

---

### 3. Connect & Drive

1. Power on the car — the LED on NodeMCU will blink and then stay solid.
2. On your phone, go to **Wi-Fi settings** and connect to:
   - **SSID:** `NodeMCU-Car`
   - **Password:** `12345678`
3. Open the app and tap **Connect**.
4. Use the D-Pad to drive!

---

## 📡 Communication Protocol

All messages are plain-text WebSocket frames sent to `ws://192.168.4.1:81`.

### App → Car (Commands)

| Message | Action |
|---|---|
| `F` | Move forward |
| `B` | Move backward |
| `L` | Turn left |
| `R` | Turn right |
| `S` | Stop |
| `V<0-255>` | Set motor speed (e.g. `V200`) |

### Car → App (Telemetry)

Broadcast every **100 ms** as JSON:

```json
{
  "front": 25,
  "back": 42,
  "frontBlocked": false,
  "backBlocked": false,
  "speed": 180
}
```

| Field | Type | Description |
|---|---|---|
| `front` | `int` | Front sensor distance in cm (`-1` = no reading) |
| `back` | `int` | Rear sensor distance in cm (`-1` = no reading) |
| `frontBlocked` | `bool` | `true` if front obstacle < safe distance |
| `backBlocked` | `bool` | `true` if rear obstacle < safe distance |
| `speed` | `int` | Current PWM speed value (0–255) |

---

## ⚙️ Configuration

Both parameters can be changed in `smart_car_controller.ino` without touching any other file:

```cpp
// firmware/smart_car_controller/smart_car_controller.ino

const char* apSSID     = "NodeMCU-Car";  // Wi-Fi network name
const char* apPassword = "12345678";     // Wi-Fi password (min 8 chars)
const int   safeDistance = 10;           // Collision stop threshold (cm)
int         currentSpeed = 180;          // Default motor speed (0–255)
```

---

## 🗺 Project Roadmap

- [ ] OTA (over-the-air) firmware updates
- [ ] Camera streaming via MJPEG
- [ ] Joystick / gyroscope steering mode in the app
- [ ] Battery voltage monitoring and low-battery alert
- [ ] iOS support (Flutter app is already cross-platform; just needs signing)
- [ ] PID-based speed control for smoother movement

---

## 📄 License

This project is released under the [MIT License](LICENSE). You are free to use, modify, and distribute it for any purpose.

---

<div align="center">

Made with ❤️ — contributions and pull requests are always welcome!

</div>
