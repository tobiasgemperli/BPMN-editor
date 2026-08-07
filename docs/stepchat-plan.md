# StepChat — Development Plan

---

## Phase 1.1 — BPMN Storage (finishing) - 9.8.2026

Core app and backend storage are done. Remaining items from feedback:

### Tobias (Frontend)
- [x] Discover screen with categories and sample diagrams from backend
- [x] Search screen with results from  backend
- [x] Load models from backend
- [x] Save/update models to backend (auto-sync on save)
- [x] Delete diagrams (long-press, local + server)
- [ ] Image display: show full picture first, tap to zoom, pinch zoom
- [ ] Fix duplicate step text on IMAGE+TEXT cards
- [ ] Close button consistency — top-left on all modals
- [ ] Autosave (debounced, 5s after last edit)
- [ ] Allow content on Start/End nodes (text, image, link)
- [ ] Support multiple images (1-3) in Text display mode
- [ ] Simplify to 3 display modes: Image, Video, Text
- [ ] Fix NAME vs CONTENT TITLE redundancy
- [ ] Rename "Document" to "Link"
- [ ] Modeling limits (max ~50 nodes, warn user)

### Jan (Backend)
- [x] `POST /rest2/browser/list` — list/search models
- [x] `GET /rest2/browser/getmodel/{id}` — get model with BpmnXml
- [x] `POST /rest2/browser/savemodel` — create new model
- [x] `PUT /rest2/browser/updatemodel/{id}` — update model
- [x] `DELETE /rest2/browser/deletemodel/{id}` — delete model
- [x] BpmnXml column added to database

### Ondrej (Content)
- [ ] Create at least 5 real guides with proper text, images, videos
- [ ] Define categories

---

## Phase 2 — User Accounts & Real Data - 21.8.2026

Auth: We use the existing Basic Auth with per-user credentials. Login and registration endpoints already exist. The Guide app already has working screens we can adapt.

### Tobias (Frontend)
- [ ] Upload media (image/video/PDF) on save, replace local paths with URLs
- [ ] Login screen (adapt from existing Guide app, use Basic Auth)
- [ ] Registration screen with captcha (adapt from existing Guide app)
- [ ] Persist credentials in secure storage
- [ ] Auto-login on app launch if credentials saved
- [ ] Account screen — real profile data, edit name/email/avatar
- [ ] Change password screen
- [ ] "My Flowcharts" filtered by logged-in user

### Jan (Backend)


Already exists (no changes needed):
- [x] `POST /rest2` — login / verify credentials
- [x] `GET /rest2/user/settings` — get user profile
- [x] `POST /rest2/user/settings` — update user profile
- [x] `POST /rest2/user/setpass` — change password
- [x] `GET /rest2/user/regstart` — start registration (captcha)
- [x] `POST /rest2/user/regfinish` — complete registration
- [x] `GET /rest2/user/regState/{token}` — check registration status

New (required for media in guides):
- [ ] `POST /rest2/media/upload` — upload image/video/PDF, returns a URL
- [ ] `GET /rest2/media/{id}` — serve uploaded media file

New endpoints (for Tobias in Phase 3):
- [ ] `GET /rest2/user/profile/{userId}` — public profile (Name, Thumbnail, Bio, ModelCount, FollowerCount, IsFollowedByMe)
- [ ] `POST /rest2/user/follow/{userId}` — follow a user
- [ ] `DELETE /rest2/user/follow/{userId}` — unfollow a user
- [ ] `GET /rest2/user/followers` — list current user's followers
- [ ] `GET /rest2/user/following` — list users the current user follows

### Ondrej (Content)
- [ ] Define content strategy: which sample creators to keep vs. replace
- [ ] Prepare list of real creator profiles (names, bios, avatars)
- [ ] Prepare categories

---

## Phase 3 — Social & Messaging - 4.9.2026

Jan's endpoints from Phase 2 are now ready.

### Tobias (Frontend)
- [ ] Creator profile screen with real server data
- [ ] Follow / unfollow button
- [ ] Followers / following lists on profile screen
- [ ] Real avatars everywhere (cards, search, profile chips)
- [ ] Remove all sample creators and hardcoded demo data
- [ ] Conversation list screen
- [ ] Chat screen (1-on-1 messaging)
- [ ] Unread badge on Messages tab

### Jan (Backend)
- [ ] `GET /rest2/messages/conversations` — list conversations
- [ ] `GET /rest2/messages/conversation/{userId}` — get messages with a user
- [ ] `POST /rest2/messages/send/{userId}` — send a message
- [ ] `GET /rest2/messages/unread` — get unread message count

### Ondrej (Content)
- [ ] Prepare and upload real guide content with images and videos

---

## Phase 4 — Bug Fixes & Improvements - 18.9.2026

All features complete. Focus on stability and release.

### Tobias (Frontend)
- [ ] Bug fixes from Phase 1-3 testing
- [ ] Performance optimization (large diagrams, image loading)
- [ ] Offline mode improvements (sync queue, conflict resolution)
- [ ] UI/UX refinements based on user feedback
- [ ] App Store / Play Store submission preparation

### Jan (Backend)
- [ ] Bug fixes from Phase 1-3 testing
- [ ] API performance and error handling improvements
- [ ] Rate limiting and security hardening

### Ondrej (Content)
- [ ] Review and update guides based on user feedback
- [ ] Additional guide content for launch

### Everyone
- [ ] End-to-end test across all phases
- [ ] Final review before public release
