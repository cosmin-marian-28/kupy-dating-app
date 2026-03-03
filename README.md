# Kupy — Dating App

A Flutter dating app where users complete missions to unlock conversations. Built with Supabase for real-time backend and Firebase for push notifications. Features a custom hand-drawn UI system, 4 dating modes, in-app purchases, and face verification.

> Currently under App Store review and internal testing 14days period for Google Play launch. Full source is private — this repo contains selected code samples and screenshots as a portfolio preview.

## Preview

<p align="center">
  <img src="screenshots/home_page_not _verified.PNG" width="200" />
  <img src="screenshots/profile_page.PNG" width="200" />
  <img src="screenshots/chat_page.PNG" width="200" />
</p>

<p align="center">
  <img src="screenshots/filters.PNG" width="200" />
  <img src="screenshots/subscription.PNG" width="200" />
</p>

## Tech Stack

- **Flutter** (Dart) — Cross-platform iOS & Android
- **Supabase** — Auth (email OTP), PostgreSQL database, Realtime subscriptions, Storage
- **Firebase** — Cloud Messaging (push notifications), background message handling
- **In-App Purchases** — Consumables + auto-renewable subscriptions (App Store & Google Play)
- **Geolocator** — Location-based user filtering with Haversine distance
- **Camera** — Front-facing selfie capture for face verification
- **Audioplayers** — Match sound effects
- **Klipy** — GIF/sticker picker in chat

## How It Works

Users don't just swipe — they complete missions to prove interest. Each user pair gets assigned a mission (e.g. "send 50 likes over 5 days"). When both sides complete their mission, chat unlocks. This creates real engagement instead of empty matches.

### Dating Modes

| Mode | How it works |
|------|-------------|
| **Kupy** (default) | Tiered missions with escalating difficulty — from 30 likes up to 1000+ over multiple days. Supports daily targets and consecutive-day streaks. |
| **Speed Date** | Fixed 100-heart threshold per pair. No multi-day missions — just send enough hearts and chat opens. |
| **Surprise Date** | Fixed 30-heart threshold. Gender filters are disabled so you meet people you wouldn't normally see. |
| **Drink Buddy** | Fixed 50-heart threshold, party mode. Gender filters off — find someone to grab a drink with. |

Users can switch modes from the home map. Each mode tracks progress independently with its own pair tables.

### KupyHearts & Monetization

- **Hearts** — The basic currency. Earned via daily check-ins or purchased. Spent by tapping on users.
- **KupyHearts** — Premium power-ups (consumable IAP). Instantly complete a mission for a specific user.
- **Subscriptions** — Two tiers:
  - *Cracked Cupidon* — 1 KupyHeart + 5,000 hearts on purchase
  - *Cupidon's Blessing* — 5 KupyHearts + unlimited hearts

### Face Verification

Users verify their identity by taking a live selfie that's compared against their profile photo using DeepFace (ArcFace model + RetinaFace detector). The verification API runs on Hugging Face Spaces — images are processed in memory and never stored.

## Architecture

```
lib/
├── main.dart                  # App entry, Firebase + Supabase init
├── config/                    # Supabase credentials
├── l10n/                      # Localization (EN, RO, DE, IT)
├── pages/                     # All screens
│   ├── home_page.dart         # Interactive user map with mode switching
│   ├── chat_page.dart         # Conversation list
│   ├── chat_thread_page.dart  # Real-time messaging (Supabase Realtime)
│   ├── profile_page.dart      # User profile & settings
│   ├── face_verification_page.dart
│   ├── signup_page.dart       # Email OTP auth
│   └── ...
├── services/
│   ├── mission_service.dart   # Mission logic, heart spending, progress tracking
│   ├── chat_service.dart      # Message CRUD + Realtime subscriptions
│   ├── subscription_service.dart  # IAP fulfillment, blocking, KupyHearts
│   ├── iap_service.dart       # App Store / Google Play purchase handling
│   ├── location_service.dart  # GPS + Haversine filtering
│   ├── push_notification_service.dart
│   ├── klipy_service.dart     # GIF/sticker integration
│   └── sound_service.dart     # Match sound effects
├── painters/                  # Custom hand-drawn UI (wobbly pills, borders)
├── theme/                     # Dark/light mode, drink buddy theme
└── widgets/                   # Bottom bar, hearts display, purchase modal

supabase/
├── functions/                 # Edge Functions (Deno)
│   ├── push-notification/     # FCM push delivery
│   ├── send-otp / verify-otp/ # Email OTP auth flow
│   ├── verify-face/           # Face verification proxy
│   ├── apple-iap-webhook/     # App Store server notifications
│   └── engagement-nudge/      # Re-engagement notifications
└── migrations/                # PostgreSQL schema + RPC functions

hf-face-verify/                # Hugging Face Space (Docker)
└── app.py                     # FastAPI — DeepFace ArcFace verification
```

## Key Implementation Details

- **Custom UI system** — All buttons, cards, and navigation use hand-drawn wobbly pill shapes rendered with `CustomPainter`. No standard Material widgets for the main UI.
- **Mission engine** — 3 difficulty categories with 4 tiers each. Missions can require total likes, daily targets, or consecutive-day streaks. Switching categories has a cooldown enforced server-side.
- **Real-time chat** — Messages delivered via Supabase Realtime (Postgres changes). Push notifications sent through a Supabase Edge Function calling FCM.
- **Map-based home screen** — Users appear as circles on a pannable/zoomable grid. Tap to send hearts, long-press for details. Priority sorting ensures in-progress missions and admirers always appear.
- **Atomic operations** — Heart spending, mission completion, and match detection all happen in PostgreSQL RPC functions to prevent race conditions.

## Code Samples

Selected source files are in the [`code/`](code/) folder:

| File | What it shows |
|------|--------------|
| `mission_service.dart` | Mission definitions, heart spending, progress tracking |
| `chat_service.dart` | Supabase Realtime message subscriptions |
| `iap_service.dart` | In-app purchase flow (consumables + subscriptions) |
| `subscription_service.dart` | KupyHeart delivery, blocking, admirer loading |
| `chat_thread_page.dart` | Real-time chat UI |
| `pill_painter.dart` | Hand-drawn wobbly shape rendering |
| `app_theme.dart` | Dark/light + drink buddy theme system |

