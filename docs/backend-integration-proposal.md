# Backend Integration Proposal — StepChat × Guide API

## Overview

The StepChat app uses BPMN 2.0 XML as its diagram format. I'd propose the backend stores BPMN XML as an opaque text blob. The backend handles storage, listing, and user management. All diagram logic (parsing, rendering, editing) stays on the client.

Integration is split into three phases so we can ship incrementally.

---

## Phase 1 — BPMN Storage (Backend + Frontend)

Goal: Save, load, update, and delete BPMN diagrams on the server instead of local-only storage.

### Existing Endpoints — No Changes Needed

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/rest2/browser/list` | List/search models (metadata only) |

### Existing Endpoint — Needs Modification

#### `GET /rest2/browser/getmodel/{id}`

**Current behavior:** Returns model with `Nodes` array in guide format.

**Requested change:** Return a new field `BpmnXml` containing the raw BPMN 2.0 XML string. The `Nodes` array can remain for backward compatibility with the existing guide frontend.

**Updated response example:**
```json
{
  "Id": "42",
  "OwnerName": "Maria Chen",
  "Created": "2026-06-20 10:30:00",
  "Name": "Customer Onboarding",
  "Version": "2",
  "Keywords": ["onboarding", "customer"],
  "Sources": ["Sales"],
  "Categories": ["Operations"],
  "Nodes": [],
  "BpmnXml": "<?xml version=\"1.0\" encoding=\"UTF-8\"?><definitions ...>...</definitions>"
}
```

### New Endpoints

#### 1. `POST /rest2/browser/savemodel`

Create a new model. Returns the created model with its assigned `Id`.

**Request body:**
```json
{
  "Name": "Customer Onboarding",
  "Content": "Optional description",
  "Keywords": ["onboarding"],
  "Sources": ["Sales"],
  "Categories": ["Operations"],
  "BpmnXml": "<?xml version=\"1.0\" ...>...</definitions>"
}
```

**Response (200):**
```json
{
  "Id": "42",
  "OwnerName": "test",
  "Created": "2026-06-26 14:00:00",
  "Name": "Customer Onboarding",
  "Version": "1"
}
```

**Errors:**
- `401` — invalid credentials
- `400` — missing required fields (`Name`, `BpmnXml`)

#### 2. `PUT /rest2/browser/updatemodel/{id}`

Update an existing model. Only provided fields are updated.

**Request body:**
```json
{
  "Name": "Customer Onboarding v2",
  "Keywords": ["onboarding", "revised"],
  "BpmnXml": "<?xml version=\"1.0\" ...>...</definitions>"
}
```

**Response (200):**
```json
{
  "Id": "42",
  "Version": "2",
  "Name": "Customer Onboarding v2"
}
```

**Errors:**
- `401` — invalid credentials
- `403` — not the owner
- `404` — model not found

#### 3. `DELETE /rest2/browser/deletemodel/{id}`

Delete a model by ID. Only the owner can delete.

**Response (200):**
```json
{
  "success": true
}
```

**Errors:**
- `401` — invalid credentials
- `403` — not the owner
- `404` — model not found

### Database Changes

One change to the existing model/guide table:

| Column | Type | Description |
|--------|------|-------------|
| `BpmnXml` | TEXT | Raw BPMN 2.0 XML string, nullable |

The existing `Nodes` column stays untouched for backward compatibility.

### Frontend Work (StepChat)

- Replace local `DiagramStorage` with API client calling the new endpoints
- Wire Save button to `POST savemodel` / `PUT updatemodel`
- Load diagrams from `GET getmodel/{id}` and parse `BpmnXml`
- Discover screen fetches from `POST browser/list` instead of sample data

### Summary

| Task | Side | Effort |
|------|------|--------|
| Add `BpmnXml` column | Backend | Small |
| Return `BpmnXml` in `getmodel` | Backend | Small |
| `POST savemodel` | Backend | Medium |
| `PUT updatemodel/{id}` | Backend | Medium |
| `DELETE deletemodel/{id}` | Backend | Small |
| API client + wire up UI | Frontend | Medium |

---

## Phase 2 — User Accounts & Real Data

Goal: Replace hardcoded sample creators and diagrams with real user accounts and server data.

### What Exists on Backend (ready to use)

| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/rest2` | Login / verify credentials |
| GET | `/rest2/user/settings` | Get user profile |
| POST | `/rest2/user/settings` | Update user profile (name, email, thumbnail) |
| POST | `/rest2/user/setpass` | Change password |
| GET | `/rest2/user/regstart` | Start registration (returns captcha) |
| POST | `/rest2/user/regfinish` | Complete registration |
| GET | `/rest2/user/regState/{token}` | Check registration status |

### What Exists on Frontend (currently fake)

| Feature | Current State | Phase 2 Target |
|---------|--------------|----------------|
| Creator profiles (Maria Chen, etc.) | Hardcoded `SampleCreator` objects | Fetched from backend user data |
| Discover screen diagrams | Hardcoded `SampleDiagrams` | Fetched from `POST browser/list` |
| "My Flowcharts" section | Local storage only | Filtered `browser/list` by current user |
| Follow button | Does nothing | Needs new backend endpoint |
| User avatar | Hardcoded images | From `user/settings` thumbnail |

### New Backend Endpoints Needed

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/rest2/user/profile/{userId}` | View another user's public profile |
| POST | `/rest2/user/follow/{userId}` | Follow a user |
| DELETE | `/rest2/user/follow/{userId}` | Unfollow a user |
| GET | `/rest2/user/followers` | List current user's followers |
| GET | `/rest2/user/following` | List users the current user follows |

### Frontend Work (StepChat)

- Login / registration screens
- Persist auth token (secure storage)
- Replace all sample data with API calls
- User profile screen connected to real data
- Follow/unfollow functionality

---

## Phase 3 — User-to-User Messaging

Goal: Let users message each other about diagrams.

### Current State

The "Message" button on creator profiles shows: *"Messaging is not available yet"*

### New Backend Endpoints Needed

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/rest2/messages/conversations` | List conversations for current user |
| GET | `/rest2/messages/conversation/{userId}` | Get messages with a specific user |
| POST | `/rest2/messages/send/{userId}` | Send a message to a user |
| GET | `/rest2/messages/unread` | Get unread message count |

### Message Model

```json
{
  "id": "msg_123",
  "fromUserId": "5",
  "toUserId": "12",
  "text": "Love your onboarding diagram!",
  "timestamp": "2026-06-26T14:30:00Z",
  "read": false
}
```

### Frontend Work (StepChat)

- Conversation list screen
- Chat screen (1-on-1 messaging)
- Unread badge on Message button
- Push notifications (optional)

---


## Authentication Note

The current system uses HTTP Basic Auth with shared test credentials (`test:j5K_fv3sg`). For production (Phase 2+), we recommend upgrading to token-based auth (JWT). This gives us:
- Per-user identity
- Session expiry
- Secure credential handling on mobile

This can be implemented as part of Phase 2 when we connect real user accounts.
