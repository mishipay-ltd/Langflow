# Langflow + Datadog Integration Setup

Setup Langflow on a macOS Intel iMac (2017) to build AI-powered flows
that query and analyze Datadog metrics using Anthropic Claude.

---

## Prerequisites

- macOS (Intel iMac 2017)
- Anthropic API key
- Datadog API key + Application key

---

## Quick Start

```bash
# 1. Make the setup script executable
chmod +x setup.sh

# 2. Run it
./setup.sh
```

The script will check for Docker, pull and start Langflow, then print
manual steps for configuring API keys.

If you prefer to do it manually, follow the phases below.

---

## Phase 1: Install Docker Desktop

1. Download **Docker Desktop for Mac (Intel chip)** from:
   https://docs.docker.com/desktop/setup/install/mac-install/

2. Open the `.dmg`, drag Docker to Applications, and launch it.

3. Wait for the whale icon in the menu bar to indicate Docker is ready.

4. Verify in Terminal:

```bash
docker --version
docker compose version
```

Expected output (versions may differ):
```
Docker version 24.x.x
Docker Compose version v2.x.x
```

---

## Phase 2: Start Langflow

```bash
# Create project directory
mkdir -p ~/langflow-datadog
cd ~/langflow-datadog

# Copy docker-compose.yml to this directory (already provided in this repo)
# Then start Langflow:
docker compose up -d

# Watch logs until you see "Uvicorn running on http://0.0.0.0:7860"
docker compose logs -f langflow
```

Open **http://localhost:7860** in your browser. You should see the Langflow UI.

### Useful commands

```bash
# Stop Langflow
docker compose down

# Stop and remove all data (fresh start)
docker compose down -v

# View logs
docker compose logs -f langflow

# Restart
docker compose restart langflow
```

---

## Phase 3: Configure Anthropic API Key

1. Open http://localhost:7860
2. Click the **gear icon** (bottom-left) > **Global Variables**
3. Click **Add New**
4. Fill in:
   - **Variable Name**: `ANTHROPIC_API_KEY`
   - **Type**: `Credential`
   - **Value**: your Anthropic API key (starts with `sk-ant-...`)
5. Click **Save**

---

## Phase 4: Configure Datadog Credentials

You need two keys from Datadog:

| Key | Where to find it |
|-----|-----------------|
| API Key | Datadog > Organization Settings > API Keys |
| Application Key | Datadog > Organization Settings > Application Keys (create one if needed) |

In Langflow **Settings > Global Variables**, add two variables:

1. **Variable Name**: `DD_API_KEY` / **Type**: `Credential` / **Value**: your Datadog API key
2. **Variable Name**: `DD_APP_KEY` / **Type**: `Credential` / **Value**: your Datadog Application key

---

## Phase 5: Build the Datadog Query Flow

### Architecture

```
User Question --> Prompt --> Claude (Anthropic) --> API Request (Datadog) --> Chat Output
```

### Step-by-step

1. **Create a new flow**
   - Click **New Flow** > **Blank Flow**
   - Name it `Datadog Query Assistant`

2. **Add Chat Input**
   - From the sidebar, drag **Chat Input** onto the canvas
   - No special configuration needed

3. **Add Prompt component**
   - Drag a **Prompt** component onto the canvas
   - Set the template to:

   ```
   You are a Datadog metrics assistant for MishiPay infrastructure.

   The user will ask questions about system metrics. Your job is to:
   1. Understand the user's question
   2. Formulate a Datadog metrics query using Datadog query syntax
   3. Determine the appropriate time range

   Common Datadog metric queries:
   - CPU: avg:system.cpu.user{*}, avg:system.cpu.system{*}
   - Memory: avg:system.mem.used{*}, avg:system.mem.free{*}
   - Disk: avg:system.disk.used{*}, avg:system.disk.free{*}
   - Network: avg:system.net.bytes_rcvd{*}, avg:system.net.bytes_sent{*}
   - Load: avg:system.load.1{*}, avg:system.load.5{*}

   You can filter by host: avg:system.cpu.user{host:web-server-01}
   You can filter by environment: avg:system.cpu.user{env:production}

   Based on the Datadog API response data provided, summarize the metrics
   in plain English. Include:
   - The metric name and what it measures
   - The time range covered
   - Key values (min, max, average if available)
   - Any notable trends or anomalies

   User question: {user_question}

   Datadog API response data: {datadog_response}
   ```

   - Connect **Chat Input** message output -> **Prompt** `user_question` input

4. **Add Anthropic model component**
   - Drag **Anthropic** from Models section
   - Set **Model Name**: `claude-sonnet-4-20250514` (or latest available)
   - The `ANTHROPIC_API_KEY` global variable should auto-populate
   - Connect **Prompt** output -> **Anthropic** input

5. **Add API Request component** (for Datadog)
   - Drag **API Request** onto the canvas
   - Configure:
     - **URLs**: `https://api.datadoghq.com/api/v1/query`
     - **Method**: `GET`
     - **Headers**:
       | Key | Value |
       |-----|-------|
       | DD-API-KEY | (paste your DD_API_KEY or reference global variable) |
       | DD-APPLICATION-KEY | (paste your DD_APP_KEY or reference global variable) |
     - **Query Parameters**:
       | Key | Value |
       |-----|-------|
       | from | (unix timestamp - e.g., 1 hour ago) |
       | to | (unix timestamp - now) |
       | query | (the Datadog query string) |

   Note: For the first test, you can hardcode a simple query. Later,
   you'll wire this to receive dynamic values from Claude.

6. **Add Chat Output**
   - Drag **Chat Output** onto the canvas
   - Connect **Anthropic** text output -> **Chat Output** input

7. **Wire it all together**
   - Chat Input -> Prompt (user_question)
   - API Request response -> Prompt (datadog_response)
   - Prompt -> Anthropic -> Chat Output

### First test (hardcoded)

For your first test, hardcode these values in the API Request component:
- `from`: run `date -v-1H +%s` in terminal to get 1-hour-ago timestamp
- `to`: run `date +%s` in terminal to get current timestamp
- `query`: `avg:system.cpu.user{*}`

Click the **Play** button in the flow editor to test.

---

## Phase 6: Verify End-to-End

1. Open the **Playground** (play button top-right of flow editor)
2. Type: "What is the average CPU utilization across all hosts in the last hour?"
3. Verify:
   - Claude understands the question
   - The API request hits Datadog and returns data
   - Claude summarizes the metrics clearly
4. If something fails, check logs:

```bash
docker compose logs -f langflow
```

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Docker not starting | Ensure Docker Desktop is open and the whale icon shows "Running" |
| Langflow not loading | Run `docker compose logs -f langflow` and check for errors |
| API key errors | Verify global variables are set correctly in Settings |
| Datadog 403 error | Check that both API key AND Application key are correct |
| Datadog 400 error | Verify the query syntax (e.g., `avg:system.cpu.user{*}`) |
| Slow startup | First pull can take 5-10 minutes depending on network speed |

---

## File Structure

```
langflow-datadog/
├── docker-compose.yml    # Langflow container configuration
├── setup.sh              # Automated setup script
└── README.md             # This file
```
