# ForthAI Work Project #9 Board IDs

Reference for all Project #9 field IDs and option IDs used in `gh project` CLI commands.

## Project

- **Project Number:** 9
- **Owner:** Forth-AI
- **Project ID:** PVT_kwDOCrEjbc4BTqhr

## Status Field

- **Field ID:** PVTSSF_lADOCrEjbc4BTqhrzhA3_Wc
- **Options:**
  - Todo: `f75ad846`
  - In Progress: `47fc9ee4`
  - Pending Review: `3eb0a766`
  - Shipped: `98236657`

## Repository

- **Repo:** Forth-AI/work-ssot

## Quick Reference Commands

### Add issue to project

```bash
gh project item-add 9 --owner Forth-AI --url https://github.com/Forth-AI/work-ssot/issues/NUMBER
```

### Get item ID for an issue

```bash
gh project item-list 9 --owner Forth-AI --format json \
  | jq -r '.items[] | select(.content.url == "https://github.com/Forth-AI/work-ssot/issues/NUMBER") | .id'
```

### Set status to Todo

```bash
gh project item-edit --project-id PVT_kwDOCrEjbc4BTqhr \
  --id ITEM_ID \
  --field-id PVTSSF_lADOCrEjbc4BTqhrzhA3_Wc \
  --single-select-option-id f75ad846
```

### Set status to In Progress

```bash
gh project item-edit --project-id PVT_kwDOCrEjbc4BTqhr \
  --id ITEM_ID \
  --field-id PVTSSF_lADOCrEjbc4BTqhrzhA3_Wc \
  --single-select-option-id 47fc9ee4
```

### Set status to Pending Review

```bash
gh project item-edit --project-id PVT_kwDOCrEjbc4BTqhr \
  --id ITEM_ID \
  --field-id PVTSSF_lADOCrEjbc4BTqhrzhA3_Wc \
  --single-select-option-id 3eb0a766
```

### Set status to Shipped

```bash
gh project item-edit --project-id PVT_kwDOCrEjbc4BTqhr \
  --id ITEM_ID \
  --field-id PVTSSF_lADOCrEjbc4BTqhrzhA3_Wc \
  --single-select-option-id 98236657
```
