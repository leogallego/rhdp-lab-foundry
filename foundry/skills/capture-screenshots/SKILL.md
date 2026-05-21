---
name: foundry:capture-screenshots
description: Capture screenshots of all lab services using Playwright MCP and embed them in Showroom content. Use when asked to "take screenshots", "capture screenshots", "add screenshots to my lab", "screenshot the services", or "generate visual references".
context: main
model: claude-sonnet-4-6
---

# Capture Screenshots - Playwright-Powered Lab Visuals

Navigates to each service in a running lab environment, captures screenshots, and embeds them in the Antora content pages.

## Prerequisites

- Lab must be provisioned and running (services accessible)
- Playwright MCP server must be configured in Claude Code
- Lab must have a `ui-config.yml` with tabs defining service URLs

## Workflow

### Step 1: Read lab configuration

Read `ui-config.yml` to get the list of service tabs with URLs.
Read `.foundry.yml` for lab metadata (guid, domain).

If the lab is running, ask the user for the base URL or GUID:
"What's your lab's GUID or base URL? (e.g., abc123 or https://control-abc123.apps.example.com)"

### Step 2: Build URL list

For each tab in ui-config.yml, resolve the actual URL by substituting
`${guid}` and `${domain}` with the provided values.

### Step 3: Capture screenshots

For each service URL, use Playwright MCP to:

1. Navigate to the URL:
   ```
   mcp__playwright__browser_navigate(url="https://control-{guid}.{domain}")
   ```

2. Handle login if needed:
   - If a login page is detected (look for username/password fields), 
     fill with known default credentials (admin/ansible123 for AAP,
     admin/RedHat123! for Splunk, etc.)
   - Use `mcp__playwright__browser_snapshot` to check the page state
   - Use `mcp__playwright__browser_fill_form` for login fields

3. Wait for the page to load:
   ```
   mcp__playwright__browser_wait_for(time=3)
   ```

4. Take the screenshot:
   ```
   mcp__playwright__browser_take_screenshot(
     type="png",
     filename="content/modules/ROOT/images/{service_name}.png"
   )
   ```

5. For AAP-specific pages, navigate to key views:
   - Templates page: `/#!/templates`
   - Inventories page: `/#!/inventories`
   - Jobs page: `/#!/jobs`
   - Workflow Visualizer: specific workflow URL
   Take a screenshot of each.

### Step 4: Embed in content

For each screenshot captured, find the corresponding content page
and insert an image reference:

```adoc
.{Service Name} Dashboard
image::{service_name}.png[{Service Name}]
```

Insert images at logical positions:
- Service overview screenshots go in the "Explore the Environment" module
- Workflow screenshots go in the module that uses that workflow
- Dashboard screenshots go at the start of the relevant module

### Step 5: Create images directory if needed

```bash
mkdir -p content/modules/ROOT/images/
```

## Service-Specific Screenshot Sequences

### AAP Controller
1. Login page (before login)
2. Dashboard (after login)
3. Templates list
4. Inventories list
5. Workflow Visualizer (if workflow exists)

### Splunk
1. Login page
2. Search & Reporting home
3. Any saved searches/dashboards

### Mattermost
1. Channel view with messages

### Gitea
1. Repository list

### Custom Dashboard
1. Main dashboard view
2. Service status cards

## Screenshot Naming Convention

```
content/modules/ROOT/images/
  aap-dashboard.png
  aap-templates.png
  aap-workflow.png
  splunk-dashboard.png
  gitea-repos.png
  mattermost-channel.png
  dashboard-overview.png
```

## When Playwright MCP Is Not Available

If Playwright MCP is not configured:
1. Generate placeholder image references in the content
2. Print instructions for the user to take screenshots manually
3. Provide the list of URLs and suggested filenames

```adoc
// TODO: Add screenshot
// URL: https://control-{guid}.{domain}
// Save as: content/modules/ROOT/images/aap-dashboard.png
image::aap-dashboard.png[AAP Dashboard - screenshot pending]
```

## Important

- ALWAYS check if Playwright MCP tools are available before attempting screenshots
- Login credentials come from .foundry.yml or lab defaults, never hardcode in content
- Screenshots should be taken at a consistent viewport size (1280x720)
- Resize browser before capturing: `mcp__playwright__browser_resize(width=1280, height=720)`
- Close the browser when done: `mcp__playwright__browser_close()`
