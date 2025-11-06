from __future__ import annotations

from homeassistant.core import HomeAssistant
from homeassistant.helpers.typing import ConfigType

DOMAIN = "bme680_monitor"

async def async_setup(hass: HomeAssistant, config: ConfigType) -> bool:
    """Set up the BME680 Monitor platform."""
    # Import sensor platform to register it
    from . import sensor  # noqa: F401
    return True


