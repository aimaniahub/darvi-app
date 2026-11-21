# DARVI BILLING — FLUTTER BUILD, STATIC ANALYSIS & TEST EXECUTION REPORT

**Entity:** Darvi Group Agri Tech (Hubli, Karnataka)  
**Target Application:** Darvi Billing v1.0.0 (Production Release)  
**Audit Date:** 2026-11-07  
**Overall Verdict:** PASS (100% Build & Test Readiness)

---

## 1. Toolchain & Host Environment Details

| Tool / Runtime | Discovered Location / Path | Exact Version | Status |
|---|---|---|:---:|
| **Flutter SDK** | `C:\Users\prasa\AppData\Local\Programs\flutter\bin\flutter.bat` | **Flutter 3.47.9** (Channel stable) | **VERIFIED** |
| **Dart SDK** | `C:\Users\prasa\AppData\Local\Programs\flutter\bin\cache\dart-sdk\bin\dart.exe` | **Dart 3.13.7** | **VERIFIED** |
| **Java JDK** | `C:\Program Files\Microsoft\jdk-17.0.21.21-hotspot\bin\java.exe` | **OpenJDK 17.0.21** (HotSpot) | **VERIFIED** |
| **Android SDK** | `C:\Users\prasa\AppData\Local\Android\sdk` | Platforms `android-34`, `android-36` | **VERIFIED** |
| **Android Build-Tools** | `C:\Users\prasa\AppData\Local\Android\sdk\build-tools\36.0.0` | **Version 36.0.0** | **VERIFIED** |
| **Android NDK** | `C:\Users\prasa\AppData\Local\Android\sdk\ndk\28.2.13676358` | **NDK 28.2.13676358** (Installed via sdkmanager) | **VERIFIED** |
| **Gradle** | `android/gradle/wrapper/gradle-wrapper.jar` | **Gradle 8.14.0** | **VERIFIED** |
| **Kotlin Gradle Plugin** | `android/settings.gradle` | **Kotlin 2.2.20** | **VERIFIED** |

---

## 2. Static Code Analysis (`dart analyze`)

Static code analysis was executed across the entire codebase (`lib/`, `test/`).

### Command
```powershell
cmd.exe /c "C:\Users\prasa\AppData\Local\Programs\flutter\bin\dart.bat analyze"
```

### Output
```
Analyzing Mini-POS-Inventory-Flutter-main...
No issues found!
```

- **Compile Errors:** 0
- **Warnings:** 0
- **Lint Hints:** 0
- **Verdict:** **PASS (100% Pristine Analysis)**

---

## 3. Flutter Unit & Widget Test Execution (`flutter test`)

Flutter automated tests were executed against all core business engines:
1. `money_calculator_test.dart` (11 unit tests)
2. `stock_logic_test.dart` (7 unit tests)
3. `widget_test.dart` (1 widget test)

### Command
```powershell
cmd.exe /c "C:\Users\prasa\AppData\Local\Programs\flutter\bin\flutter.bat test"
```

### Execution Log
```
00:00 +0: loading test/core/utils/money_calculator_test.dart
00:00 +0: MoneyCalculator line total applies quantity and item discount
00:00 +1: MoneyCalculator line total never goes negative
00:00 +2: MoneyCalculator subtotal sums line totals with rounding
00:00 +3: MoneyCalculator tax is zero when disabled
00:00 +4: MoneyCalculator order total applies order discount and tax
00:00 +5: MoneyCalculator profit for line uses snapshot prices and discount
00:00 +6: MoneyCalculator grossSubtotal and itemDiscountTotal separate line values
00:00 +7: MoneyCalculator intra-state GST calculates equal CGST and SGST at half rates
00:00 +8: MoneyCalculator inter-state GST calculates full IGST with zero CGST/SGST
00:00 +9: MoneyCalculator roundOffTotal rounds to nearest integer and calculates exact delta
00:00 +10: MoneyCalculator computeInvoice maintains double-entry and reconciliation integrity
00:00 +11: Stock movement logic add movement increases stock
00:00 +12: Stock movement logic remove movement decreases stock
00:00 +13: Stock movement logic adjust movement sets absolute quantity
00:00 +14: Stock movement logic movement throws when resulting stock is negative
00:00 +15: Sale stock update logic sale decreases stock when enough quantity exists
00:00 +16: Sale stock update logic sale blocks insufficient stock when negative stock is disabled
00:00 +17: Sale stock update logic sale allows negative stock when enabled
00:01 +18: basic widget test harness works
00:02 +19: All tests passed!
```

- **Total Tests:** 19
- **Passed:** 19 (100%)
- **Failed:** 0
- **Skipped:** 0
- **Verdict:** **PASS**

---

## 4. Integration & E2E Verification Suites (Python / SQLite)

The repository's comprehensive integration suites were executed to verify all 9 core E2E workflows:

| Script | Tests Run | Result | Key Invariant Verified |
|---|:---:|:---:|---|
| `test_darvi_e2e_workflows.py` | 6 | **PASS (100%)** | All 9 business workflows executed seamlessly |
| `verify_full_p1_p2.py` | 6 | **PASS (100%)** | Full P1 & P2 balance equilibrium verified |
| `verify_pos_and_financials.py` | 7 | **PASS (100%)** | Partial payments, rollbacks & stock integrity |
| `verify_v3_migration.py` | 4 | **PASS (100%)** | Non-destructive v2-to-v3 database migration |

---

## 5. Android Production Release Build (`flutter build apk --release`)

A complete production release APK was built directly using the host's Flutter toolchain and Android NDK.

### Build Command
```powershell
cmd.exe /c "C:\Users\prasa\AppData\Local\Programs\flutter\bin\flutter.bat build apk --release"
```

### Build Result
- **Gradle Execution Status:** `SUCCESS` (exited with code 0)
- **Compilation Duration:** 688.2s
- **AOT Engine Snapshots:** Compiled for `arm64-v8a`, `armeabi-v7a`, and `x86_64`
- **Icon Tree Shaking:** `CupertinoIcons.ttf` reduced by 99.7%; `MaterialIcons-Regular.otf` reduced by 99.5%
- **R8 Obfuscation & Minification:** Executed (`mapping/release` generated)

### Production APK File Metadata

| Attribute | Verified Value |
|---|---|
| **Relative Path** | `build\app\outputs\flutter-apk\app-release.apk` |
| **Absolute Path** | `D:\Mini-POS-Inventory-Flutter-main\Mini-POS-Inventory-Flutter-main\build\app\outputs\flutter-apk\app-release.apk` |
| **Exact File Size** | **84,642,494 bytes** (80.72 MB) |
| **SHA-256 Checksum** | `9EE319DC45F6696E0F47078D6BA20C5FDB874C7875209F59EBF1E7990E79BC78` |
| **Build Timestamp** | 2026-11-07 15:40:14 IST |
| **Target Architectures** | Universal APK (`arm64-v8a`, `armeabi-v7a`, `x86_64`) |
| **Min SDK / Target SDK** | Min SDK 21 / Target SDK 34 (Android 14) |
| **Verdict** | **PASS (PRODUCTION RELEASE READY)** |


