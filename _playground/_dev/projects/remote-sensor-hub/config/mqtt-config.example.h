#ifndef MQTT_CONFIG_H
#define MQTT_CONFIG_H

// MQTT Broker Configuration
#define MQTT_BROKER_HOST "192.168.1.100"  // Raspberry Pi IP address
#define MQTT_BROKER_PORT 1883              // MQTT port (1883 for non-SSL, 8883 for SSL)

// MQTT Authentication (optional)
#define MQTT_USERNAME "sensor-hub-user"    // MQTT username
#define MQTT_PASSWORD "your-mqtt-password" // MQTT password

// MQTT Client Configuration
#define MQTT_CLIENT_ID "kitchen-node"      // Unique client ID for this node
#define MQTT_KEEPALIVE 60                  // Keepalive interval (seconds)
#define MQTT_RECONNECT_DELAY 5000          // Delay before reconnecting (ms)

// MQTT Topic Prefix
#define MQTT_TOPIC_PREFIX "sensor-hub"     // Base topic prefix

// MQTT QoS Levels
#define MQTT_QOS_DATA 0                    // QoS for sensor data (frequent)
#define MQTT_QOS_STATUS 1                  // QoS for status messages
#define MQTT_QOS_COMMAND 1                 // QoS for commands

// MQTT Message Settings
#define MQTT_BUFFER_SIZE 512               // Maximum message size
#define MQTT_RETAIN_STATUS true            // Retain status messages
#define MQTT_RETAIN_DATA false             // Don't retain sensor data

// MQTT Topics
#define MQTT_TOPIC_STATUS MQTT_TOPIC_PREFIX "/" MQTT_CLIENT_ID "/system/status"
#define MQTT_TOPIC_ERROR MQTT_TOPIC_PREFIX "/" MQTT_CLIENT_ID "/system/error"
#define MQTT_TOPIC_INFO MQTT_TOPIC_PREFIX "/" MQTT_CLIENT_ID "/system/info"
#define MQTT_TOPIC_HEARTBEAT MQTT_TOPIC_PREFIX "/" MQTT_CLIENT_ID "/system/heartbeat"
#define MQTT_TOPIC_COMMAND MQTT_TOPIC_PREFIX "/" MQTT_CLIENT_ID "/command/+"

// MQTT SSL/TLS (optional, for secure connections)
// #define MQTT_USE_SSL true
// #define MQTT_CA_CERT "-----BEGIN CERTIFICATE-----\n..."

#endif // MQTT_CONFIG_H

