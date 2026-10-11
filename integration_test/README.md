# Native local pilot

`native_pilot_test.dart` exercises production native credential storage, Argon2,
SQLite persistence, and the Node API across separate Windows app processes.

Run `npm.cmd run test:native-pilot` from the sibling `jce_backend` repository after
setting `JCE_FLUTTER_EXECUTABLE` to your Flutter executable. The backend owns the
disposable PostgreSQL/API fixture, supplies process-only test inputs, runs prepare,
resume and cleanup, and verifies exactly one server sale/payment. Running the Dart
entry point directly without its fixture fails deliberately.

See `jce_backend/docs/local_pilot_acceptance.md` for prerequisites, output artifacts,
scope, and the remaining physical-device acceptance checklist. This check is
Windows-only; it does not approve native production or cover Android, OS reboot,
physical WAN loss, checkout UI, or branch hardware.
