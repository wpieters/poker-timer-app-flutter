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
