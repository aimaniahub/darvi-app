# DARVI BILLING — PHASE 6 BUILD & CODE QUALITY REPORT

**Report Date:** November 9, 2026  
**Auditor / Agent:** Antigravity System Architect  
**Platform / Toolchain:** Flutter 3.47.9 (channel stable) / Dart 3.13.7 / DevTools 2.60.0  
**Host OS:** Microsoft Windows 11 Pro [Version 10.0.26200]  
**Application ID:** `com.example.mini_pos_inventory`  
**Application Name:** Darvi Billing  
**Version / Build:** `1.0.0+1` (VersionName: 1.0.0, VersionCode: 1)  

---

## 1. BUILD TOOLCHAIN & ENVIRONMENT AUDIT

### 1.1 Flutter & Dart SDK Compatibility
- **Flutter SDK:** Version `3.47.9` (channel `stable`, git revision `c197ca5199`).
- **Dart SDK:** Version `3.13.7`.
- **Target SDK Range:** `>=3.3.0 <4.0.0`.
- **JDK Compatibility:** Java 17 (Java HotSpot 64-Bit Server VM).

### 1.2 Dependencies & Version Constraints (`pubspec.yaml`)
- **State Management & Routing:** `flutter_bloc: ^9.1.1`, `equatable: ^2.0.7`, `go_router: ^17.1.0`.
- **Database & Persistence:** `drift: ^2.21.0`, `sqlite3_flutter_libs: ^0.5.24`, `path_provider: ^2.1.4`, `path: ^1.9.0`.
- **Hardware, Media & Barcode:** `mobile_scanner: ^6.0.2`, `image_picker: ^1.2.1`, `pdf: ^3.11.1`, `printing: ^5.13.4`, `share_plus: ^10.1.2`.
- **UI & Iconography:** `tabler_icons_plus: ^3.50.0`, `fl_chart: ^0.69.2`, `cupertino_icons: ^1.0.8`.
- **Data & Crypto:** `intl: ^0.20.2`, `csv: ^6.0.0`, `crypto: ^3.0.3`, `uuid: ^4.5.1`.
- **Development Tooling:** `flutter_lints: ^6.0.0`, `drift_dev: ^2.21.2`, `build_runner: ^2.4.13`, `flutter_test`.

### 1.3 Android Gradle Configuration (`android/app/build.gradle.kts`)
- **Namespace:** `com.example.mini_pos_inventory`
- **Application ID:** `com.example.mini_pos_inventory`
- **Compile SDK:** Evaluated dynamically via `flutter.compileSdkVersion` (API 35).
- **Min SDK:** Evaluated dynamically via `flutter.minSdkVersion` (API 21 - Android 5.0 Lollipop).
- **Target SDK:** Evaluated dynamically via `flutter.targetSdkVersion` (API 34/35).
- **Java Compatibility:** `JavaVersion.VERSION_17` (Source and Target).
- **Kotlin JVM Target:** `17`.
- **Build Types:** Release configuration active with standard Flutter assembly pipeline.

### 1.4 Android Permissions (`android/app/src/main/AndroidManifest.xml`)
The application permissions have been audited and verified to be strictly minimal and justified:
1. `android.permission.CAMERA`: Used exclusively for the live POS barcode scanner and product/document photos.
2. `android.permission.BLUETOOTH` (maxSdkVersion=30): Legacy Bluetooth classic socket connection.
3. `android.permission.BLUETOOTH_ADMIN` (maxSdkVersion=30): Pairing management on older Android releases.
4. `android.permission.ACCESS_FINE_LOCATION` (maxSdkVersion=30): Required for Bluetooth discovery on Android 11 and lower.
5. `android.permission.BLUETOOTH_SCAN` (`usesPermissionFlags="neverForLocation"`): Explicitly tells Android 12+ that BT scanning is not used to derive geographic location.
6. `android.permission.BLUETOOTH_CONNECT`: Direct RFCOMM socket communication with SSEZNIK2POS 58mm thermal printer.

### 1.5 Asset Registration & Integrity
Verified that assets registered in `pubspec.yaml` exist on disk without dead references:
- `assets/darvi_logo.png` (126,803 bytes) — High-res corporate logo.
- `assets/darvi_icon.png` (20,114 bytes) — Application launcher mark.
- `assets/logo/darvi_logo_mark.png` (20,114 bytes) — Receipt and header badge.
- Font icon tree-shaking active during release build:
  - `CupertinoIcons.ttf` reduced by 99.7% (848 bytes).
  - `MaterialIcons-Regular.otf` reduced by 99.4% (10,012 bytes).
  - `tabler-icons-filled.ttf` reduced by 99.4% (1,352 bytes).
  - `tabler-icons.ttf` reduced by 97.5% (46,484 bytes).

---

## 2. BUILD COMMAND EXECUTION & RESULTS

Every required command was executed in the workspace root:

### 2.1 `flutter clean`
- **Command:** `flutter clean`
- **Exit Status:** `0` (Success)
- **Output:** Cleaned `build/`, `.dart_tool/`, and ephemeral platform artifacts in 774ms.

### 2.2 `dart analyze`
- **Command:** `dart analyze lib test`
- **Exit Status:** `0` (Success)
- **Output:**
  - **Errors:** 0
  - **Warnings:** 0
  - **Infos / Deprecations:** 85 (standard Flutter Material 3 deprecation recommendations for `.withValues()` and form `initialValue`). Zero blocking issues.

### 2.3 `flutter test`
- **Command:** `flutter test`
- **Exit Status:** `0` (Success)
- **Output:** **170 / 170 tests passing (100% pass rate)** in 40 seconds.
- **Coverage:** Comprehensive coverage across design system, POS cart, receipt ESC/POS engine, PDF invoice generation, Drift database migrations, financial ledgers, PBKDF2 cryptography, multi-tenant workspaces, and Phase 6 backup/restore and performance benchmarks.

### 2.4 `flutter build apk --release`
- **Command:** `flutter build apk --release`
- **Exit Status:** `0` (Success)
- **Build Duration:** 208.7 seconds
- **Output Artifact:** `build\app\outputs\flutter-apk\app-release.apk`
- **Artifact Size:** **95,005,606 bytes (90.6 MB)**
- **Timestamp:** November 9, 2026, 16:17:45 IST

### 2.5 `flutter build windows --release`
- **Command:** `flutter build windows --release`
- **Exit Status:** `1` (Blocked)
- **Reason:** Windows host OS policy requires Windows Developer Mode or elevated symlink privileges (`Building with plugins requires symlink support. Please enable Developer Mode in your system settings: start ms-settings:developers`).
- **Impact:** Does not affect Android release APK deployment.

---

## 3. AUDIT CONCLUSION

The codebase compiles cleanly into an optimized Android Release APK. All automated unit, repository, financial invariant, and database restoration tests pass with 100% fidelity.

