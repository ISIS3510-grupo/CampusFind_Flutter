# Maestro E2E flows

End-to-end tests of the student app on an Android emulator, against the real
Firebase project and its deployed rules.

| Flow | Checks |
|---|---|
| `report_lost_item.yaml` | Lost report without photo or private detail |
| `report_with_private_detail.yaml` | Report plus its `lostReportPrivate` document |
| `lost_item_photo.yaml` | Camera photo uploaded to `lostReports/{id}.jpg` (Sensor) |
| `offline_queue.yaml` | Airplane mode: report queued, sent when back online (Context-aware) |

## Run

```
flutter build apk --debug && adb install -r build/app/outputs/flutter-apk/app-debug.apk
maestro test -e EMAIL=<student email> -e PASSWORD=<password> -e TITLE="Maestro $(date +%H%M%S)" .maestro
```

- Use a test student account. Never write the password in these files.
- Maestro needs Java 17 (`JAVA_HOME`).
- On the emulator, turn off stylus handwriting or Gboard catches the typed text:
  `adb shell settings put secure stylus_handwriting_enabled 0`
- The camera ids belong to the stock emulator camera; a real phone may differ.
