# 🧠 MigraineLog

A personal migraine tracking app with a mobile-first interface, built to help you understand your patterns, triggers, and medication use over time.

![MigraineLog Dashboard](https://img.shields.io/badge/status-active-brightgreen) ![Ruby](https://img.shields.io/badge/backend-Ruby%20%2B%20WEBrick-CC342D) ![SQLite](https://img.shields.io/badge/database-SQLite3-003B57) ![Zero dependencies](https://img.shields.io/badge/frontend-zero%20dependencies-blueviolet) ![Deploy on Railway](https://img.shields.io/badge/deploy-Railway-6466F1)

---

## Overview

MigraineLog is a lightweight, self-hosted web app for tracking migraine episodes. It runs entirely from a single Ruby file and a single HTML file — no build tools, no package manager, no framework. Your data stays yours.

**Key characteristics:**

- **Mobile-native UI** — designed first for iPhone and Android, works equally well on desktop
- **No frontend framework** — pure vanilla JavaScript with a custom 20-line state engine; zero CDN dependencies
- **Single-file backend** — one Ruby script, SQLite database, no ORM
- **Self-hostable in minutes** — run locally on any Mac/Linux machine or deploy to the cloud for free

---

## Features

### Tracking
- Log migraine episodes with date, start time, and duration
- Rate pain severity on a 1–5 scale (Mild → Unbearable)
- Select pain location (left temple, forehead, behind eyes, etc.)
- Choose from 14 common triggers (Stress, Poor Sleep, Alcohol, Caffeine, etc.)
- Choose from 8 common symptoms (Nausea, Visual aura, Light sensitivity, etc.)
- Log one or more medications with name, dose, and time taken
- Add free-text notes per episode

### Dashboard
- Monthly episode count with last-month comparison
- Average severity and duration stats
- Days since last migraine with traffic-light indicator
- Mini calendar showing migraine days at a glance
- Weekly frequency bar chart
- Top 5 triggers across recent episodes

### History
- Full chronological log grouped by month
- Search by notes, triggers, medications, or location
- Filter by severity level

### Analytics
- 12-week activity heatmap
- Episode frequency by day of week
- Episode frequency by hour of day
- Complete trigger breakdown with proportional bars
- Auto-generated insights (peak day, peak hour, most common trigger)

### Medications
- Summary card per medication showing usage count, common dose, and average severity when taken
- Last used date per medication

---

## Tech Stack

| Layer | Technology |
|---|---|
| Frontend | Vanilla JavaScript (no framework), HTML5, CSS3 |
| Backend | Ruby + WEBrick (built-in HTTP server) |
| Database | SQLite3 |
| Deployment | Railway (cloud) or any machine with Ruby |
| API | REST/JSON over HTTP |

**Why no framework?** The app was intentionally built with zero external frontend dependencies so it works offline, loads instantly, and has no CDN failure risk. The entire frontend is a single HTML file you can open directly.

---

## Project Structure

```
migrainelog/
├── migraine-tracker.html   # Entire frontend (HTML + CSS + JS in one file)
├── server.rb               # REST API server (Ruby WEBrick + SQLite3)
├── Gemfile                 # Ruby gem dependencies
├── Gemfile.lock            # Locked versions (Linux x86_64 for Railway)
├── Procfile                # Railway/Heroku process declaration
├── nixpacks.toml           # Railway build config (SQLite3 native deps)
├── start.command           # Double-click launcher for macOS
└── migraine.db             # SQLite database (created on first run, gitignored)
```

---

## Getting Started

### Prerequisites

- Ruby 2.6+ (macOS ships with it; check with `ruby -v`)
- Bundler (`gem install bundler`)
- Xcode Command Line Tools on macOS (`xcode-select --install`)

### Run Locally

```bash
git clone https://github.com/lmontfajon/migrainelog.git
cd migrainelog
bundle install
ruby server.rb
```

Then open **http://localhost:4567** in your browser.

**macOS shortcut:** Double-click `start.command` in Finder to start the server without opening a terminal.

### Access from Your Phone (same Wi-Fi)

1. Start the server on your Mac
2. Find your Mac's local IP: **System Preferences → Network** (e.g. `192.168.1.42`)
3. Open `http://192.168.1.42:4567` in Safari on your phone
4. Tap **Share → Add to Home Screen** to install it as a native-feeling app

---

## Deploying to the Cloud (Railway)

MigraineLog is pre-configured for one-click deployment on [Railway](https://railway.app).

1. Fork this repository
2. Create a free account at [railway.app](https://railway.app)
3. New Project → Deploy from GitHub repo → select your fork
4. Railway auto-detects the `Procfile` and builds with `nixpacks.toml`
5. Your app is live at a permanent public URL in ~2 minutes

> **Note on data persistence:** Railway's free tier does not provide persistent disk storage. The SQLite database resets on each redeploy. For permanent storage, consider adding a [Railway Postgres](https://docs.railway.app/databases/postgresql) database or self-hosting on a VPS.

---

## API Reference

The backend exposes a simple REST API at `/api/entries`.

### Endpoints

| Method | Path | Description |
|---|---|---|
| `GET` | `/api/entries` | List all entries (sorted by date desc) |
| `POST` | `/api/entries` | Create a new entry |
| `GET` | `/api/entries/:id` | Get a single entry |
| `PUT` | `/api/entries/:id` | Update an entry |
| `DELETE` | `/api/entries/:id` | Delete an entry |
| `GET` | `/api/health` | Health check + entry count |

### Entry Schema

```json
{
  "id": "a1b2c3d",
  "date": "2026-02-23T19:00:00.000Z",
  "severity": 2,
  "duration": 4.0,
  "location": "Left temple",
  "notes": "Stressful work day",
  "triggers": ["Stress"],
  "symptoms": ["Fatigue", "Nausea"],
  "medications": [
    {
      "id": "x1y2z3",
      "name": "Sumatriptan",
      "dose": "100mg",
      "time": "19:30"
    }
  ]
}
```

### Severity Scale

| Value | Label |
|---|---|
| 1 | Mild |
| 2 | Moderate |
| 3 | Intense |
| 4 | Severe |
| 5 | Unbearable |

### Example: Create an Entry

```bash
curl -X POST https://your-app.up.railway.app/api/entries \
  -H "Content-Type: application/json" \
  -d '{
    "date": "2026-03-01T08:00:00.000Z",
    "severity": 3,
    "duration": 6,
    "location": "Left temple",
    "triggers": ["Poor Sleep", "Stress"],
    "symptoms": ["Nausea"],
    "medications": [{"name": "Sumatriptan", "dose": "100mg", "time": "08:15"}],
    "notes": "Woke up with it"
  }'
```

---

## Architecture Notes

### Frontend State Engine

The app uses a minimal custom state engine (~20 lines) instead of React or Vue:

```js
let _state = {};
let _listeners = [];

function getState() { return _state; }
function setState(patch) {
  _state = typeof patch === 'function' ? patch(_state) : { ..._state, ...patch };
  _listeners.forEach(fn => fn());
}
function subscribe(fn) {
  _listeners.push(fn);
  return () => { _listeners = _listeners.filter(f => f !== fn); };
}
```

Every `setState` call re-renders the affected parts of the UI via DOM diffing.

### Backend Routing

The WEBrick servlet is mounted at `'/'` (not `'/api'`) to prevent WEBrick from stripping the path prefix before route matching. All routes are matched against the full path using regex.

### Encoding Fix

WEBrick delivers `req.path` as `ASCII-8BIT`. SQLite3 stores IDs as `UTF-8`. On Ruby 2.6, parameterized queries silently fail to match ASCII-8BIT against UTF-8 values. All ID lookups force UTF-8 encoding before the query:

```ruby
id = id.to_s.encode('UTF-8', invalid: :replace, undef: :replace)
```

---

## Mobile UI Design

The interface is built mobile-first with native-feeling interactions:

- **Bottom tab bar** — Home, History, Analytics, Meds
- **Bottom sheet modals** — slide up from the bottom, native-app style
- **FAB button** — circular + button for quick logging
- **Safe area insets** — respects iPhone notch and home bar (`env(safe-area-inset-*)`)
- **iOS zoom prevention** — all form inputs use `font-size: 16px`
- **Touch feedback** — `-webkit-tap-highlight-color: transparent` + `:active` scale transforms
- **Dynamic viewport** — uses `100dvh` for correct height on mobile browsers
- **Installable** — `apple-mobile-web-app-capable` meta tag enables Add to Home Screen

---

## Contributing

Contributions are welcome. Some ideas for what could be improved:

- Persistent cloud storage (PostgreSQL adapter for the backend)
- Data export to CSV or PDF
- Weekly/monthly email or push notification summaries
- Offline support via Service Worker
- Customisable trigger and symptom lists
- Dark/light theme toggle

To contribute:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/my-improvement`)
3. Make your changes
4. Open a pull request with a clear description

---

## License

MIT License — see [LICENSE](LICENSE) for details.

---

## Disclaimer

MigraineLog is a personal tracking tool and is **not a medical device**. It is not intended to diagnose, treat, or replace professional medical advice. Always consult a qualified healthcare provider regarding your health.

---

*Built with care for anyone who knows what it's like to lose a day to a migraine.*
