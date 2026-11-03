# City Rush: Double Dash

An original local two-player endless runner built with Flutter. Each runner has an independent split-screen track, score, coins, and controls. The illustrated city and characters are drawn in Flutter; the game uses no Subway Surfers assets or branding.

## Play

Open `flutter_app` in a terminal and run `flutter run`. In portrait, the tracks stack vertically; in landscape, they sit side by side. Swipe left or right to change lanes, swipe up to jump, and swipe down to slide. Players control the runner in their own half. Avoid barriers, slide under overhead obstacles, and collect coins. Either runner can continue after the other wipes out.

## Build Android APK

From `flutter_app`, run:

```sh
flutter build apk --release
```

The APK is written to `flutter_app/build/app/outputs/flutter-apk/app-release.apk`.