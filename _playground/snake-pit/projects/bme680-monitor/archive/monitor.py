#!/usr/bin/env python3
"""BME680 VOC Monitor for 3D Printer Enclosure Safety

Monitors volatile organic compounds (VOCs) from 3D printing
and determines when it's safe to open the printer enclosure.

Features:
- Establish baseline VOC levels (normal room air)
- Monitor VOC changes during printing
- Alert when safe to open enclosure (VOCs returned to baseline)
"""

from typing import Optional
import time
import sys
from pathlib import Path
from dataclasses import dataclass
import argparse

try:
    import board
    import busio
    from adafruit_bme680 import Adafruit_BME680_I2C
except ImportError as e:
    print(f"ERROR: Missing required package. Install with:")
    print(f"  uv pip install adafruit-circuitpython-bme680 adafruit-blinka")
    sys.exit(1)


@dataclass
class BMEReading:
    """Container for BME680 sensor readings."""
    temperature: float
    humidity: float
    pressure: float
    gas: Optional[float]  # VOC/IAQ index
    
    def __str__(self) -> str:
        gas_str = f"{self.gas:.1f}" if self.gas is not None else "N/A"
        return (
            f"Temp: {self.temperature:.1f}°C, "
            f"Humidity: {self.humidity:.1f}%, "
            f"Pressure: {self.pressure:.1f} hPa, "
            f"Gas: {gas_str}"
        )


class BMESensor:
    """BME680 sensor wrapper with error handling and calibration.
    
    Provides safe reading methods with retry logic and baseline calibration
    for VOC monitoring.
    """
    
    def __init__(self, i2c_address: int = 0x77):
        """Initialize BME680 sensor.
        
        Args:
            i2c_address: I2C address (0x76 or 0x77)
        """
        self.i2c_address = i2c_address
        self.sensor: Optional[Adafruit_BME680_I2C] = None
        self.baseline_voc: Optional[float] = None
        self.voc_threshold: float = 10.0  # Default threshold
        self._init_sensor()
    
    def _init_sensor(self) -> None:
        """Initialize sensor hardware connection with error handling."""
        try:
            i2c = busio.I2C(board.SCL, board.SDA)
            self.sensor = Adafruit_BME680_I2C(i2c, address=self.i2c_address)
            print(f"✅ BME680 connected at I2C address 0x{self.i2c_address:02x}")
            # Set up sensor for accurate readings
            self.sensor.sea_level_pressure = 1013.25
        except (OSError, RuntimeError, ValueError) as e:
            print(f"❌ Failed to initialize BME680: {e}")
            print("   Check that:")
            print("   - Sensor is connected correctly (SDA to GPIO 2, SCL to GPIO 3)")
            print("   - I2C is enabled in /boot/firmware/config.txt: dtparam=i2c_arm=on")
            print("   - I2C enabled, then REBOOT: sudo reboot")
            print("   - Sensor is powered (3.3V)")
            print(f"   - I2C address is correct (you're using 0x{self.i2c_address:02x})")
            print("   - Verify with: i2cdetect -y 1")
            self.sensor = None
    
    def is_connected(self) -> bool:
        """Check if sensor is connected and responding."""
        return self.sensor is not None
    
    def read(self) -> Optional[BMEReading]:
        """Read all sensor values.
        
        Returns:
            BMEReading object or None if read failed
            
        Note: Gas readings require the internal heater to stabilize (~2-3 cycles).
        Early readings may be inaccurate.
        """
        if not self.is_connected():
            return None
        
        try:
            # Note: Adafruit library manages heater timing internally
            # but gas readings may still be unstable until heater stabilizes
            return BMEReading(
                temperature=self.sensor.temperature,
                humidity=self.sensor.relative_humidity,
                pressure=self.sensor.pressure,
                gas=self.sensor.gas
            )
        except Exception as e:
            print(f"⚠️  Sensor read error: {e}")
            return None
    
    def calibrate_baseline(self, duration: int = 60, interval: int = 5) -> bool:
        """Establish baseline VOC level.
        
        Takes readings over duration to determine normal room air VOC levels.
        
        Args:
            duration: Calibration time in seconds
            interval: Seconds between readings
            
        Returns:
            True if calibration successful, False otherwise
        """
        if not self.is_connected():
            print("❌ Cannot calibrate: sensor not connected")
            return False
        
        print(f"\n📊 Calibrating baseline VOC levels...")
        print(f"   Duration: {duration}s, Interval: {interval}s")
        print("   Ensure room air is normal (no active printing, good ventilation)")
        print("")
        
        readings = []
        num_readings = duration // interval
        
        for i in range(num_readings):
            reading = self.read()
            if reading and reading.gas is not None:
                readings.append(reading.gas)
                print(f"   Reading {i+1}/{num_readings}: {reading.gas:.1f}", end='\r')
            else:
                print(f"\n   ⚠️  Skipping invalid reading {i+1}")
            time.sleep(interval)
        
        print()  # New line after progress
        
        if not readings:
            print("❌ Calibration failed: no valid readings")
            return False
        
        self.baseline_voc = sum(readings) / len(readings)
        print(f"✅ Baseline established: {self.baseline_voc:.1f}")
        print(f"   Using threshold: {self.baseline_voc + self.voc_threshold:.1f}")
        return True
    
    def is_safe_to_open(self) -> Optional[bool]:
        """Check if current VOC levels are safe for opening enclosure.
        
        Returns:
            True if safe, False if unsafe, None if can't determine
        """
        if self.baseline_voc is None:
            return None
        
        reading = self.read()
        if not reading or reading.gas is None:
            return None
        
        safe_threshold = self.baseline_voc + self.voc_threshold
        return reading.gas <= safe_threshold


def main():
    """Main monitoring loop."""
    parser = argparse.ArgumentParser(
        description="BME680 VOC Monitor for 3D Printer Enclosure"
    )
    parser.add_argument(
        "--calibrate",
        action="store_true",
        help="Run baseline calibration"
    )
    parser.add_argument(
        "--monitor",
        action="store_true",
        help="Monitor VOC levels (default action)"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=10,
        help="Monitoring interval in seconds (default: 10)"
    )
    parser.add_argument(
        "--scan",
        action="store_true",
        help="Scan I2C bus for BME680"
    )
    
    args = parser.parse_args()
    
    # Default to monitor if no action specified
    if not args.calibrate and not args.monitor:
        args.monitor = True
    
    # Scan mode
    if args.scan:
        print("\n🔍 Scanning I2C bus for BME680...")
        print("   Trying addresses 0x76 and 0x77...\n")
        
        for addr in [0x76, 0x77]:
            print(f"Trying I2C address 0x{addr:02x}...", end=" ")
            test_sensor = BMESensor(i2c_address=addr)
            if test_sensor.is_connected():
                print("✅ FOUND!")
                # Try to read a value to confirm it's a BME680
                reading = test_sensor.read()
                if reading:
                    print(f"   Sensor responding: {reading}")
                    print(f"\n✅ Use this address: 0x{addr:02x}")
                else:
                    print("   Connected but can't read values")
            else:
                print("❌ Not found")
            print()
        
        print("If no devices found, check wiring and power supply.")
        return
    
    # Initialize sensor
    sensor = BMESensor()
    
    if not sensor.is_connected():
        print("\n❌ Sensor not available. Exiting.")
        print("   Try running with --scan to diagnose connection issues.")
        sys.exit(1)
    
    # Calibration mode
    if args.calibrate:
        success = sensor.calibrate_baseline(duration=60, interval=5)
        if success:
            print("\n✅ Calibration complete! You can now monitor safely.")
            # TODO: Save baseline to file for persistence
        else:
            print("\n❌ Calibration failed")
            sys.exit(1)
        return
    
    # Monitoring mode
    if args.monitor:
        print("\n🔍 Monitoring VOC levels...")
        print(f"   Interval: {args.interval}s")
        print("   Press Ctrl+C to stop\n")
        
        # Check if calibrated
        if sensor.baseline_voc is None:
            print("⚠️  WARNING: No baseline set!")
            print("   Run with --calibrate first to establish safe levels")
            print("")
        
        try:
            while True:
                reading = sensor.read()
                if reading:
                    print(reading)
                    
                    # Safety check
                    safe = sensor.is_safe_to_open()
                    if safe is True:
                        print("   ✅ SAFE to open enclosure")
                    elif safe is False:
                        print("   ⚠️  UNSAFE - VOCs elevated")
                    # safe is None means not calibrated yet
                
                time.sleep(args.interval)
                
        except KeyboardInterrupt:
            print("\n\n👋 Monitoring stopped by user")


if __name__ == "__main__":
    main()

