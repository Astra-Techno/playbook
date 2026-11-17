# Maestro UI Tests for KoCourt

Maestro tests simulate real humans using the installed APK on an Android emulator. No source code needed — just the APK.

## Setup (Windows)

1. **Install Maestro:**
   ```bash
   # PowerShell (run as admin)
   iwr -useb "https://get.maestro.mobile.dev" | iex
   ```

2. **Start Android Emulator:**
   - Open Android Studio -> Virtual Device Manager -> Start an emulator
   - Or via command line: `emulator -avd Pixel_7_API_34`

3. **Install the APK:**
   ```bash
   adb install public_html/downloads/kocourt-player.apk
   ```

## Run Tests

```bash
# Single flow
maestro test maestro/player-discovery.yaml

# Full player journey
maestro test maestro/player-full-journey.yaml

# All flows
maestro test maestro/

# Record a video
maestro record maestro/player-full-journey.yaml
```

## Available Flows

| Flow | What it tests |
|------|--------------|
| `player-discovery.yaml` | Browse venues, navigate tabs |
| `player-login.yaml` | Login with demo OTP |
| `player-booking.yaml` | View court details, try booking |
| `player-full-journey.yaml` | Complete user session (login -> browse -> book) |

## Screenshots
Maestro saves screenshots to `~/.maestro/tests/` after each run.

## Tips
- Use `maestro studio` to interactively build new flows by tapping on the emulator
- Use `maestro record` to generate a video of the test run
- Flows use `optional: true` on most taps so they don't fail if UI changes slightly
