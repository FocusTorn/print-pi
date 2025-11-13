#ifndef WIFI_CONFIG_H
#define WIFI_CONFIG_H

// WiFi Credentials
#define WIFI_SSID "your-wifi-ssid"
#define WIFI_PASSWORD "your-wifi-password"

// WiFi Connection Settings
#define WIFI_RETRY_DELAY 500    // Delay between connection attempts (ms)
#define WIFI_MAX_RETRIES 10     // Maximum number of connection attempts
#define WIFI_TIMEOUT 30000      // WiFi connection timeout (ms)

// WiFi Power Settings (ESP32 only)
// Options: WIFI_POWER_19_5dBm, WIFI_POWER_19dBm, WIFI_POWER_18_5dBm,
//          WIFI_POWER_17dBm, WIFI_POWER_15dBm, WIFI_POWER_13dBm,
//          WIFI_POWER_11dBm, WIFI_POWER_8_5dBm, WIFI_POWER_7dBm,
//          WIFI_POWER_5dBm, WIFI_POWER_2dBm, WIFI_POWER_MINUS_1dBm
#define WIFI_TX_POWER WIFI_POWER_19_5dBm

#endif // WIFI_CONFIG_H

