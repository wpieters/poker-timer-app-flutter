# Poker Timer

A timer app for managing blind increases in private home poker games.

We've been playing a monthly home poker game for over a decade, and we have a set timer for increasing blinds.
This helps us keep the game going between all the socialising, and makes for a higher stakes, more exciting
game as we reach the end of the evening.

I've been wanting to learn Flutter for a while, for no other reason than to see what the fuss is about.
I figured this could be a nice project for it.

## How It Works

The app provides a simple and intuitive interface for managing poker tournament blind levels:

- **Predefined Blind Intervals**: The app uses a sequence of timed intervals (45, 45, 30, 30, 15, 15 minutes) to structure your poker tournament. These can be changed in Settings.
- **Color-Coded Blind Levels**: Each blind level is represented by a color-coded circle, making it easy to track progress. You can update these to match your chip colors.
- **Start/Pause/Resume**: Control the timer with simple buttons to start, pause, and resume as needed.
- **Auto-Doubling Blinds**: When predefined chip levels are exhausted, the app automatically doubles blind values to ensure the tournament progresses properly.
- **Sound Notifications**: Audio alerts play when a blind level ends, ensuring players don't miss blind increases. You can adjust the volume in Settings.

## Features

- Cross-platform compatibility (iOS, Android, and Web)
- Intuitive user interface
- Audio notifications for blind level changes
- Ability to pause and resume the timer without losing track of remaining time
- Automatic blind doubling for longer tournaments

## Live Demo

You can try the web version of the app here:
[Poker Timer Web App](https://trunk.d1dmczzvq7uczm.amplifyapp.com)

## Getting Started

This project is built with Flutter. To run it locally:

1. Ensure you have Flutter installed (see [Flutter installation guide](https://docs.flutter.dev/get-started/install))
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run` to start the app on your connected device or emulator

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Development

This project started as a learning exercise during a Udemy Flutter course I was taking. It was later picked up again to further experiment with Windsurf, an agentic IDE that uses AI to assist with development tasks.

## Acknowledgements

- Voice clips used in the app were generated using [Motion Array](https://motionarray.com/)

## Screen awake and timer recovery

The PWA is designed to stay visible on the table. It requests a **screen** wake
lock while open, including while paused or editing settings. The status above the
timer confirms whether the lock was acquired. Returning from another app requests
a fresh lock; a refusal or unexpected release shows a retry button.

- Serve over HTTPS (localhost also works).
- For an installed iPhone/iPad Home Screen app, use **iOS/iPadOS 18.4 or newer**.
  Apple fixed a Home Screen wake-lock bug in that release:
  [Safari 18.4 release notes](https://webkit.org/blog/16574/webkit-features-in-safari-18-4/).
  On older devices, try opening the app in Safari instead of the installed PWA.
- Battery saver and OS/browser policies can refuse a wake lock. The app cannot
  prevent a manual screen lock or promise an alert while hidden.
- Start/Resume activates sound from the button gesture. If audio is blocked, or
  a game is restored after reloading, use **Enable sound**.
- The tournament is saved locally with an absolute deadline. Returning or
  reloading catches up all elapsed levels without restarting their full duration.
  A catch-up emits one alert, rather than a burst for every missed level.
- Pause freezes the remaining duration; Reset clears the saved tournament.
  Interval/chip edits apply to the next tournament; volume changes apply immediately.

## Current development and web build

Validated with Flutter **3.47.7 / Dart 3.13.5**. The application dependency lockfile
is tracked for reproducible builds. Android build configuration follows this SDK's
AGP 9.1 / Gradle 9.3.1 template; iOS dependencies require iOS 13 or later.

```sh
flutter pub get
flutter analyze
flutter test
scripts/build-web.sh
```

The build script needs Node.js as well as Flutter. It finds Flutter on PATH, falls
back to `~/flutter/flutter/bin/flutter`, or accepts `FLUTTER_BIN=/path/to/flutter`.
Deploy the resulting `build/web` directory.

### CI/CD (AWS Amplify)

Hosting uses Amplify app `d1dmczzvq7uczm` in `us-east-1`, connected to this
GitHub repository through a push webhook. As checked on 2026-10-10:

- `trunk` automatically builds and deploys the production site.
- New branches matching `*` or `*/**` automatically get development deployments.
  Pushing `feat/update-flutter` should create a separate development deployment;
  merging it into `trunk` triggers production.
- There are no GitHub Actions workflows. Pull request previews are disabled;
  feature branch deployments provide the preview environment instead.
- The root `amplify.yml` overrides the old console build specification, which
  installed Flutter 3.19.3. It pins Flutter 3.47.7, selects Node 22, runs analysis
  and tests, and builds the offline PWA through `scripts/build-web.sh`.

Check the first feature branch deployment in Amplify before merging. Local tests
do not verify the hosted build image or its available resources. Changes to
Amplify branch settings can alter these push triggers.

Flutter no longer supplies its previous offline cache. **Use this build script for
PWA releases**, rather than plain `flutter build web`: it bundles the renderer
locally and generates a cache containing the app, fonts, and sounds. The worker
keeps the previous `flutter_service_worker.js` URL so installed versions can
upgrade. Each build has a content-derived cache version; updates activate after
all existing app windows close. Reopen while online to receive an update, and
allow the first download to finish before using the app offline. A service worker
only provides offline loading here; it does not run the timer in the background.

Browser regression check (Playwright is a test-only dependency):

```sh
npm install --prefix /tmp/poker-timer-browser playwright@1.51.1
/tmp/poker-timer-browser/node_modules/.bin/playwright install chromium
python3 -m http.server 8765 --directory build/web
# In another terminal:
PLAYWRIGHT_MODULE=/tmp/poker-timer-browser/node_modules/playwright node scripts/browser-smoke.cjs
```

The browser test uses a fake clock and wake-lock API to exercise releases,
refusals, return-to-app recovery, audio delivery, and an offline reload. Physical
phone checks are still needed: set Auto-Lock to a short interval, open the PWA,
confirm the awake status, leave it untouched past Auto-Lock, then switch apps and
return. Test both normal mode and battery saver on iOS 18.4+ and Android Chrome.
