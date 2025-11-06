from __future__ import annotations

import time
from dataclasses import dataclass
from typing import Any

from datetime import timedelta
import voluptuous as vol
from homeassistant.components.sensor import SensorEntity, PLATFORM_SCHEMA
from homeassistant.const import PERCENTAGE, UnitOfPressure, UnitOfTemperature
from homeassistant.helpers.update_coordinator import DataUpdateCoordinator, UpdateFailed
from homeassistant.core import HomeAssistant

DEFAULT_BUS = 1
DEFAULT_ADDR = 0x77
DEFAULT_INTERVAL = 5

PLATFORM_SCHEMA = PLATFORM_SCHEMA.extend({
    vol.Optional("bus", default=DEFAULT_BUS): vol.Coerce(int),
    vol.Optional("address", default=DEFAULT_ADDR): vol.Coerce(int),
    vol.Optional("scan_interval", default=DEFAULT_INTERVAL): vol.Coerce(int),
})


def _open_sensor(bus: int, addr: int):
    # Use vendored monitor driver
    from .monitor import BME680
    sensor = BME680(addr)
    sensor.set_gas_heater_temperature(320)
    sensor.set_gas_heater_duration(150)
    sensor.select_gas_heater_profile(0)
    return sensor


class BME680Coordinator(DataUpdateCoordinator):
    def __init__(self, hass: HomeAssistant, bus: int, addr: int, interval: int) -> None:
        super().__init__(hass, name="bme680_monitor", update_interval=timedelta(seconds=interval))
        self._bus = bus
        self._addr = addr
        self._sensor = None

    async def _async_update_data(self) -> dict[str, Any]:
        try:
            if self._sensor is None:
                self._sensor = await self.hass.async_add_executor_job(_open_sensor, self._bus, self._addr)
            got = await self.hass.async_add_executor_job(self._sensor.get_sensor_data)
            data = {}
            if got:
                d = self._sensor.data
                data = {
                    "temperature": d.temperature,
                    "humidity": d.humidity,
                    "pressure": d.pressure,
                    "gas": d.gas_resistance,
                    "heat_stable": bool(getattr(d, "heat_stable", False)),
                }
            return data
        except Exception as err:  # noqa: BLE001
            raise UpdateFailed(str(err))


async def async_setup_platform(hass: HomeAssistant, config, async_add_entities, discovery_info=None):
    bus = config.get("bus", DEFAULT_BUS)
    addr = config.get("address", DEFAULT_ADDR)
    interval = config.get("scan_interval", DEFAULT_INTERVAL)

    coordinator = BME680Coordinator(hass, bus, addr, interval)
    await coordinator.async_config_entry_first_refresh()

    entities: list[SensorEntity] = [
        TemperatureEntity(coordinator),
        HumidityEntity(coordinator),
        PressureEntity(coordinator),
        GasEntity(coordinator),
    ]
    async_add_entities(entities)


class BaseBMEEntity(SensorEntity):
    _attr_has_entity_name = True
    def __init__(self, coordinator: BME680Coordinator) -> None:
        self.coordinator = coordinator
        self._attr_available = True

    @property
    def available(self) -> bool:
        """Return if entity is available."""
        return self.coordinator.last_update_success

    async def async_added_to_hass(self) -> None:
        """When entity is added to hass."""
        await super().async_added_to_hass()
        self.async_on_remove(
            self.coordinator.async_add_listener(self._handle_coordinator_update)
        )

    def _handle_coordinator_update(self) -> None:
        """Handle updated data from the coordinator."""
        self.async_write_ha_state()

    @property
    def device_info(self):
        return {
            "identifiers": {("bme680_monitor", "bme680")},
            "name": "BME680 Monitor",
            "manufacturer": "Bosch",
            "model": "BME680",
        }


class TemperatureEntity(BaseBMEEntity):
    _attr_name = "BME680 Temperature"
    _attr_native_unit_of_measurement = UnitOfTemperature.CELSIUS

    @property
    def native_value(self):
        return self.coordinator.data.get("temperature")


class HumidityEntity(BaseBMEEntity):
    _attr_name = "BME680 Humidity"
    _attr_native_unit_of_measurement = PERCENTAGE

    @property
    def native_value(self):
        return self.coordinator.data.get("humidity")


class PressureEntity(BaseBMEEntity):
    _attr_name = "BME680 Pressure"
    _attr_native_unit_of_measurement = UnitOfPressure.HPA

    @property
    def native_value(self):
        return self.coordinator.data.get("pressure")


class GasEntity(BaseBMEEntity):
    _attr_name = "BME680 Gas Resistance"

    @property
    def native_value(self):
        return self.coordinator.data.get("gas")


