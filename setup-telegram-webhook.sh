#!/bin/bash

# Setup script for Telegram webhook with Cloudflare tunnel
# This script helps automate the process of:
# 1. Starting Cloudflare tunnel
# 2. Getting the webhook path from the database
# 3. Setting the Telegram webhook URL

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Telegram Webhook Setup Script${NC}"
echo ""

# Check if Docker services are running
if ! docker compose -f docker-compose.local.yml ps | grep -q "Up"; then
    echo -e "${RED}❌ Docker services are not running. Please start them first:${NC}"
    echo "   docker compose -f docker-compose.local.yml up -d"
    exit 1
fi

echo -e "${GREEN}✅ Docker services are running${NC}"
echo ""

# Step 1: Start Cloudflare tunnel (in background)
echo -e "${YELLOW}📡 Step 1: Starting Cloudflare tunnel...${NC}"
echo "   Run this command in a separate terminal:"
echo "   cloudflared tunnel --url http://localhost:3000"
echo ""
read -p "Press Enter once you've started the tunnel and have the URL..."
echo ""

# Get the tunnel URL
read -p "Enter the Cloudflare tunnel URL (e.g., https://xxx.trycloudflare.com): " TUNNEL_URL
if [ -z "$TUNNEL_URL" ]; then
    echo -e "${RED}❌ Tunnel URL is required${NC}"
    exit 1
fi

# Step 2: Get webhook path from database
echo ""
echo -e "${YELLOW}🔍 Step 2: Finding webhook path...${NC}"
WEBHOOK_PATH=$(docker compose -f docker-compose.local.yml exec -T db psql -U postgres -d simstudio -t -c "SELECT path FROM webhook WHERE provider = 'telegram' AND is_active = true LIMIT 1;" 2>/dev/null | tr -d '[:space:]')

if [ -z "$WEBHOOK_PATH" ]; then
    echo -e "${RED}❌ No active Telegram webhook found in database${NC}"
    echo "   Please create a Telegram webhook trigger in your workflow first"
    exit 1
fi

echo -e "${GREEN}✅ Found webhook path: ${WEBHOOK_PATH}${NC}"
echo ""

# Step 3: Get bot token (from webhook config or prompt)
echo -e "${YELLOW}🔑 Step 3: Getting bot token...${NC}"
BOT_TOKEN=$(docker compose -f docker-compose.local.yml exec -T db psql -U postgres -d simstudio -t -c "SELECT provider_config->>'botToken' FROM webhook WHERE path = '$WEBHOOK_PATH' LIMIT 1;" 2>/dev/null | tr -d '[:space:]' | tr -d '"')

if [ -z "$BOT_TOKEN" ]; then
    read -p "Enter your Telegram bot token: " BOT_TOKEN
    if [ -z "$BOT_TOKEN" ]; then
        echo -e "${RED}❌ Bot token is required${NC}"
        exit 1
    fi
else
    echo -e "${GREEN}✅ Found bot token in database${NC}"
fi
echo ""

# Step 4: Set Telegram webhook
echo -e "${YELLOW}📤 Step 4: Setting Telegram webhook...${NC}"
WEBHOOK_URL="${TUNNEL_URL}/api/webhooks/trigger/${WEBHOOK_PATH}"

echo "   Webhook URL: ${WEBHOOK_URL}"
echo ""

RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/setWebhook" \
  -H "Content-Type: application/json" \
  -d "{\"url\":\"${WEBHOOK_URL}\"}")

if echo "$RESPONSE" | grep -q '"ok":true'; then
    echo -e "${GREEN}✅ Webhook set successfully!${NC}"
    echo ""
    
    # Verify webhook
    echo -e "${YELLOW}🔍 Verifying webhook...${NC}"
    curl -s "https://api.telegram.org/bot${BOT_TOKEN}/getWebhookInfo" | jq '.result | {url, pending_update_count, last_error_message}'
else
    echo -e "${RED}❌ Failed to set webhook:${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

echo ""
echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Make sure Cloudflare tunnel stays running"
echo "2. Update NEXT_PUBLIC_APP_URL in docker-compose.local.yml to: ${TUNNEL_URL}"
echo "3. Restart Docker services: docker compose -f docker-compose.local.yml restart simstudio realtime"
echo "4. Send a test message to your Telegram bot"

