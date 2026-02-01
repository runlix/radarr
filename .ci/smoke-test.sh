#!/usr/bin/env bash
set -e
set -o pipefail

# Smoke test for Radarr Docker image
# This script receives IMAGE_TAG from the workflow environment

IMAGE="${IMAGE_TAG}"
PLATFORM="${PLATFORM:-linux/amd64}"
CONTAINER_NAME="radarr-smoke-test-${RANDOM}"
RADARR_PORT="7878"

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 Radarr Smoke Test${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo "Image: ${IMAGE}"
echo "Platform: ${PLATFORM}"
echo ""

# Validate IMAGE_TAG is set
if [ -z "${IMAGE}" ] || [ "${IMAGE}" = "null" ]; then
  echo -e "${RED}❌ ERROR: IMAGE_TAG environment variable is not set${NC}"
  exit 1
fi

# Create temporary config directory
CONFIG_DIR=$(mktemp -d)
chmod 777 "${CONFIG_DIR}"
echo "Config directory: ${CONFIG_DIR}"
echo ""

# Cleanup function
cleanup() {
  echo ""
  echo -e "${YELLOW}🧹 Cleaning up...${NC}"

  # Capture final logs before stopping
  if docker ps -a | grep -q "${CONTAINER_NAME}"; then
    echo "Saving container logs..."
    docker logs "${CONTAINER_NAME}" > /tmp/radarr-smoke-test.log 2>&1 || true
    echo "Logs saved to: /tmp/radarr-smoke-test.log"
  fi

  docker stop "${CONTAINER_NAME}" 2>/dev/null || true
  docker rm "${CONTAINER_NAME}" 2>/dev/null || true

  # Clean up config directory (files may be owned by container user)
  if [ -d "${CONFIG_DIR}" ]; then
    chmod -R 777 "${CONFIG_DIR}" 2>/dev/null || true
    rm -rf "${CONFIG_DIR}" 2>/dev/null || true
  fi

  echo -e "${YELLOW}Cleanup complete${NC}"
}
trap cleanup EXIT

# Start container (use local image, don't pull from registry)
echo -e "${BLUE}▶️  Starting container...${NC}"
if ! docker run \
  --pull=never \
  --platform="${PLATFORM}" \
  --name "${CONTAINER_NAME}" \
  -v "${CONFIG_DIR}:/config" \
  -p "${RADARR_PORT}:7878" \
  -e PUID=1000 \
  -e PGID=1000 \
  -e TZ=UTC \
  -d \
  "${IMAGE}"; then
  echo -e "${RED}❌ Failed to start container${NC}"
  exit 1
fi

echo -e "${GREEN}✅ Container started${NC}"
echo ""

# Wait for initialization
echo -e "${BLUE}⏳ Waiting for Radarr to initialize...${NC}"
echo "Waiting 15 seconds for startup..."
sleep 15

# Check if container is still running
echo ""
echo -e "${BLUE}🔍 Checking container status...${NC}"
if ! docker ps | grep -q "${CONTAINER_NAME}"; then
  echo -e "${RED}❌ Container exited unexpectedly${NC}"
  echo ""
  echo "Container logs:"
  docker logs "${CONTAINER_NAME}" 2>&1
  exit 1
fi
echo -e "${GREEN}✅ Container is running${NC}"
echo ""

# Check logs for critical errors
echo -e "${BLUE}📋 Analyzing container logs...${NC}"
LOGS=$(docker logs "${CONTAINER_NAME}" 2>&1)

# Check for fatal errors
FATAL_COUNT=$(echo "$LOGS" | grep -ciE "fatal|panic" || true)
if [ "${FATAL_COUNT}" -gt 0 ]; then
  echo -e "${RED}❌ Found ${FATAL_COUNT} critical error(s) in logs:${NC}"
  echo "$LOGS" | grep -iE "fatal|panic" | head -10
  exit 1
fi

# Check for expected startup messages (suppress broken pipe errors)
if echo "$LOGS" | grep -qi "starting radarr" 2>/dev/null; then
  echo -e "${GREEN}✅ Radarr startup message found${NC}"
else
  echo -e "${YELLOW}⚠️  Warning: Expected startup message not found${NC}"
fi

# Check for database initialization (suppress broken pipe errors)
if echo "$LOGS" | grep -qi "database" 2>/dev/null; then
  echo -e "${GREEN}✅ Database initialization detected${NC}"
else
  echo -e "${YELLOW}⚠️  Warning: No database messages found${NC}"
fi

echo -e "${GREEN}✅ No critical errors in logs${NC}"
echo ""

# Test health endpoint with retries
echo -e "${BLUE}🏥 Testing health endpoint...${NC}"
HEALTH_URL="http://localhost:${RADARR_PORT}/health"
MAX_ATTEMPTS=24
ATTEMPT=0
HEALTH_OK=false

while [ $ATTEMPT -lt $MAX_ATTEMPTS ]; do
  ATTEMPT=$((ATTEMPT + 1))

  if curl -fsSL --max-time 5 "${HEALTH_URL}" -o /dev/null 2>/dev/null; then
    HEALTH_OK=true
    break
  fi

  echo "Attempt ${ATTEMPT}/${MAX_ATTEMPTS}: Waiting for health endpoint..."
  sleep 5
done

if [ "${HEALTH_OK}" = true ]; then
  echo -e "${GREEN}✅ Health endpoint responding (${HEALTH_URL})${NC}"
else
  echo -e "${RED}❌ Health endpoint check failed after ${MAX_ATTEMPTS} attempts${NC}"
  echo ""
  echo "Recent container logs:"
  docker logs "${CONTAINER_NAME}" 2>&1 | tail -30
  exit 1
fi
echo ""

# Test ping endpoint
echo -e "${BLUE}📡 Testing API ping endpoint...${NC}"
PING_URL="http://localhost:${RADARR_PORT}/ping"
if curl -fsSL --max-time 5 "${PING_URL}" -o /dev/null 2>/dev/null; then
  echo -e "${GREEN}✅ API ping successful (${PING_URL})${NC}"
else
  echo -e "${YELLOW}⚠️  API ping failed (non-critical)${NC}"
fi
echo ""

# Test root endpoint
echo -e "${BLUE}🌐 Testing root web endpoint...${NC}"
ROOT_URL="http://localhost:${RADARR_PORT}/"
if curl -fsSL --max-time 5 "${ROOT_URL}" -o /dev/null 2>/dev/null; then
  echo -e "${GREEN}✅ Web UI accessible (${ROOT_URL})${NC}"
else
  echo -e "${YELLOW}⚠️  Web UI check failed (non-critical)${NC}"
fi
echo ""

# Verify image is using correct architecture
echo -e "${BLUE}🏗️  Verifying architecture...${NC}"
IMAGE_ARCH=$(docker image inspect "${IMAGE}" | jq -r '.[0].Architecture')
EXPECTED_ARCH=$(echo "${PLATFORM}" | cut -d'/' -f2)

if [ "${IMAGE_ARCH}" = "${EXPECTED_ARCH}" ] || [ "${IMAGE_ARCH}" = "null" ]; then
  if [ "${IMAGE_ARCH}" = "null" ]; then
    echo -e "${YELLOW}⚠️  Cannot verify architecture (not set in image metadata)${NC}"
  else
    echo -e "${GREEN}✅ Architecture matches: ${IMAGE_ARCH}${NC}"
  fi
else
  echo -e "${RED}❌ Architecture mismatch: expected ${EXPECTED_ARCH}, got ${IMAGE_ARCH}${NC}"
  exit 1
fi
echo ""

# Check process is running inside container
echo -e "${BLUE}⚙️  Checking Radarr process...${NC}"
if docker exec "${CONTAINER_NAME}" pgrep -f Radarr >/dev/null 2>&1; then
  echo -e "${GREEN}✅ Radarr process is running${NC}"
else
  echo -e "${RED}❌ Radarr process not found${NC}"
  docker exec "${CONTAINER_NAME}" ps aux || true
  exit 1
fi
echo ""

# Summary
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅✅✅ Smoke Test PASSED ✅✅✅${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "Test Summary:"
echo "  • Container started successfully"
echo "  • No critical errors in logs"
echo "  • Health endpoint responding"
echo "  • Correct architecture: ${CONTAINER_ARCH}"
echo "  • Radarr process running"
echo ""

exit 0
