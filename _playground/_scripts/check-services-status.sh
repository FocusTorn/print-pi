#!/usr/bin/env bash
# Quick service status checker
# Shows running and stopped Docker containers and systemd services

echo "=== Docker Containers ==="
echo ""
echo "--- Running Containers ---"
RUNNING=$(docker ps --format "{{.Names}}" 2>/dev/null)
if [ -z "$RUNNING" ]; then
    echo "  No running containers"
else
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null
fi

echo ""
echo "--- Stopped/Exited Containers ---"
STOPPED=$(docker ps -a --filter "status=exited" --format "{{.Names}}" 2>/dev/null)
if [ -z "$STOPPED" ]; then
    echo "  No stopped containers"
else
    docker ps -a --filter "status=exited" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null
fi

CREATED=$(docker ps -a --filter "status=created" --format "{{.Names}}" 2>/dev/null)
if [ -n "$CREATED" ]; then
    echo ""
    echo "--- Created (Not Started) Containers ---"
    docker ps -a --filter "status=created" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null
fi

FAILED=$(docker ps -a --filter "status=dead" --format "{{.Names}}" 2>/dev/null)
if [ -n "$FAILED" ]; then
    echo ""
    echo "--- Failed/Dead Containers ---"
    docker ps -a --filter "status=dead" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null
fi

RESTARTING=$(docker ps -a --filter "status=restarting" --format "{{.Names}}" 2>/dev/null)
if [ -n "$RESTARTING" ]; then
    echo ""
    echo "--- Restarting Containers ---"
    docker ps -a --filter "status=restarting" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null
fi

# Check for any containers that are not running
NOT_RUNNING=$(docker ps -a --format "{{.Names}}\t{{.Status}}" 2>/dev/null | grep -v "Up " | awk '{print $1}' | grep -v "^$" || true)
if [ -n "$NOT_RUNNING" ] && [ -z "$STOPPED" ] && [ -z "$CREATED" ] && [ -z "$FAILED" ] && [ -z "$RESTARTING" ]; then
    echo ""
    echo "--- Other Non-Running Containers ---"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Image}}" 2>/dev/null | grep -v "Up "
fi

echo ""
echo "=== Systemd Services (MQTT & BME680) ==="
echo ""
echo "--- Active Services ---"
ACTIVE_SERVICES=$(systemctl list-units --type=service --state=active --no-pager 2>/dev/null | grep -E "mqtt|mosquitto|bme680" || true)
if [ -z "$ACTIVE_SERVICES" ]; then
    echo "  No active services found"
else
    systemctl list-units --type=service --state=active --no-pager 2>/dev/null | grep -E "mqtt|mosquitto|bme680" | awk '{printf "  %-40s %s\n", $1, $3}'
fi

echo ""
echo "--- Inactive/Failed Services ---"
INACTIVE_SERVICES=$(systemctl list-units --type=service --all --no-pager 2>/dev/null | grep -E "mqtt|mosquitto|bme680" | grep -vE "active|running" || true)
if [ -z "$INACTIVE_SERVICES" ]; then
    echo "  No inactive services found"
else
    systemctl list-units --type=service --all --no-pager 2>/dev/null | grep -E "mqtt|mosquitto|bme680" | grep -vE "active|running" | awk '{printf "  %-40s %s %s\n", $1, $3, $4}'
fi

echo ""
echo "=== Service Status Summary ==="
echo ""
echo "Docker Containers:"
for container in homeassistant nodered grafana; do
    STATUS=$(docker inspect "$container" --format '{{.State.Status}}' 2>/dev/null || echo "not found")
    if [ "$STATUS" = "running" ]; then
        echo "  ✅ $container: $STATUS"
    else
        echo "  ❌ $container: $STATUS"
    fi
done

echo ""
echo "Systemd Services:"
for service in mosquitto.service bme680-base-mqtt.service bme680-heatsoak-mqtt.service bme680-iaq-mqtt.service; do
    if systemctl list-unit-files "$service" >/dev/null 2>&1; then
        STATUS=$(systemctl is-active "$service" 2>/dev/null || echo "inactive")
        if [ "$STATUS" = "active" ]; then
            echo "  ✅ $service: $STATUS"
        else
            echo "  ❌ $service: $STATUS"
        fi
    fi
done

