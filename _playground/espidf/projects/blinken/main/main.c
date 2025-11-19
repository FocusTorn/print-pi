#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_log.h"

static const char *TAG = "BLINKEN";

void app_main(void)
{
    ESP_LOGI(TAG, "Hello from ESP-IDF!");
    
    int count = 0;
    while (1) {
        ESP_LOGI(TAG, "Count: %d", count++);
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}
