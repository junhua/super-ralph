# Project Board IDs

> **Config:** All project-specific IDs are loaded from `.claude/super-ralph-config.md`. This file is auto-generated on first use by any super-ralph command. This document explains the structure and meaning of each field.

## Project

- **Project Number:** `$PROJECT_NUM`
- **Owner:** `$ORG`
- **Project ID:** `$PROJECT_ID`

## Status Field

- **Field ID:** `$STATUS_FIELD_ID`
- **Options:**
  - Todo: `$STATUS_TODO`
  - In Progress: `$STATUS_IN_PROGRESS`
  - Pending Review: `$STATUS_PENDING_REVIEW`
  - Shipped: `$STATUS_SHIPPED`

## Repository

- **Repo:** `$REPO`

## Quick Reference Commands

### Add issue to project

```bash
gh project item-add $PROJECT_NUM --owner $ORG --url https://github.com/$REPO/issues/NUMBER
```

### Get item ID for an issue

```bash
gh project item-list $PROJECT_NUM --owner $ORG --format json \
  | jq -r '.items[] | select(.content.url == "https://github.com/$REPO/issues/NUMBER") | .id'
```

### Set status to Todo

```bash
gh project item-edit --project-id $PROJECT_ID \
  --id ITEM_ID \
  --field-id $STATUS_FIELD_ID \
  --single-select-option-id $STATUS_TODO
```

### Set status to In Progress

```bash
gh project item-edit --project-id $PROJECT_ID \
  --id ITEM_ID \
  --field-id $STATUS_FIELD_ID \
  --single-select-option-id $STATUS_IN_PROGRESS
```

### Set status to Pending Review

```bash
gh project item-edit --project-id $PROJECT_ID \
  --id ITEM_ID \
  --field-id $STATUS_FIELD_ID \
  --single-select-option-id $STATUS_PENDING_REVIEW
```

### Set status to Shipped

```bash
gh project item-edit --project-id $PROJECT_ID \
  --id ITEM_ID \
  --field-id $STATUS_FIELD_ID \
  --single-select-option-id $STATUS_SHIPPED
```
