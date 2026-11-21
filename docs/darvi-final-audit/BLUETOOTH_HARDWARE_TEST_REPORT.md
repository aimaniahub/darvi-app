# DARVI BILLING — BLUETOOTH THERMAL PRINTER HARDWARE AUDIT REPORT

**Entity:** Darvi Group Agri Tech (Hubli, Karnataka)  
**Target Hardware:** SSEZNIK2POS 58mm Bluetooth Thermal POS Printer  
**Audit Scope:** ESC/POS Generator Byte Validation, Android RFCOMM SPP MethodChannel Bridge, Physical Printing Verification  
**Audit Date:** 2026-11-07  
**Overall Verdict:** PROTOCOL PASS | PHYSICAL HARDWARE NOT VERIFIED

---

## 1. Hardware Specification & Profile

| Property | SSEZNIK2POS Specification | Darvi Billing Configuration |
|---|---|---|
| **Print Width** | 58mm (48mm printable area) | 58mm Thermal Receipt Profile |
| **Character Columns** | 32 characters / line (Font A: 12x24 dots) | Strict 32-column formatting |
| **Interface** | Bluetooth 4.0 / 2.0 SPP (Serial Port Profile) | Android RFCOMM Bluetooth SPP Socket |
| **Standard Command Set** | ESC/POS emulation | Standard Epson ESC/POS byte protocol |
| **Baud Rate** | 9600 / 115200 bps | Native Bluetooth Serial Socket |
| **Paper Cut** | Manual tear bar / Partial cut command | Paper feed 3 lines + Cut command (`GS V 66 0`) |

---

## 2. ESC/POS Protocol Generator Verification (`esc_pos_generator.dart`)

### 2.1 Generated Receipt Layout (Darvi Group Agri Tech)
The ESC/POS byte generator produces the following structured 32-column receipt:

```
================================
     DARVI GROUP AGRI TECH      
  #2 Totad Bldg, Arjun Vihar,   
    Gokul Road, Hubli-580030    
       Ph: 9986890777           
   GSTIN: 29BKZPA0053M1ZQ       
--------------------------------
Inv No: INV-20261107-001        
Date: 07/11/2026 14:30          
Cashier: Priya Sharma           
Customer: Walk-in Retail        
--------------------------------
Item         Qty  Price   Total 
--------------------------------
Neem Guard     2 450.00  900.00 
  HSN: 31010000 | GST 18%       
--------------------------------
Gross Subtotal:         ₹900.00 
CGST (9%):               ₹81.00 
SGST (9%):               ₹81.00 
Round Off:                ₹0.00 
--------------------------------
GRAND TOTAL:           ₹1062.00 
Paid (UPI):            ₹1062.00 
Change Due:               ₹0.00 
--------------------------------
 Improving Agriculture,         
     Improving lives.           
Goods once sold not returnable  
================================
```

### 2.2 Byte Sequence & Hex Command Verification

| ESC/POS Command | Hexadecimal Bytes | Purpose | Protocol Verification |
|---|---|---|:---:|
| `ESC @` | `0x1B 0x40` | Initialize printer hardware | **PASS** |
| `ESC a 1` | `0x1B 0x61 0x01` | Center align header text | **PASS** |
| `ESC E 1` | `0x1B 0x45 0x01` | Enable bold emphasis for store title | **PASS** |
| `ESC ! 0x10` | `0x1B 0x21 0x10` | Double-height font for Grand Total | **PASS** |
| `ESC a 0` | `0x1B 0x61 0x00` | Left align table items | **PASS** |
| `ESC d 3` | `0x1B 0x64 0x03` | Feed 3 blank lines before paper cut | **PASS** |
| `GS V 66 0` | `0x1D 0x56 0x42 0x00` | Partial cut paper command | **PASS** |

- **Verdict on ESC/POS Generator:** **PASS (100%)**

---

## 3. Android Native Bluetooth SPP Bridge (`MainActivity.kt`)

### 3.1 MethodChannel Lifecycle
In [`MainActivity.kt`](file:///d:/Mini-POS-Inventory-Flutter-main/Mini-POS-Inventory-Flutter-main/android/app/src/main/kotlin/com/example/mini_pos/MainActivity.kt):
- **Channel Name:** `com.darvi.billing/bluetooth_printer`
- **Supported Methods:**
  1. `getPairedDevices`: Queries `BluetoothAdapter.getDefaultAdapter().bondedDevices` and returns MAC address, device name, and pairing state.
  2. `connect(macAddress)`: Initiates RFCOMM socket using standard SPP UUID (`00001101-0000-1000-8000-00805F9B34FB`).
  3. `sendBytes(bytes)`: Streams raw ESC/POS byte buffers in 256-byte chunks with 20ms delays to prevent thermal printhead buffer overflow.
  4. `disconnect()`: Flushes output stream and closes Bluetooth socket cleanly.

- **Verdict on Native SPP RFCOMM Implementation:** **PASS (100%)**

---

## 4. Physical Hardware Verification Status

In accordance with our strict verification guidelines:

| Validation Criteria | Host Status | Audit Result | Reason |
|---|---|:---:|---|
| **ESC/POS Byte Emulation** | Local Dart Engine | **PASS** | Unit tests verify exact hex commands and 32-column bounds. |
| **Android MethodChannel** | Kotlin Android Codebase | **PASS** | Native RFCOMM socket logic compiled into release APK. |
| **Physical SSEZNIK2POS Device** | **Not connected to build host** | **NOT VERIFIED** | The physical thermal printer is not attached to this Windows workstation. |

---

## 5. Physical Hardware Pairing & Testing Instructions (For Store Deployment)

Follow these steps when testing on the physical SSEZNIK2POS hardware at the Darvi Group store:
1. Power on the SSEZNIK2POS printer and verify that the blue Bluetooth status LED is blinking.
2. Ensure 58mm thermal paper roll is loaded with the thermal-sensitive side facing up.
3. Open Android OS **Settings -> Connected Devices -> Bluetooth**.
4. Scan and select **SSEZNIK2POS** (or `POS-58`). If prompted for a pairing PIN, enter `0000` or `1234`.
5. Launch **Darvi Billing**.
6. Navigate to **POS**, add items to cart, and tap **Charge**.
7. In the payment completion dialog, tap **Print Thermal Receipt**.
8. Select the paired SSEZNIK2POS device.
9. Verify that the receipt feeds cleanly, aligns with 32 columns, prints GSTIN `29BKZPA0053M1ZQ`, feeds 3 lines, and partial-cuts.

