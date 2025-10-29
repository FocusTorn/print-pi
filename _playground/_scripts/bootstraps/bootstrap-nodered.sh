#!/usr/bin/env bash
# Bootstrap Node-RED installation via Docker
# Installs Node-RED as a separate container with HA integration

set -e

NODE_RED_DIR="/home/pi/nodered"
NODE_RED_CONTAINER="nodered"
DOWNLOAD_DIR="/home/pi/Downloads/curls"

echo "🔴 Bootstrapping Node-RED installation..."
echo ""

# Check if Node-RED container already exists
if docker ps -a --format '{{.Names}}' | grep -q "^${NODE_RED_CONTAINER}$"; then
    echo "⚠️  Node-RED container already exists"
    read -p "Remove and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "🗑️  Stopping and removing existing container..."
        docker stop "${NODE_RED_CONTAINER}" 2>/dev/null || true
        docker rm "${NODE_RED_CONTAINER}" 2>/dev/null || true
    else
        echo "❌ Installation cancelled"
        exit 0
    fi
fi

# Create Node-RED data directory
echo "📁 Creating Node-RED data directory..."
mkdir -p "$NODE_RED_DIR"

# Detect timezone
TIMEZONE=$(cat /etc/timezone 2>/dev/null || echo "UTC")
echo "🌍 Detected timezone: $TIMEZONE"

# Check if we need sudo for docker
DOCKER_CMD="docker"
if ! docker ps &> /dev/null; then
    echo "⚠️  Docker group not active, using sudo"
    DOCKER_CMD="sudo docker"
fi

# Pull Node-RED image
echo "📥 Pulling Node-RED Docker image..."
$DOCKER_CMD pull nodered/node-red:latest

# Run Node-RED container
echo "🚀 Starting Node-RED container..."
$DOCKER_CMD run -d \
  --name "${NODE_RED_CONTAINER}" \
  --restart=unless-stopped \
  -e TZ="$TIMEZONE" \
  -p 1880:1880 \
  -v "${NODE_RED_DIR}:/data" \
  --network=host \
  nodered/node-red:latest

# Wait for container to start
echo "⏱️  Waiting for Node-RED to initialize..."
sleep 5

# Verify container is running
if ! $DOCKER_CMD ps --format '{{.Names}}' | grep -q "^${NODE_RED_CONTAINER}$"; then
    echo "❌ Container failed to start. Check logs with:"
    echo "   docker logs ${NODE_RED_CONTAINER}"
    exit 1
fi

echo "✅ Container is running!"
echo ""

# Fix permissions
sudo chown -R 1000:1000 "$NODE_RED_DIR"

# Wait a bit more for Node-RED to fully initialize
echo "⏱️  Waiting for Node-RED to be ready (15 seconds)..."
sleep 15

echo ""
echo "✅ Node-RED installation complete!"
echo ""
echo "📊 Container Status:"
$DOCKER_CMD ps --filter "name=${NODE_RED_CONTAINER}" --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'
echo ""
echo "🌐 Access Node-RED at:"
echo "   • http://192.168.1.159:1880"
echo "   • http://MyP.local:1880"
echo ""
echo "📁 Data directory: ${NODE_RED_DIR}"
echo ""
echo "📋 Next Steps:"
echo "   1. Access Node-RED web interface"
echo "   2. Install Home Assistant palette:"
echo "      Menu → Manage palette → Install → Search 'node-red-contrib-home-assistant-websocket'"
echo "   3. Configure HA connection:"
echo "      Add 'server' node"
echo "      URL: http://192.168.1.159:8123"
echo "      Create Long-Lived Access Token in HA"
echo ""
echo "🔧 Useful commands:"
echo "   • docker logs -f ${NODE_RED_CONTAINER}      (view logs)"
echo "   • docker restart ${NODE_RED_CONTAINER}      (restart)"
echo "   • docker stop ${NODE_RED_CONTAINER}         (stop)"
echo "   • docker start ${NODE_RED_CONTAINER}        (start)"
echo ""
echo "📖 Documentation:"
echo "   • Node-RED: https://nodered.org/docs/"
echo "   • HA Integration: https://zachowj.github.io/node-red-contrib-home-assistant-websocket/"
echo ""

