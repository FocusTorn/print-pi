/*
  Blink ESP32-S3
  Turns the built-in LED on and off repeatedly.
  
  Most ESP32-S3 boards have a built-in LED on GPIO 48 (or GPIO 38).
  If your board doesn't have a built-in LED, connect an external LED
  to GPIO 48 with a 220Ω resistor.
*/

void setup() {
  // Initialize serial communication
  Serial.begin(115200);
  delay(1000);
  
  // Initialize the LED pin
  pinMode(LED_BUILTIN, OUTPUT);
  
  Serial.println("ESP32-S3 Blink Example Started!");
}

void loop() {
  // Turn LED on
  digitalWrite(LED_BUILTIN, HIGH);
  Serial.println("LED ON");
  delay(1000);
  
  // Turn LED off
  digitalWrite(LED_BUILTIN, LOW);
  Serial.println("LED OFF");
  delay(1000);
}
