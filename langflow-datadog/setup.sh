#!/bin/bash
set -euo pipefail

echo "============================================"
echo " Langflow + Datadog Setup Script"
echo " Target: macOS (Intel iMac 2017)"
echo "============================================"
echo ""

# -----------------------------------------------------------
# PHASE 1: Check / Install Docker
# -----------------------------------------------------------
echo "--- Phase 1: Docker ---"

if command -v docker &> /dev/null; then
    echo "[OK] Docker is already installed: $(docker --version)"
else
    echo "[!] Docker is NOT installed."
    echo "    Download Docker Desktop for Mac (Intel) from:"
    echo "    https://docs.docker.com/desktop/setup/install/mac-install/"
    echo ""
    echo "    1. Click 'Docker Desktop for Mac with Intel chip'"
    echo "    2. Open the .dmg and drag Docker to Applications"
    echo "    3. Launch Docker Desktop from Applications"
    echo "    4. Wait for the whale icon to appear in the menu bar"
    echo "    5. Re-run this script after Docker is installed."
    exit 1
fi

# Check Docker daemon is running
if ! docker info &> /dev/null; then
    echo "[!] Docker daemon is not running."
    echo "    Please start Docker Desktop and wait for it to be ready."
    echo "    Then re-run this script."
    exit 1
fi

echo "[OK] Docker daemon is running."
echo "[OK] Docker Compose: $(docker compose version)"
echo ""

# -----------------------------------------------------------
# PHASE 2: Create project directory and start Langflow
# -----------------------------------------------------------
echo "--- Phase 2: Start Langflow ---"

PROJ_DIR="$HOME/langflow-datadog"
mkdir -p "$PROJ_DIR"

# Copy docker-compose.yml if not already in place
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    cp "$SCRIPT_DIR/docker-compose.yml" "$PROJ_DIR/docker-compose.yml"
    echo "[OK] docker-compose.yml copied to $PROJ_DIR"
fi

cd "$PROJ_DIR"

echo "[..] Pulling Langflow image (this may take a few minutes)..."
docker compose pull

echo "[..] Starting Langflow..."
docker compose up -d

echo "[..] Waiting for Langflow to be ready..."
MAX_WAIT=120
ELAPSED=0
until curl -s -o /dev/null -w "%{http_code}" http://localhost:7860 | grep -q "200\|302"; do
    if [ $ELAPSED -ge $MAX_WAIT ]; then
        echo "[!] Langflow did not become ready within ${MAX_WAIT}s."
        echo "    Check logs: docker compose logs -f langflow"
        exit 1
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    echo "    ...waiting (${ELAPSED}s / ${MAX_WAIT}s)"
done

echo "[OK] Langflow is running at http://localhost:7860"
echo ""

# -----------------------------------------------------------
# PHASE 3 & 4: Reminder for API keys
# -----------------------------------------------------------
echo "============================================"
echo " MANUAL STEPS REQUIRED"
echo "============================================"
echo ""
echo "Phase 3: Configure Anthropic API Key"
echo "  1. Open http://localhost:7860 in your browser"
echo "  2. Go to Settings (gear icon) > Global Variables"
echo "  3. Add variable:"
echo "     Name:  ANTHROPIC_API_KEY"
echo "     Type:  Credential"
echo "     Value: <your Anthropic API key>"
echo ""
echo "Phase 4: Configure Datadog Credentials"
echo "  1. In Settings > Global Variables, add:"
echo "     Name:  DD_API_KEY"
echo "     Type:  Credential"
echo "     Value: <your Datadog API key>"
echo ""
echo "  2. Add another variable:"
echo "     Name:  DD_APP_KEY"
echo "     Type:  Credential"
echo "     Value: <your Datadog Application key>"
echo "     (Generate at: Datadog > Organization Settings > Application Keys)"
echo ""
echo "Phase 5: Build the Datadog Query Flow"
echo "  See the flow JSON file: datadog-query-flow.json"
echo "  You can import it in Langflow: My Collection > Import"
echo ""
echo "============================================"
echo " Setup complete! Open http://localhost:7860"
echo "============================================"
