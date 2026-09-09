# Backend Plan & Open Points for Jan

Reviewed against everything already answered — this lists **only what's still open**, plus a suggested order. Headline: we want **chat**.

---

## ✅ Confirmed working — thank you, no action needed

So we don't re-ask: these are verified done on the live server.

- `?withContent` on `/browser/list` (hydrates BpmnXml in one call)
- `updatemodel` now returns **409** on a bad field (was 500)
- `/files/file/{id}` serves the real **Content-Type**
- **Admin account** (gtobias/21) + the one-time Nodes→BpmnXml migration (done)
- `/user/thumbnail/{id}`, `ownerid` list filter
- `/user/profile` **`IsFollowedByMe`** now correct
- Model thumbnails via `ThumbnailFileId` (upload → attach → serve)
- `/browser/list` trailing-slash 500 — you couldn't reproduce; treating as resolved

---

## 🔧 Open fixes (small)

### 1. `FollowerCount` still isn't updated (follow-up to "profile fixed")
The `IsFollowedByMe` half is fixed — thanks. The **count** half still doesn't move. Verified 2026-09-09 (followed 14 as 21):

| step | `FollowerCount` | `IsFollowedByMe` |
|------|:---:|:---:|
| before | `"1"` | `false` |
| after follow | `"1"` ❌ | `true` ✅ |
| after unfollow | `"1"` | `false` |

The relationship is stored (following list is right), but the aggregate isn't recomputed. **Ask:** derive `FollowerCount`/`FollowingCount` from the follow table (recompute on read, or ±1 on follow/unfollow).

### 2. Own-avatar write format (follow-up to "settings should store thumbnail now")
`POST /user/settings` with `thumbnail` = single-base64 of the PNG returns **`500 "invalid thumbnail"`** (verified on QA/22). Reads are multiply-wrapped (profile `Image` ×2, settings `thumbnail` ×3). **Ask:** what format does the write expect (data-URI? double-base64? size limit?) — or, simplest, accept a plain single base64 or a `/files/upload` file id like models do.

### 3. `Bio` / "about me" field
Add `Bio` to `GET /user/settings` + `GET /user/profile/{id}`, and accept `bio` on `POST /user/settings`. The profile screen already has an (always-empty) bio slot.

### 4. Is `uname` changeable?
Can `POST /user/settings` accept a new `uname` (uniqueness → 409), or is it immutable? Just need a yes/no so the client shows the field editable or read-only.

### 5. Delete-account endpoint
None exists. Add e.g. `DELETE /user/account` (decide models' fate: orphan/transfer/delete). Required for App Store / Play Store compliance.

---

## 💬 Next big thing — Messaging / Chat backend

This is the priority. The app already has a Messages tab and "Message {creator}" buttons, but there's **no backend**, so they're placeholders. (The old guide app's ChatFeature is mock-only — not reusable.) Proposed minimal 1-to-1 messaging:

| Method | Endpoint | Purpose |
|--------|----------|---------|
| `GET` | `/rest2/messages/conversations` | List conversations (peer + last message + unread count) |
| `GET` | `/rest2/messages/conversation/{userId}` | Message history with one user (paginated); marks them read |
| `POST` | `/rest2/messages/send/{userId}` | Send `{ "Text": "..." }` → returns the created message |
| `GET` | `/rest2/messages/unread` | Total unread (for the tab badge) |

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

Polling `GET /messages/unread` is fine for v1; push/websocket can come later.

---

## Suggested order for Jan

1. **Messaging backend** (the 4 endpoints above) — biggest, and it's what we want next; unblocks the whole Messages tab + Message buttons.
2. **`FollowerCount` fix + avatar write format** — small, each fixes a visible bug.
3. **`Bio` field + `uname` answer + delete-account** — small, unblocks the Edit-Profile screen.
