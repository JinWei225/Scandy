# ML Kit OCR bench

A measurement tool, not an app anyone uses. It runs Google ML Kit text
recognition over images pushed to an Android device and writes the detections
out as JSON, so the OCR half of the Scandy pipeline can be compared on-device
against Apple Vision on the Mac.

The results feed the `ocr-mlkit+*` arms of
`backend/bench/compare_pipelines.py`, and the captured text becomes half the
shared fixture in `frontend_flutter/test/fixtures/receipt_cases.json`.

## Running it

```bash
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk

# Let the app create its own directories first — one made over adb belongs to
# the shell user and the app cannot read it.
adb shell monkey -p com.scandy.mlkit_ocr_bench 1
adb shell am force-stop com.scandy.mlkit_ocr_bench

DIR=/sdcard/Android/data/com.scandy.mlkit_ocr_bench/files
adb push <your-images>/. "$DIR/in/"
adb shell rm -f "$DIR/out/DONE"
adb shell monkey -p com.scandy.mlkit_ocr_bench 1     # runs on launch
# wait for $DIR/out/DONE, then:
adb pull "$DIR/out/mlkit_ocr.json" ../../backend/bench/mlkit/mlkit_ocr.json
```

Then:

```bash
.venv/bin/python backend/bench/compare_pipelines.py \
  --arms ocr-mlkit+rules,ocr-mlkit+nuextract \
  --images-dir backend/test_img \
  --ground-truth backend/bench/ground_truth_screens.json \
  --mlkit-json backend/bench/mlkit/mlkit_ocr.json
```

## Notes

- Output is written after **each** script model, not once at the end. Only the
  Latin model ships with the app; the others come through Play Services, and
  loading the Chinese one takes the process down on the device this was built
  for. Saving as it goes means a completed pass is never lost to a later one.
- Input and output live in the app's own external files directory because that
  needs no runtime storage permission.
- Installing over adb can be refused with `INSTALL_FAILED_USER_RESTRICTED` on
  MIUI/HyperOS until *Developer options → Install via USB* is enabled.
