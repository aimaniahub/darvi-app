# QuickStock POS Source Code Audit: Navigation & Routing Architecture

**Document ID:** `docs/darvi-audit/NAVIGATION_AUDIT.md`  
**Audit Date:** November 2026  
**Auditor:** Senior Flutter Architect & Software Auditor  

---

## 1. Routing Implementation Review

Navigation in QuickStock POS is implemented via `go_router: ^17.1.0` in `lib/app/router/app_router.dart`.

```mermaid
graph TD
    Root[AppRouter: initialLocation = /login] --> Guard{Auth Guard: redirect}
    Guard -->|Not Authenticated| Login[/login: LoginPage]
    Guard -->|Authenticated| Shell[ShellRoute: AppShellPage]
    Shell --> Tab1[/pos: PosPage]
    Shell --> Tab2[/products: ProductsPage]
    Shell --> Tab3[/reports: ReportsPage]
    Shell --> Tab4[/settings: SettingsPage]
    Tab3 --> InvoiceSubroute[/reports/invoice/:id: InvoiceDetailPage]
```

### Route Configuration Table

| Path | Route Type | Page Widget | Guard / Redirect Condition | State Preservation |
|---|---|---|---|---|
| `/login` | Top-level `GoRoute` | `LoginPage` | If `isAuthenticated == true`, redirects to `/pos`. | Destroyed on redirect. |
| `/` (Shell) | `ShellRoute` | `AppShellPage` | If `!isAuthenticated`, redirects to `/login`. | Contains persistent bottom navigation bar. |
| `/pos` | Child `GoRoute` | `PosPage` | Auth required. | Re-created when navigating between tabs. |
| `/products` | Child `GoRoute` | `ProductsPage` | Auth required. | Re-created when navigating between tabs. |
| `/reports` | Child `GoRoute` | `ReportsPage` | Auth required. | Re-created when navigating between tabs. |
| `/reports/invoice/:id` | Nested `GoRoute` | `InvoiceDetailPage` | Auth required; parses `state.pathParameters['id']`. | Pushed on top of `/reports`. Back returns to `/reports`. |
| `/settings` | Child `GoRoute` | `SettingsPage` | Auth required. | Re-created when navigating between tabs. |

---

## 2. Authentication Guards & Reactive Routing

The router listens to state emissions from `AppCubit` via `GoRouterRefreshStream`:
```dart
refreshListenable: GoRouterRefreshStream(dependencies.appCubit.stream),
redirect: (context, state) {
  final isAuthenticated = dependencies.appCubit.state.isAuthenticated;
  final isLoginRoute = state.uri.path == '/login';

  if (!isAuthenticated && !isLoginRoute) {
    return '/login';
  }
  if (isAuthenticated && isLoginRoute) {
    return '/pos';
  }
  return null;
},
```

### Evaluation of Auth Guard:
1. **Strengths:** 
   - Instant reactive redirection when `loginCashier()`, `loginAdmin()`, or `logout()` is invoked.
   - Prevents unauthenticated access to shell routes.
2. **Weaknesses:**
   - **No Role-Based Route Guards:** There is no route-level check for Admin vs. Cashier. A Cashier can theoretically navigate to `/settings` or `/reports` if a route link is accessible. Access restriction is handled only inside individual widgets (e.g. hiding the Add Product FAB), rather than at the route guard level.
   - **Single Initial Destination:** Authenticated users are always redirected to `/pos`, which is appropriate for retail POS but may need configurable routing in Darvi Billing (e.g. Admin landing on Dashboard, Cashier landing on POS).

---

## 3. Back Navigation & Navigation Stack Integrity

1. **Shell Route Navigation:**
   - In `AppShellPage`:
     ```dart
     onDestinationSelected: (index) {
       if (index == _currentIndex) return;
       context.go(_tabs[index]);
     }
     ```
   - Using `context.go()` replaces the current location within the shell. It does not push onto an arbitrary deep stack, preventing infinite back-stack loops.
2. **Subroute Navigation:**
   - Tapping an invoice in `ReportsPage` calls:
     ```dart
     context.push('/reports/invoice/${invoice.id}')
     ```
   - This correctly pushes `InvoiceDetailPage` onto the navigator stack. The system back button or `AppBar` back button returns the user cleanly to `/reports`.
3. **Screen State Preservation Issue:**
   - Because `ShellRoute` is used instead of `StatefulShellRoute`, switching between tabs (e.g. from `/pos` to `/products` and back to `/pos`) causes the child pages to be **disposed and rebuilt**.
   - **Impact on POS:** If a cashier adds items to the cart in `PosPage`, then navigates to `ProductsPage` to check an item, and navigates back to `/pos`:
     - The `PosCubit` is provided via `BlocProvider(create: ...)` *inside* `PosPage.build()`.
     - **When the user navigates away from `/pos`, `PosCubit` is closed and the cart is destroyed!**
   - **Critical Fix for Darvi:** Upgrade `ShellRoute` to `StatefulShellRoute.indexedStack` or move `PosCubit` to `AppDependencies` so that the cart state survives tab switches.

---

## 4. Missing Routes Required for Darvi Billing

To support Darvi Billing's expanded business operations, the following routes must be added:

```mermaid
graph LR
    DarviShell[Darvi Navigation Shell] --> SalesGroup[Sales & Billing]
    DarviShell --> InventoryGroup[Catalog & Inventory]
    DarviShell --> PartyGroup[Customers & Suppliers]
    DarviShell --> AccountsGroup[Accounts & Ledger]
    DarviShell --> StaffGroup[Staff & Incentives]
    DarviShell --> HardwareGroup[Hardware & Settings]

    SalesGroup --> R1[/pos]
    SalesGroup --> R2[/invoices]
    SalesGroup --> R3[/quotations]

    InventoryGroup --> R4[/products]
    InventoryGroup --> R5[/categories]
    InventoryGroup --> R6[/stock-movements]

    PartyGroup --> R7[/customers]
    PartyGroup --> R8[/suppliers]
    PartyGroup --> R9[/purchases]

    AccountsGroup --> R10[/customer-ledger/:id]
    AccountsGroup --> R11[/supplier-ledger/:id]
    AccountsGroup --> R12[/expenses]
    AccountsGroup --> R13[/cash-bank]

    StaffGroup --> R14[/employees]
    StaffGroup --> R15[/attendance]
    StaffGroup --> R16[/payroll]
    StaffGroup --> R17[/incentives]

    HardwareGroup --> R18[/printer-settings]
    HardwareGroup --> R19[/settings]
    HardwareGroup --> R20[/workspaces]
```

