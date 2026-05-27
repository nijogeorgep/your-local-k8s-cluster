---
description: "Output the exact CLI commands to advance, pause, abort, or retry an Argo Rollouts canary/blue-green, or to trigger and approve a Kargo stage promotion. Use when managing progressive delivery in this cluster."
argument-hint: "What to promote (e.g. rollout my-api, kargo staging→prod)"
agent: agent
tools: [execute, search]
---

You are helping the user manage progressive delivery on this local cluster. Your job is to:
1. Discover the current state of the relevant Rollout or Kargo stage
2. Output the **exact commands** to perform the requested operation

DO NOT modify any files. DO NOT apply any manifests. Only run **read-only** discovery commands (`get`, `describe`, `status`) to gather context, then print the action commands for the user to review and run themselves.

## Argo Rollouts CLI Path
The Argo Rollouts kubectl plugin is at `.\tools\kubectl-plugins\kubectl-argo-rollouts.exe`. Use this path explicitly on Windows. The Makefile alias `make rollouts-ui` launches the dashboard for visual inspection.

## Step 1 — Identify What the User Wants

Ask (or infer from the argument) which operation they need:

**Argo Rollouts operations:**
- **Advance** — manually promote past a `pause` step (e.g. move from 10% → 25%)
- **Full promote** — skip all remaining steps and complete the rollout immediately
- **Pause** — halt the rollout at the current step
- **Abort** — roll back to the stable version immediately
- **Retry** — restart a failed/aborted rollout
- **Status** — just show current rollout state

**Kargo operations:**
- **Promote freight** — trigger promotion of latest freight into a stage (dev/staging/prod)
- **Approve promotion** — manually approve a pending promotion that has `autoPromotionEnabled: false`
- **Status** — show current freight and stage state

If the user didn't specify a rollout name or stage, discover available ones (Step 2).

## Step 2 — Discover Current State

Run the appropriate discovery command based on the operation type:

**For Argo Rollouts:**
```powershell
# List all rollouts across namespaces
.\tools\kubectl-plugins\kubectl-argo-rollouts.exe list rollouts --all-namespaces

# Get detailed status of a specific rollout
.\tools\kubectl-plugins\kubectl-argo-rollouts.exe get rollout <name> -n <namespace> --watch=false
```

**For Kargo:**
```powershell
# List all Kargo stages
kubectl get stages --all-namespaces

# Show freight waiting for promotion
kubectl get freight -n <project-namespace>

# Show pending promotions
kubectl get promotions -n <project-namespace>
```

Show the output so the user can confirm the rollout/stage name and current step before proceeding.

## Step 3 — Output the Action Commands

Print a clearly labelled block of commands. Do NOT run them — present them for the user to execute.

### Argo Rollouts Commands

```powershell
# Advance past current pause step (one step at a time)
.\tools\kubectl-plugins\kubectl-argo-rollouts.exe promote <rollout-name> -n <namespace>

# Fully promote — skip all remaining steps
.\tools\kubectl-plugins\kubectl-argo-rollouts.exe promote <rollout-name> -n <namespace> --full

# Pause at current step
.\tools\kubectl-plugins\kubectl-argo-rollouts.exe pause <rollout-name> -n <namespace>

# Abort — rollback to stable immediately
.\tools\kubectl-plugins\kubectl-argo-rollouts.exe abort <rollout-name> -n <namespace>

# Retry after abort or failure
.\tools\kubectl-plugins\kubectl-argo-rollouts.exe retry rollout <rollout-name> -n <namespace>

# Watch live progress after running a command
.\tools\kubectl-plugins\kubectl-argo-rollouts.exe get rollout <rollout-name> -n <namespace> --watch
```

### Kargo Commands

```powershell
# Trigger promotion of latest freight into a stage (when autoPromotionEnabled: false)
kubectl kargo promote --project <project-name> --freight <freight-id> --stage <stage-name>

# List promotions waiting for approval
kubectl get promotions -n <project-namespace> --field-selector status.phase=Pending

# Approve a pending promotion
kubectl kargo approve --promotion <promotion-name> -n <project-namespace>

# Watch stage status after triggering
kubectl get stage <stage-name> -n <project-namespace> -w
```

> **Tip**: Open the Kargo UI (`make kargo-ui` → http://localhost:8081) or the Argo Rollouts dashboard (`make rollouts-ui`) to monitor progress visually.

## Step 4 — Canary Step Context (Argo Rollouts only)

If the rollout uses a canary strategy with steps, show the user a numbered step map based on the discovered rollout status, so they know which step they are advancing to:

```
Step map for <rollout-name>:
  [1] setWeight: 10%      ← current (paused here)
  [2] pause: 2m
  [3] setWeight: 25%
  [4] pause: 2m
  [5] setWeight: 50%      ← after next promote
  ...
  [N] setWeight: 100%     → stable
```

Highlight the current step and the step they will land on after running `promote`.
