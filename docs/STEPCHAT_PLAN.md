# STEPCHAT — Combined Development Plan

## Phase 1 — Finishing & BPMN Storage

### 1A: Stability & Core Fixes

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 1 | Autosave on by default (fix crash on save/media) | Frontend | High |
| 2 | Close button consistency — single button, top-left, all views | Frontend | High |
| 3 | Add `BpmnXml` TEXT column to model table | Backend | High |
| 4 | Return `BpmnXml` in `GET /rest2/browser/getmodel/{id}` | Backend | High |
| 5 | `POST /rest2/browser/savemodel` — create new model | Backend | High |
| 6 | `PUT /rest2/browser/updatemodel/{id}` — update existing model | Backend | High |
| 7 | `DELETE /rest2/browser/deletemodel/{id}` — delete model | Backend | High |
| 8 | Replace local `DiagramStorage` with API client | Frontend | High |
| 9 | Wire Save button to `savemodel` / `updatemodel` | Frontend | High |
| 10 | Load diagrams from `getmodel/{id}`, parse `BpmnXml` | Frontend | High |
| 11 | Discover screen fetches from `POST browser/list` | Frontend | High |

### 1B: GUI Fixes

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 12 | Start/Finish nodes — add TEXT, IMAGE, LINK, PDF options | Frontend | Medium |
| 13 | Text display — allow up to 3 images instead of 1 | Frontend | Medium |
| 14 | Text display — add spellcheck | Frontend | Medium |
| 15 | Text display — show character limit indicator | Frontend | Low |
| 16 | Link display — fix icon (shows PDF, should be WWW) or allow PDF attachment | Frontend | Medium |
| 17 | PDF attachment — add ability to attach documents to text steps | Frontend + Backend | Medium |
| 18 | Image/Video viewer — default to full-picture view (not zoom-to-fill) | Frontend | Medium |
| 19 | Image/Video viewer — tap to toggle zoom, pinch-to-zoom | Frontend | Medium |
| 20 | Image+Text view — fix duplicate step text bug | Frontend | Medium |
| 21 | Image+Text view — fix URL covered by Android nav bar | Frontend | Medium |

### 1C: Display Mode Refactor

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 22 | Implement 3 display modes: | Frontend | Medium |
|   | - Image mode: full-screen image + step name + link + PDF | | |
|   | - Video mode: full-screen video + step name + link + PDF | | |
|   | - Text mode: text + up to 3 thumbnails + link + PDF (no video) | | |

### 1D: Limits & Guardrails

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 23 | Define modeling limits (max objects, media count, video duration/quality) | Content | Medium |
| 24 | Enforce limits in app and display to user | Frontend | Medium |
| 25 | Validate limits server-side | Backend | Medium |

### 1E: Payments (can run in parallel)

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 26 | Decide payment provider: Stripe (USA) / Paddle (EU VAT) / Mollie (EU+USA) | Content | Medium |
| 27 | Add FREE / PAID toggle on guide creation | Frontend | Medium |
| 28 | Integrate payment provider — account connection, 80/20 revenue split | Backend | Medium |
| 29 | Store FREE/PAID flag, gate access to paid guides | Backend | Medium |

---

## Phase 2 — User Accounts & Real Data

### 2A: Auth & Registration

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 30 | Login screen | Frontend | High |
| 32 | Registration screen (using existing `regstart` / `regfinish`) | Frontend | High |
| 33 | Persist auth token in secure storage | Frontend | High |

Backend endpoints already exist:
- `POST /rest2` — login
- `GET /rest2/user/regstart` — registration captcha
- `POST /rest2/user/regfinish` — complete registration
- `GET /rest2/user/regState/{token}` — check registration status

### 2B: Replace Sample Data

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 34 | Replace hardcoded `SampleCreator` objects with real user data | Frontend | High |
| 35 | Replace hardcoded `SampleDiagrams` with `POST browser/list` | Frontend | High |
| 36 | "My Flowcharts" — filtered `browser/list` by current user | Frontend | High |
| 37 | User profile screen — connected to `user/settings` + real avatar | Frontend | Medium |
| 38 | Prepare real seed content to replace samples | Content | Medium |

### 2C: Social Features

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 39 | `GET /rest2/user/profile/{userId}` — public profile | Backend | Medium |
| 40 | `POST /rest2/user/follow/{userId}` — follow | Backend | Medium |
| 41 | `DELETE /rest2/user/follow/{userId}` — unfollow | Backend | Medium |
| 42 | `GET /rest2/user/followers` — list followers | Backend | Medium |
| 43 | `GET /rest2/user/following` — list following | Backend | Medium |
| 44 | Wire follow/unfollow in app | Frontend | Medium |
| 45 | Define public profile fields | Content | Medium |

---

## Phase 3 — User-to-User Messaging

| # | Task | Owner | Priority |
|---|------|-------|----------|
| 46 | `GET /rest2/messages/conversations` — list conversations | Backend | Medium |
| 47 | `GET /rest2/messages/conversation/{userId}` — get messages | Backend | Medium |
| 48 | `POST /rest2/messages/send/{userId}` — send message | Backend | Medium |
| 49 | `GET /rest2/messages/unread` — unread count | Backend | Medium |
| 50 | Conversation list screen | Frontend | Medium |
| 51 | Chat screen (1-on-1) | Frontend | Medium |
| 52 | Unread badge on Message button | Frontend | Low |
| 53 | Push notifications | Frontend + Backend | Low |
