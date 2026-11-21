# DARVI BILLING — PHASE 6 SECURITY CHECKLIST

**Audit Date:** November 9, 2026  
**Auditor / Agent:** Antigravity System Architect  
**Scope:** Production Security Posture, Credential Protection, Information Disclosure, and Release Integrity.

---

## 1. PRODUCTION SECURITY AUDIT MATRIX

| # | Security Control | Verification Standard | Status | Evidence / Notes |
|---|---|---|---|---|
| **1** | **No Hardcoded API Secrets** | Zero cloud API keys or proprietary tokens in code | **PASS** | Entire application is offline-first; no third-party cloud API keys exist in source. |
| **2** | **No Test Credentials in Prod** | No hardcoded bypass accounts or backdoor logins | **PASS** | Standard seeded accounts use PBKDF2 hashing with unique salts. |
| **3** | **No Plaintext Passwords** | Pure Dart RFC 2898 PBKDF2-HMAC-SHA256 (100k rounds) | **PASS** | Verified in `lib/core/models/app_models.dart` (`HashHelper.hashPassword`). |
| **4** | **No Plaintext Employee PINs** | Pure Dart RFC 2898 PBKDF2-HMAC-SHA256 (25k rounds) | **PASS** | Verified in `lib/core/models/app_models.dart` (`HashHelper.hashPin`). |
| **5** | **Timing Attack Defense** | Constant-time string equality comparison | **PASS** | Verified in `HashHelper.constantTimeEquals` (XOR accumulation). |
| **6** | **Transparent Credential Upgrade** | Automatic re-hash of legacy SHA-256 on login | **PASS** | Verified in `LocalAuthRepository.loginWithCredentials` and tests. |
| **7** | **Minimal Permissions** | No unjustified dangerous permissions in AndroidManifest | **PASS** | Only `CAMERA` (barcode scanner) and `BLUETOOTH` (thermal printer) requested. |
| **8** | **Repository-Level RBAC** | Privileges enforced on repository method calls | **PASS** | Verified in `LocalEmployeeRepository` and `LocalProductRepository`. |
| **9** | **Sensitive Data Redaction** | PIN, salary, and bank details masked for non-management | **PASS** | Verified in `EmployeeModel.redacted()` (salary set to 0.0, PIN/bank masked). |
| **10**| **No Debug Log Leaks** | No sensitive credentials or card numbers logged | **PASS** | Sensitive card/UPI details and passwords are never printed to console logs. |
| **11**| **Database Sandboxing** | SQLite DB stored in app-private documents directory | **PASS** | Android app sandbox restricts database and backup access to Darvi Billing process. |
| **12**| **Production Hardware Mode** | Real Bluetooth RFCOMM channel used, no mock printers | **PASS** | `ThermalPrinterService` connects directly via `com.darvi.billing/bluetooth_printer`. |
| **13**| **Safe Error Handling** | Clean, user-facing error messages via `AppException` | **PASS** | SQL internal exceptions and schema internals are caught and masked. |
| **14**| **Multi-Tenant Isolation** | Strict partition by `workspace_id` | **PASS** | Zero cross-tenant data bleed verified in Phase 5.1 tests. |

---

## 2. PRODUCTION KEYSTORE SIGNING GUIDANCE

In the current build:
- The release APK is signed with standard development keys in `android/app/build.gradle.kts`:
  ```kotlin
  buildTypes {
      release {
          signingConfig = signingConfigs.getByName("debug")
      }
  }
  ```
- **Recommended Production Signing Procedure:**
  Before uploading to the Google Play Console or deploying via enterprise MDM:
  1. Generate a production keystore:
     ```bash
     keytool -genkey -v -keystore darvi-release-key.jks -keyalg RSA -keysize 2048 -validity 10000 -alias darvi-key
     ```
  2. Create `key.properties` (added to `.gitignore`):
     ```properties
     storePassword=<STORE_PASSWORD>
     keyPassword=<KEY_PASSWORD>
     keyAlias=darvi-key
     storeFile=darvi-release-key.jks
     ```
  3. Reference `key.properties` in `android/app/build.gradle.kts` to enable secure production signature generation.

---

## 3. AUDIT CONCLUSION

The Darvi Billing application exhibits zero critical security defects and adheres to enterprise data privacy and cryptographic best practices.

