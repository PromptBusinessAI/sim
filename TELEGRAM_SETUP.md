# Telegram Webhook Setup Guide

## Key Learnings & Setup Process

### Prerequisites
1. Docker services running (`docker compose -f docker-compose.local.yml up -d`)
2. Cloudflare tunnel installed (`cloudflared`)
3. Telegram bot token

### Setup Steps

#### 1. Start Cloudflare Tunnel
```bash
cloudflared tunnel --url http://localhost:3000
```
**Note:** This needs to be run each time you start the services. The URL changes each time.

#### 2. Update Docker Environment
Update `NEXT_PUBLIC_APP_URL` in `docker-compose.local.yml` with the new tunnel URL:
```yaml
- NEXT_PUBLIC_APP_URL=https://your-new-tunnel-url.trycloudflare.com
```

Then rebuild/restart services:
```bash
docker compose -f docker-compose.local.yml up -d --build simstudio realtime
```

#### 3. Get Webhook Path from Database
The webhook path is stored in the database. You can find it by:
- Looking at the Telegram trigger block in your workflow UI
- Or querying the database:
```bash
docker compose -f docker-compose.local.yml exec -T db psql -U postgres -d simstudio -c "SELECT path FROM webhook WHERE provider = 'telegram' AND is_active = true;"
```

#### 4. Set Telegram Webhook
Use the webhook path in the curl command:
```bash
curl -X POST "https://api.telegram.org/bot<YOUR_BOT_TOKEN>/setWebhook" \
  -H "Content-Type: application/json" \
  -d '{"url":"https://your-tunnel-url.trycloudflare.com/api/webhooks/trigger/<WEBHOOK_PATH>"}'
```

### Automated Setup Script
Use the provided `setup-telegram-webhook.sh` script to automate steps 2-4:
```bash
./setup-telegram-webhook.sh
```

### Build Optimization
The Docker build excludes docs to speed up builds:
- Modified `docker/app.Dockerfile` to use `--filter='!docs'`
- This significantly reduces build time

### Workflow Configuration
Ensure your workflow has the correct connections:
- **Telegram Trigger** → **Agent Block** → **Telegram Send Block**
- The Agent block should output to the Telegram Send block, not back to the trigger

### Troubleshooting

#### Webhook returns 404
- Check if webhook exists in database: `SELECT * FROM webhook WHERE path = '<your-path>';`
- If missing, create it manually or recreate in the UI

#### Messages not being sent
- Verify workflow connections (Agent → Telegram Send)
- Check execution logs: `docker compose -f docker-compose.local.yml logs simstudio | grep -E "ERROR|telegram"`
- Verify bot token is correct in Telegram Send block

#### Enhanced Error Messages
If Telegram send fails after AI message generation, you'll see:
```
An Ollama/AI message was ready to send, but Telegram send failed. Cause: [error details]
```

