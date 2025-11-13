#!/usr/bin/env bash
# Bootstrap Grafana installation via Docker
# Installs Grafana as a separate container for metrics and visualization

set -e

GRAFANA_DIR="/home/pi/grafana"
GRAFANA_CONTAINER="grafana"
GRAFANA_PORT="3000"
DOWNLOAD_DIR="/home/pi/Downloads/curls"

echo "📊 Bootstrapping Grafana installation..."
echo ""

# Check if Grafana container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${GRAFANA_CONTAINER}$"; then
    echo "⚠️  Grafana container already exists"
    read -p "Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Stopping and removing existing container..."
        docker stop "${GRAFANA_CONTAINER}" 2>/dev/null || true
        docker rm "${GRAFANA_CONTAINER}" 2>/dev/null || true
    else
        echo "❌ Installation cancelled"
        exit 0
    fi
fi

# Create Grafana data directory structure
echo "📁 Creating Grafana data directories..."
mkdir -p "${GRAFANA_DIR}/data"
mkdir -p "${GRAFANA_DIR}/logs"
mkdir -p "${GRAFANA_DIR}/plugins"
mkdir -p "${GRAFANA_DIR}/provisioning/datasources"
mkdir -p "${GRAFANA_DIR}/provisioning/dashboards"

# Detect timezone
TIMEZONE=$(cat /etc/timezone 2>/dev/null || echo "UTC")
echo "🌍 Detected timezone: $TIMEZONE"

# Check if we need sudo for docker
DOCKER_CMD="docker"
if ! docker ps &> /dev/null; then
    echo "⚠️  Docker group not active, using sudo"
    DOCKER_CMD="sudo docker"
fi

# Pull Grafana image
echo "📥 Pulling Grafana Docker image..."
$DOCKER_CMD pull grafana/grafana:latest

# Run Grafana container
echo "🚀 Starting Grafana container..."
$DOCKER_CMD run -d \
  --name "${GRAFANA_CONTAINER}" \
  --restart=unless-stopped \
  -e TZ="$TIMEZONE" \
  -e "GF_SECURITY_ADMIN_USER=admin" \
  -e "GF_SECURITY_ADMIN_PASSWORD=admin" \
  -e "GF_INSTALL_PLUGINS=" \
  -p "${GRAFANA_PORT}:3000" \
  -v "${GRAFANA_DIR}/data:/var/lib/grafana" \
  -v "${GRAFANA_DIR}/logs:/var/log/grafana" \
  -v "${GRAFANA_DIR}/plugins:/var/lib/grafana/plugins" \
  -v "${GRAFANA_DIR}/provisioning:/etc/grafana/provisioning" \
  --network=host \
  grafana/grafana:latest

# Wait for container to start
echo "⏱️  Waiting for Grafana to initialize..."
sleep 5

# Verify container is running
if ! $DOCKER_CMD ps --format '{{.Names}}' | grep -q "^${GRAFANA_CONTAINER}$"; then
    echo "❌ Container failed to start. Check logs with:"
    echo "   docker logs ${GRAFANA_CONTAINER}"
    exit 1
fi

echo "✅ Container is running!"
echo ""

# Fix permissions (Grafana runs as user 472)
sudo chown -R 472:472 "${GRAFANA_DIR}/data"
sudo chown -R 472:472 "${GRAFANA_DIR}/logs"
sudo chmod -R 755 "${GRAFANA_DIR}"

# Wait a bit more for Grafana to fully initialize
echo "⏱️  Waiting for Grafana to be ready (15 seconds)..."
sleep 15

echo ""
echo "✅ Grafana installation complete!"
echo ""
echo "📊 Container Status:"
$DOCKER_CMD ps --filter "name=${GRAFANA_CONTAINER}" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""
echo "🌐 Access Grafana at:"
echo "   • http://192.168.1.159:${GRAFANA_PORT}"
echo "   • http://MyP.local:${GRAFANA_PORT}"
echo ""
echo "🔐 Default Credentials:"
echo "   Username: admin"
echo "   Password: admin"
echo "   ⚠️  CHANGE THESE CREDENTIALS ON FIRST LOGIN!"
echo ""
echo "📁 Data directories:"
echo "   • Data: ${GRAFANA_DIR}/data"
echo "   • Logs: ${GRAFANA_DIR}/logs"
echo "   • Plugins: ${GRAFANA_DIR}/plugins"
echo "   • Provisioning: ${GRAFANA_DIR}/provisioning"
echo ""
echo "📋 Next Steps:"
echo "   1. Access Grafana web interface"
echo "   2. Change default admin password"
echo "   3. Configure data sources (e.g., InfluxDB, Prometheus, Home Assistant)"
echo "   4. Create dashboards or import existing ones"
echo ""
echo "🔧 Useful commands:"
echo "   • docker logs -f ${GRAFANA_CONTAINER}      (view logs)"
echo "   • docker restart ${GRAFANA_CONTAINER}      (restart)"
echo "   • docker stop ${GRAFANA_CONTAINER}         (stop)"
echo "   • docker start ${GRAFANA_CONTAINER}        (start)"
echo ""
echo "📖 Documentation:"
echo "   • Grafana: https://grafana.com/docs/grafana/latest/"
echo "   • Home Assistant Integration: https://www.home-assistant.io/integrations/grafana/"
echo ""

