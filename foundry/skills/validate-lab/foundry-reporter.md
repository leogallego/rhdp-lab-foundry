# Foundry Reporter - Embedded Provisioning Health Reporting

## How It Works

Every lab scaffolded by Lab Foundry includes a hidden reporter that automatically
sends provisioning status back to a central endpoint. Lab creators never see it
or configure it. It just works.

## Where It Lives

The reporter is embedded in two places:

### 1. setup-automation/main.yml (end of provisioning)

The Lab Foundry template for main.yml always ends with:

```yaml
# --- Lab Foundry Reporter (do not remove) ---
- name: Foundry health check
  hosts: localhost
  connection: local
  gather_facts: false
  vars:
    foundry_report_url: "{{ lookup('env', 'FOUNDRY_REPORT_URL') | default('https://foundry-reports.apps.example.com/api/v1/report', true) }}"
    foundry_lab_name: "{{ lookup('env', 'LAB_NAME') | default(ansible_play_name, true) }}"
    foundry_guid: "{{ lookup('env', 'GUID') | default('unknown', true) }}"
  tasks:
    - name: Check services from ui-config
      ansible.builtin.uri:
        url: "{{ item.url | replace('${guid}', foundry_guid) | replace('${domain}', lookup('env', 'DOMAIN') | default('unknown')) }}"
        method: GET
        validate_certs: false
        status_code: [200, 301, 302, 303, 401, 403]
        timeout: 15
      register: service_checks
      loop: "{{ lookup('file', '../ui-config.yml') | from_yaml | json_query('tabs[?url]') }}"
      ignore_errors: true

    - name: Send report
      ansible.builtin.uri:
        url: "{{ foundry_report_url }}"
        method: POST
        body_format: json
        body:
          lab: "{{ foundry_lab_name }}"
          guid: "{{ foundry_guid }}"
          timestamp: "{{ ansible_date_time.iso8601 | default(now()) }}"
          stage: "provisioning"
          services: "{{ service_checks.results | map(attribute='item') | zip(service_checks.results | map(attribute='status', default=-1)) | list }}"
          failures: "{{ service_checks.results | selectattr('failed', 'equalto', true) | list | length }}"
          total: "{{ service_checks.results | length }}"
        status_code: [200, 201, 202]
        timeout: 10
      ignore_errors: true
```

### 2. runtime-automation/main.yml (after each module)

Each module run reports whether setup/solve/validation passed:

```yaml
# --- Lab Foundry Reporter (do not remove) ---
- name: Report module result
  ansible.builtin.uri:
    url: "{{ lookup('env', 'FOUNDRY_REPORT_URL') | default('https://foundry-reports.apps.example.com/api/v1/report', true) }}"
    method: POST
    body_format: json
    body:
      lab: "{{ lookup('env', 'LAB_NAME') | default('unknown') }}"
      guid: "{{ lookup('env', 'GUID') | default('unknown') }}"
      stage: "{{ module_stage }}"
      module: "{{ module_dir | basename }}"
      result: "{{ module_result.rc | default(-1) }}"
      output: "{{ module_result.stdout | default('') | truncate(500) }}"
    status_code: [200, 201, 202]
    timeout: 10
  ignore_errors: true
```

## Central Endpoint

The report endpoint can be:

1. **A simple Flask/FastAPI app** deployed on OpenShift that:
   - Receives POST reports from all provisioned labs
   - Stores them in a database (PostgreSQL) or just logs them
   - Provides a dashboard showing lab health across all instances
   - Sends Slack notifications when failures exceed a threshold

2. **A Slack incoming webhook** (simplest, no infra needed):
   - Reports go directly to a Slack channel
   - Lab creators subscribe to the channel
   - Failed provisions get highlighted

3. **A GitHub Actions webhook** that creates issues on failures

## Default Behavior

- If `FOUNDRY_REPORT_URL` env var is set: reports go there
- If not set: reports go to the default central endpoint
- If the central endpoint is unreachable: silently skipped (ignore_errors: true)
- The reporter NEVER fails the provisioning. It's fire-and-forget.

## What Gets Reported

```json
{
  "lab": "zt-ans-bu-cert-lifecycle",
  "guid": "abc123",
  "timestamp": "2026-05-21T15:00:00Z",
  "stage": "provisioning",
  "services": [
    {"name": "AAP Controller", "url": "https://control-abc123.example.com", "status": 200},
    {"name": "Gitea", "url": "https://gitea-abc123.example.com", "status": 200},
    {"name": "Splunk", "url": "https://splunk-abc123.example.com", "status": -1}
  ],
  "failures": 1,
  "total": 3
}
```

## Privacy and Security

- No student data is sent, only service health status
- No credentials or passwords in reports
- Lab creators can set FOUNDRY_REPORT_URL="" to disable entirely
- The reporter runs as the LAST task, so it doesn't affect provisioning
