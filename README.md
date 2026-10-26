# Study Planner V3

An Arabic, right-to-left study planner built with Flutter and Dart. The app stores subjects, study tasks, and planning preferences on the device with `shared_preferences`.

## Features

- Add and edit subjects, set chapter counts and exam dates, and track completed units.
- Generate a daily study plan from each subject's remaining work, exam date, and available study time.
- Mark tasks complete, add quick tasks, review the schedule, and copy the plan.
- Persist the plan and settings locally on the device.
- Use the dashboard's theme button to switch between light and dark mode.
- See overdue (unfinished past) tasks on the dashboard and the nearest upcoming exam countdown.
- Long-press a task to delete it (with undo), see today's study-minutes progress, weekday names in the plan, and subject cards sorted by nearest exam.
- Full Arabic localization (date picker, dialogs) with RTL layout.

## Run on Android

This source bundle contains the Flutter app source and its Android build workflow, but not a generated Android platform directory. With Flutter 3 and an Android emulator or device available, generate a local Android runner from the project root:

```sh
flutter create --platforms=android --project-name study_planner --org com.study _app
cp pubspec.yaml _app/pubspec.yaml
cp -R lib/. _app/lib/
cd _app
flutter pub get
flutter run
```

To build a release APK, run `flutter build apk --release` from `_app`. The GitHub Actions workflow performs the same Android-project generation and APK build.
