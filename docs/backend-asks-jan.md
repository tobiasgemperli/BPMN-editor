# Backend Requests for Jan — Messaging, Follower Counts & Profile

Scoped asks after testing the live server (`https://odoules.pfn.cz/rest2`). Grouped by priority. HTTP Basic Auth, PascalCase JSON in/out (matching existing endpoints) unless noted.

---

## 1. `FollowerCount` isn't maintained (bug — high priority)

**Verified live (2026-09-09):** the follow *relationship* is stored correctly, but the follower *count* is never recomputed.

Reproduced by following user 14 as user 21:

| Step | `FollowerCount` | `IsFollowedByMe` | `/user/following` |
|------|:---:|:---:|---|
| before | `"1"` | `false` | `[]` |
| after `POST /user/follow/14` | `"1"` ❌ | `true` ✅ | `["14"]` ✅ |
| after `DELETE /user/follow/14` | `"1"` | `false` ✅ | — |

`IsFollowedByMe` is now correct (thank you). But `FollowerCount` stayed `"1"` when it should have become `"2"`. Because the client shows the server's count, an unfollow from a stale `0` even renders **"-1 followers"** in the UI.

**Ask:** derive `FollowerCount` (and `FollowingCount`) from the follow relationships — either recompute on read in `/user/profile/{id}`, or increment/decrement on `POST`/`DELETE /user/follow/{id}`. The client can't compute another user's true follower total on its own.

---

## 2. Profile fields (`/user/settings`, `/user/profile`)

Current `GET /user/settings` returns: `id, uname, name, surname, email, phone, role`. `POST /user/settings` accepts `name, email, phone, thumbnail`. Three gaps for a proper "Edit Profile" screen:

### 2a. Add a `Bio` / "about me" field
- `GET /user/settings` and `GET /user/profile/{id}` should return `Bio` (string, may be empty).
- `POST /user/settings` should accept and store `bio`.
- Purpose: shown on the creator profile screen (the client already has a bio slot, currently always empty).

### 2b. Confirm whether `uname` (username) is changeable
- Can `POST /user/settings` accept a new `uname` (with a uniqueness check → `409` if taken)? Or is `uname` immutable by design?
- Just need a definitive yes/no so the client either offers the field or shows it read-only.

### 2d. Avatar upload format is rejected
`POST /user/settings` with `thumbnail` = single-base64 of the raw PNG bytes (the encoding the old guide app used) returns **`500 "Program fatal error: invalid thumbnail"`** (verified on the QA account 2026-09-09). Reads are multiply-wrapped base64 (profile `Image` ×2, settings `thumbnail` ×3). **What exact format does the write expect** — a data-URI (`data:image/png;base64,…`), double-base64, a specific size/mime? Please document the accepted thumbnail write format (and ideally accept a plain single base64 or a `/files/upload` file id like models do).

### 2c. Delete-account endpoint
- No endpoint exists today. Please add e.g. `DELETE /user/account` (or `POST /user/delete`) that removes the authenticated user (and decides what happens to their models — orphan, transfer, or delete).
- Needed for app-store compliance (both Apple and Google require in-app account deletion).

---

## 3. Messaging backend (Phase 3 — not yet built)

The app has a Messages tab and "Message {creator}" buttons, but no backend exists, so they're placeholders. Proposed minimal 1-to-1 messaging:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/rest2/messages/conversations` | List the current user's conversations (last message + unread count per peer) |
| `GET` | `/rest2/messages/conversation/{userId}` | Full message history with one user (paginated) |
| `POST` | `/rest2/messages/send/{userId}` | Send a message to a user |
| `GET` | `/rest2/messages/unread` | Total unread count (for the tab badge) |

**Message shape:**
```json
{
  "Id": "123",
  "FromUserId": "21",
  "ToUserId": "14",
  "Text": "Love your onboarding diagram!",
  "CreatedAt": "2026-09-09 20:30:00",
  "Read": false
}
```

`POST /messages/send/{userId}` body: `{ "Text": "..." }` → returns the created message. `GET /messages/conversation/{userId}` marks those messages read (or add `POST /messages/read/{userId}`).

**Open question for Jan:** is polling `GET /messages/unread` acceptable for now, or can we get push/websocket later? Polling is fine for v1.

**Note:** the old guide app's ChatFeature is a mock-only prototype (roster/groups UI over `MockChatRepository`, no real transport) — not reusable as a backend. This would be net-new.

---

## Priority

1. **FollowerCount fix** — small, fixes a visible bug.
2. **Bio field + uname/delete answers** — small, unblocks the profile screen.
3. **Messaging** — larger; schedule after the above.
