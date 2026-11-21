import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// Multi-tenant business workspace (Darvi Group Agri Tech and regional branches)
class Workspaces extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get businessName => text()();
  TextColumn get gstin => text().nullable()();
  TextColumn get address => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get receiptSlogan =>
      text().withDefault(const Constant('Improving Agriculture, Improving lives.'))();
  TextColumn get receiptTerms => text().withDefault(const Constant(
      'Goods once sold will not be taken back or exchanged.\nNo cash payments accepted.'))();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Financial accounts (Cash Drawers, Bank Accounts, UPI accounts)
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()(); // e.g. "Store Cash Drawer", "Company Bank Account", "Store UPI Account"
  TextColumn get type => text()(); // 'cash', 'bank', 'upi'
  TextColumn get accountNumber => text().nullable()();
  RealColumn get openingBalance => real().withDefault(const Constant(0.0))();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Payment transactions linked to sales, purchases, or ledger entries
class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get paymentType => text()(); // 'customer_receipt', 'supplier_payment', 'expense', 'transfer'
  TextColumn get referenceType => text()(); // 'sale', 'purchase_invoice', 'customer', 'supplier', 'expense', 'transfer', 'other'
  IntColumn get referenceId => integer().nullable()(); // saleId, purchaseInvoiceId
  RealColumn get amount => real()();
  TextColumn get paymentMode => text()(); // 'cash', 'upi', 'card', 'bank_transfer', 'standard'
  TextColumn get referenceNo => text().nullable()(); // UTR / Invoice / Cheque No
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  TextColumn get narration => text().nullable()();
}

/// Double-entry transaction ledger: the immutable source of truth for all party & account balances
class LedgerEntries extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get transactionType => text()(); // 'sale', 'sale_return', 'purchase', 'purchase_return', 'payment_in', 'payment_out', 'expense', 'salary', 'incentive', 'opening_balance'
  TextColumn get referenceType => text()(); // 'revenue', 'tax_payable', 'customer', 'supplier', 'account', 'expense', 'salary', 'incentive', 'equity'
  IntColumn get referenceId => integer().nullable()();
  TextColumn get partyType => text().nullable()(); // 'customer', 'supplier', 'employee'
  IntColumn get partyId => integer().nullable()();
  IntColumn get accountId =>
      integer().nullable().references(Accounts, #id, onDelete: KeyAction.restrict)();
  RealColumn get debit => real().withDefault(const Constant(0.0))();
  RealColumn get credit => real().withDefault(const Constant(0.0))();
  TextColumn get narration => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Multi-item purchase bills from suppliers
class PurchaseInvoices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get supplierId =>
      integer().references(Suppliers, #id, onDelete: KeyAction.restrict)();
  TextColumn get invoiceNumber => text()(); // Supplier bill number
  DateTimeColumn get invoiceDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get subtotal => real()();
  RealColumn get taxTotal => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  TextColumn get status => text().withDefault(const Constant('unpaid'))(); // 'unpaid', 'partial', 'paid'
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Line items for multi-item purchase bills
class PurchaseInvoiceItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get purchaseInvoiceId =>
      integer().references(PurchaseInvoices, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.restrict)();
  IntColumn get quantity => integer()();
  RealColumn get unitCost => real()();
  RealColumn get gstRate => real().withDefault(const Constant(0.0))();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
}

/// Expense tracking for daily store operations
class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get category => text()(); // 'Rent', 'Electricity', 'Tea/Snacks', 'Transport', 'Marketing', 'Repairs', 'Other'
  RealColumn get amount => real()();
  DateTimeColumn get expenseDate => dateTime().withDefault(currentDateAndTime)();
  TextColumn get referenceNo => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Employee records with profiles, role-based access, and salary details
class Employees extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get employeeCode => text().unique()(); // e.g. "EMP001"
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get role => text()(); // 'admin', 'manager', 'cashier', 'agronomist', 'field_officer'
  TextColumn get designation => text()(); // 'Store Manager', 'Cashier', 'Field Executive'
  TextColumn get department => text().withDefault(const Constant('Sales'))();
  TextColumn get loginPin => text()(); // 4 or 6-digit secure PIN
  RealColumn get baseSalary => real().withDefault(const Constant(0.0))();
  DateTimeColumn get joiningDate => dateTime().withDefault(currentDateAndTime)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Daily staff attendance with clock-in / clock-out tracking
class Attendances extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get date => dateTime()(); // Day without time
  DateTimeColumn get checkInTime => dateTime().nullable()();
  DateTimeColumn get checkOutTime => dateTime().nullable()();
  TextColumn get status => text().withDefault(const Constant('present'))(); // 'present', 'absent', 'half_day', 'on_leave'
  RealColumn get workingHours => real().withDefault(const Constant(8.0))();
  TextColumn get notes => text().nullable()();
}

/// Staff leave requests
class LeaveRequests extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime()();
  TextColumn get leaveType => text()(); // 'casual', 'sick', 'earned', 'unpaid'
  TextColumn get reason => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'approved', 'rejected'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Monthly payroll records
class PayrollRecords extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  IntColumn get month => integer()(); // 1 - 12
  IntColumn get year => integer()(); // e.g. 2026
  RealColumn get basicSalary => real()();
  RealColumn get incentiveAmount => real().withDefault(const Constant(0.0))();
  RealColumn get allowances => real().withDefault(const Constant(0.0))();
  RealColumn get deductions => real().withDefault(const Constant(0.0))();
  RealColumn get netSalary => real()();
  TextColumn get status => text().withDefault(const Constant('draft'))(); // 'draft', 'approved', 'paid'
  IntColumn get paidFromAccountId =>
      integer().nullable().references(Accounts, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get paidDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Configurable incentive commission rules
class IncentiveRules extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()(); // e.g. "Monthly Sales 2% Bonus", "Neem Guard 10 Rs/pack"
  TextColumn get ruleType => text()(); // 'percentage_revenue', 'fixed_per_product', 'target_slab'
  RealColumn get thresholdAmount => real().withDefault(const Constant(0.0))();
  RealColumn get rewardRate => real()(); // percentage or fixed amount
  IntColumn get targetProductId =>
      integer().nullable().references(Products, #id, onDelete: KeyAction.cascade)();
  IntColumn get targetCategoryId =>
      integer().nullable().references(Categories, #id, onDelete: KeyAction.cascade)();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Monthly sales targets assigned to employees
class SalesTargets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  IntColumn get month => integer()();
  IntColumn get year => integer()();
  RealColumn get targetRevenue => real()();
  RealColumn get achievedRevenue => real().withDefault(const Constant(0.0))();
  BoolColumn get isAchieved => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Individual incentive commission claims & approval workflows
class IncentiveClaims extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get employeeId =>
      integer().references(Employees, #id, onDelete: KeyAction.cascade)();
  IntColumn get saleId =>
      integer().nullable().references(Sales, #id, onDelete: KeyAction.cascade)();
  RealColumn get amount => real()();
  TextColumn get description => text()();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'approved', 'rejected', 'paid'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get processedAt => dateTime().nullable()();
}

/// Real estate / farmland development projects (e.g. "Vikshha Farmland Phase 1")
class Projects extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get code => text().unique()();
  TextColumn get location => text()();
  RealColumn get totalArea => real().withDefault(const Constant(0.0))(); // in acres / sq ft
  IntColumn get totalPlots => integer().withDefault(const Constant(0))();
  TextColumn get description => text().nullable()();
  TextColumn get status => text().withDefault(const Constant('active'))(); // 'active', 'completed', 'upcoming'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Vikshha farmland plots with agricultural details, status, and pricing
class Plots extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get projectId =>
      integer().references(Projects, #id, onDelete: KeyAction.cascade)();
  TextColumn get plotNumber => text()(); // e.g. "A-12"
  TextColumn get uniquePlotId => text().unique()(); // e.g. "VK-P1-A12"
  TextColumn get dimensions => text()(); // e.g. "60 x 40 ft"
  RealColumn get areaSqFt => real()();
  TextColumn get surveyNumber => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('available'))(); // 'available', 'reserved', 'booked', 'sold'
  RealColumn get basePrice => real()(); // rate per sq ft or base price
  RealColumn get totalPrice => real()();
  TextColumn get cropType => text().nullable()(); // e.g. "Sandalwood & Mahogany"
  TextColumn get plantationDetails => text().nullable()(); // e.g. "20 sandalwood trees with automated drip"
  TextColumn get imagePath => text().nullable()();
  TextColumn get documentPath => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// Farmland CRM leads tracking potential plot and agri investors
class Leads extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get phone => text()();
  TextColumn get email => text().nullable()();
  TextColumn get source =>
      text().withDefault(const Constant('Walk-in'))(); // 'Walk-in', 'Phone', 'Referral', 'Digital Ads', 'Agri Expo', 'Other'
  IntColumn get interestedProjectId =>
      integer().nullable().references(Projects, #id, onDelete: KeyAction.setNull)();
  IntColumn get interestedPlotId =>
      integer().nullable().references(Plots, #id, onDelete: KeyAction.setNull)();
  RealColumn get budget => real().withDefault(const Constant(0.0))();
  TextColumn get requirements => text().nullable()();
  TextColumn get stage =>
      text().withDefault(const Constant('new'))(); // 'new', 'contacted', 'interested', 'site_visit', 'negotiation', 'converted', 'lost'
  IntColumn get assignedEmployeeId =>
      integer().nullable().references(Employees, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get nextFollowUpDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

/// CRM site visits scheduled and conducted with leads
class SiteVisits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get leadId =>
      integer().references(Leads, #id, onDelete: KeyAction.cascade)();
  IntColumn get projectId =>
      integer().nullable().references(Projects, #id, onDelete: KeyAction.setNull)();
  IntColumn get plotId =>
      integer().nullable().references(Plots, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get scheduledDate => dateTime()();
  IntColumn get conductedByEmployeeId =>
      integer().nullable().references(Employees, #id, onDelete: KeyAction.setNull)();
  TextColumn get feedback => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('scheduled'))(); // 'scheduled', 'completed', 'cancelled'
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// CRM lead interaction logs (calls, WhatsApp messages, meetings, notes)
class LeadActivities extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  IntColumn get leadId =>
      integer().references(Leads, #id, onDelete: KeyAction.cascade)();
  IntColumn get employeeId =>
      integer().nullable().references(Employees, #id, onDelete: KeyAction.setNull)();
  TextColumn get activityType => text()(); // 'call', 'meeting', 'site_visit', 'note', 'whatsapp', 'email'
  TextColumn get notes => text()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Formal business quotations for plots, agri products, and farm management services
class Quotations extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get quotationNumber => text().unique()(); // e.g. "QT-2026-0001"
  IntColumn get customerId =>
      integer().nullable().references(Customers, #id, onDelete: KeyAction.setNull)();
  IntColumn get leadId =>
      integer().nullable().references(Leads, #id, onDelete: KeyAction.setNull)();
  TextColumn get customerName => text()();
  TextColumn get customerPhone => text()();
  DateTimeColumn get quotationDate => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get validUntil => dateTime()();
  RealColumn get subtotal => real()();
  RealColumn get discountTotal => real().withDefault(const Constant(0.0))();
  RealColumn get taxTotal => real().withDefault(const Constant(0.0))();
  RealColumn get cgstTotal => real().withDefault(const Constant(0.0))();
  RealColumn get sgstTotal => real().withDefault(const Constant(0.0))();
  RealColumn get igstTotal => real().withDefault(const Constant(0.0))();
  RealColumn get totalAmount => real()();
  TextColumn get status =>
      text().withDefault(const Constant('draft'))(); // 'draft', 'sent', 'accepted', 'rejected', 'converted'
  TextColumn get terms => text().nullable()();
  TextColumn get notes => text().nullable()();
  TextColumn get convertedReferenceType => text().nullable()(); // 'sale', 'booking'
  IntColumn get convertedReferenceId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Quotation line items for products, plots, or agricultural services
class QuotationItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get quotationId =>
      integer().references(Quotations, #id, onDelete: KeyAction.cascade)();
  TextColumn get itemType =>
      text().withDefault(const Constant('product'))(); // 'product', 'plot', 'service'
  IntColumn get referenceId => integer().nullable()(); // productId or plotId
  TextColumn get description => text()();
  RealColumn get quantity => real().withDefault(const Constant(1.0))();
  RealColumn get unitPrice => real()();
  RealColumn get discount => real().withDefault(const Constant(0.0))();
  RealColumn get gstRate => real().withDefault(const Constant(0.0))();
  RealColumn get total => real()();
}

/// Customer plot booking contracts and payment milestones
class PlotBookings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get bookingNumber => text().unique()(); // e.g. "BK-2026-0001"
  IntColumn get plotId =>
      integer().references(Plots, #id, onDelete: KeyAction.restrict)();
  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.restrict)();
  IntColumn get leadId =>
      integer().nullable().references(Leads, #id, onDelete: KeyAction.setNull)();
  IntColumn get employeeId =>
      integer().nullable().references(Employees, #id, onDelete: KeyAction.setNull)();
  DateTimeColumn get bookingDate => dateTime().withDefault(currentDateAndTime)();
  RealColumn get totalPlotValue => real()();
  RealColumn get bookingAmount => real()();
  IntColumn get paymentAccountId =>
      integer().nullable().references(Accounts, #id, onDelete: KeyAction.restrict)();
  TextColumn get paymentMode =>
      text().withDefault(const Constant('upi'))(); // 'cash', 'upi', 'bank_transfer', 'cheque'
  TextColumn get referenceNo => text().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('booked'))(); // 'booked', 'confirmed', 'cancelled', 'completed'
  TextColumn get cancellationReason => text().nullable()();
  RealColumn get refundAmount => real().withDefault(const Constant(0.0))();
  IntColumn get refundAccountId =>
      integer().nullable().references(Accounts, #id, onDelete: KeyAction.restrict)();
  DateTimeColumn get refundDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Installment schedules for plot bookings
class BookingInstallments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get bookingId =>
      integer().references(PlotBookings, #id, onDelete: KeyAction.cascade)();
  IntColumn get installmentNumber => integer()();
  TextColumn get title => text()(); // e.g. "Booking Advance", "Agreement", "Milestone 1", "Registration"
  DateTimeColumn get dueDate => dateTime()();
  RealColumn get amount => real()();
  RealColumn get paidAmount => real().withDefault(const Constant(0.0))();
  DateTimeColumn get paidDate => dateTime().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // 'pending', 'partial', 'paid'
  IntColumn get paymentAccountId =>
      integer().nullable().references(Accounts, #id, onDelete: KeyAction.restrict)();
}

/// Shipping and delivery dispatch orders linked to sales invoices
class DeliveryOrders extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get workspaceId =>
      integer().references(Workspaces, #id, onDelete: KeyAction.cascade)();
  TextColumn get deliveryNumber => text().unique()(); // e.g. "DO-2026-0001"
  IntColumn get saleId =>
      integer().nullable().references(Sales, #id, onDelete: KeyAction.cascade)();
  IntColumn get customerId =>
      integer().references(Customers, #id, onDelete: KeyAction.restrict)();
  TextColumn get deliveryAddress => text()();
  TextColumn get transporterName => text().nullable()();
  TextColumn get vehicleNumber => text().nullable()();
  TextColumn get trackingNumber => text().nullable()();
  RealColumn get shippingCharges => real().withDefault(const Constant(0.0))();
  DateTimeColumn get dispatchDate => dateTime().nullable()();
  DateTimeColumn get expectedDeliveryDate => dateTime().nullable()();
  DateTimeColumn get deliveredDate => dateTime().nullable()();
  TextColumn get status =>
      text().withDefault(const Constant('pending'))(); // 'pending', 'packed', 'dispatched', 'in_transit', 'delivered', 'failed'
  TextColumn get proofOfDelivery => text().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

/// Items dispatched in a delivery order
class DeliveryOrderItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get deliveryOrderId =>
      integer().references(DeliveryOrders, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.restrict)();
  IntColumn get quantity => integer()();
  TextColumn get unit => text().withDefault(const Constant('piece'))();
}

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get workspaceId =>
      integer().nullable().references(Workspaces, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  TextColumn get sku => text().unique()();

  TextColumn get barcode => text().nullable().unique()();

  IntColumn get categoryId =>
      integer().nullable().references(Categories, #id, onDelete: KeyAction.setNull)();

  RealColumn get cost => real()();

  RealColumn get price => real()();

  IntColumn get stockQty => integer()();

  IntColumn get lowStockThreshold => integer().withDefault(const Constant(5))();

  TextColumn get unit => text().withDefault(const Constant('piece'))();

  TextColumn get notes => text().nullable()();

  TextColumn get imagePath => text().nullable()();

  TextColumn get hsnCode => text().nullable()();

  RealColumn get gstRate => real().withDefault(const Constant(0.0))();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get name => text().unique()();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade)();

  TextColumn get type => text()();

  IntColumn get qtyChange => integer()();

  TextColumn get reason => text().nullable()();

  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id, onDelete: KeyAction.setNull)();

  RealColumn get unitCost => real().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get workspaceId =>
      integer().nullable().references(Workspaces, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  TextColumn get phone => text().nullable()();

  TextColumn get notes => text().nullable()();

  TextColumn get gstin => text().nullable()();

  TextColumn get address => text().nullable()();

  RealColumn get balance => real().withDefault(const Constant(0))();

  RealColumn get creditLimit => real().withDefault(const Constant(50000.0))();
}

class Suppliers extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get workspaceId =>
      integer().nullable().references(Workspaces, #id, onDelete: KeyAction.cascade)();

  TextColumn get name => text()();

  TextColumn get phone => text().nullable()();

  TextColumn get gstin => text().nullable()();

  TextColumn get address => text().nullable()();

  RealColumn get balance => real().withDefault(const Constant(0.0))();
}

class Purchases extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get supplierId =>
      integer().nullable().references(Suppliers, #id, onDelete: KeyAction.setNull)();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.cascade)();

  IntColumn get qty => integer()();

  RealColumn get unitCost => real()();

  TextColumn get notes => text().nullable()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get workspaceId =>
      integer().nullable().references(Workspaces, #id, onDelete: KeyAction.cascade)();

  TextColumn get invoiceNo => text().unique()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  IntColumn get customerId =>
      integer().nullable().references(Customers, #id, onDelete: KeyAction.setNull)();

  IntColumn get employeeId => integer().nullable()();

  RealColumn get subtotal => real()();

  RealColumn get discountTotal => real()();

  RealColumn get taxTotal => real()();

  RealColumn get cgstTotal => real().withDefault(const Constant(0.0))();

  RealColumn get sgstTotal => real().withDefault(const Constant(0.0))();

  RealColumn get igstTotal => real().withDefault(const Constant(0.0))();

  RealColumn get roundOff => real().withDefault(const Constant(0.0))();

  RealColumn get total => real()();

  RealColumn get paid => real()();

  RealColumn get changeAmount => real()();

  TextColumn get paymentMethod => text()();

  TextColumn get status => text()();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();

  IntColumn get saleId => integer().references(Sales, #id, onDelete: KeyAction.cascade)();

  IntColumn get productId =>
      integer().references(Products, #id, onDelete: KeyAction.restrict)();

  TextColumn get nameSnapshot => text()();

  RealColumn get costSnapshot => real()();

  RealColumn get priceSnapshot => real()();

  IntColumn get qty => integer()();

  RealColumn get discount => real().withDefault(const Constant(0))();

  RealColumn get lineTotal => real()();
}

class AppSettings extends Table {
  IntColumn get id => integer()();

  @override
  Set<Column> get primaryKey => {id};

  TextColumn get storeName => text().withDefault(const Constant('Mini Store'))();

  TextColumn get currency => text().withDefault(const Constant('EGP'))();

  BoolColumn get taxEnabled => boolean().withDefault(const Constant(false))();

  RealColumn get taxRate => real().withDefault(const Constant(0.14))();

  TextColumn get receiptHeader => text().withDefault(const Constant('Thank you!'))();

  TextColumn get receiptFooter =>
      text().withDefault(const Constant('Visit us again'))();

  TextColumn get language => text().withDefault(const Constant('en'))();

  BoolColumn get allowNegativeStock => boolean().withDefault(const Constant(false))();

  TextColumn get cashierPin => text().withDefault(const Constant('1234'))();

  TextColumn get adminPassword => text().withDefault(const Constant('admin123'))();
}

@DriftDatabase(
  tables: [
    Workspaces,
    Accounts,
    Payments,
    LedgerEntries,
    PurchaseInvoices,
    PurchaseInvoiceItems,
    Expenses,
    Employees,
    Attendances,
    LeaveRequests,
    PayrollRecords,
    IncentiveRules,
    SalesTargets,
    IncentiveClaims,
    Projects,
    Plots,
    Leads,
    SiteVisits,
    LeadActivities,
    Quotations,
    QuotationItems,
    PlotBookings,
    BookingInstallments,
    DeliveryOrders,
    DeliveryOrderItems,
    Products,
    Categories,
    StockMovements,
    Customers,
    Suppliers,
    Purchases,
    Sales,
    SaleItems,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 4;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Mandatory SQLite foreign-key enforcement
          await customStatement('PRAGMA foreign_keys = ON;');
          await ensureGroup1SchemaTables();
          await ensureGroup2SchemaTables();
          await ensureGroup3SchemaTables();
          await ensureGroup4SchemaTables();
          await ensurePhase4_4SchemaTables();
          await ensurePhase5_1SchemaTables();
          await ensureVikshhaCrmSchemaTables();
          await sanitizeDateTimeColumns();
        },
        onCreate: (m) async {
          await m.createAll();
        },
        onUpgrade: (m, from, to) async {
          if (from < 3) {
            // 1. Create new Darvi multi-tenant, financial and HR tables
            await m.createTable(workspaces);
            await m.createTable(accounts);
            await m.createTable(payments);
            await m.createTable(ledgerEntries);
            await m.createTable(purchaseInvoices);
            await m.createTable(purchaseInvoiceItems);
            await m.createTable(expenses);
            await m.createTable(employees);
            await m.createTable(attendances);
            await m.createTable(leaveRequests);
            await m.createTable(payrollRecords);
            await m.createTable(incentiveRules);
            await m.createTable(salesTargets);
            await m.createTable(incentiveClaims);

            // 2. Add columns to existing business tables (non-destructive)
            await m.addColumn(products, products.workspaceId);
            await m.addColumn(products, products.hsnCode);
            await m.addColumn(products, products.gstRate);

            await m.addColumn(sales, sales.workspaceId);
            await m.addColumn(sales, sales.employeeId);
            await m.addColumn(sales, sales.cgstTotal);
            await m.addColumn(sales, sales.sgstTotal);
            await m.addColumn(sales, sales.igstTotal);
            await m.addColumn(sales, sales.roundOff);

            await m.addColumn(customers, customers.workspaceId);
            await m.addColumn(customers, customers.gstin);
            await m.addColumn(customers, customers.address);
            await m.addColumn(customers, customers.creditLimit);

            await m.addColumn(suppliers, suppliers.workspaceId);
            await m.addColumn(suppliers, suppliers.gstin);
            await m.addColumn(suppliers, suppliers.address);
            await m.addColumn(suppliers, suppliers.balance);

            // 3. Seed primary Darvi workspace
            await customStatement('''
              INSERT OR IGNORE INTO workspaces (
                id, business_name, gstin, address, phone, receipt_slogan, receipt_terms, currency, is_default
              ) VALUES (
                1,
                'Darvi Group Agri Tech',
                '29BKZPA0053M1ZQ',
                '#2 Totad Building, Arjun Vihar, Gokul Road, Hubli, Karnataka 580030, India',
                '9986890777',
                'Improving Agriculture, Improving lives.',
                'Goods once sold will not be taken back or exchanged.\nNo cash payments accepted.',
                'INR',
                1
              );
            ''');

            // 4. Backfill existing business data to workspaceId = 1
            await customStatement('UPDATE products SET workspace_id = 1 WHERE workspace_id IS NULL;');
            await customStatement('UPDATE sales SET workspace_id = 1 WHERE workspace_id IS NULL;');
            await customStatement('UPDATE customers SET workspace_id = 1 WHERE workspace_id IS NULL;');
            await customStatement('UPDATE suppliers SET workspace_id = 1 WHERE workspace_id IS NULL;');

            // 5. Migrate existing non-zero customer balances into double-entry ledger opening entries
            final custRows = await customSelect(
              'SELECT id, name, balance FROM customers WHERE balance != 0;',
              readsFrom: {customers},
            ).get();

            final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            for (final row in custRows) {
              final cid = row.data['id'] as int;
              final cname = row.data['name'] as String? ?? 'Customer';
              final bal = (row.data['balance'] as num).toDouble();

              if (bal > 0) {
                await customStatement('''
                  INSERT INTO ledger_entries (
                    workspace_id, transaction_type, reference_type, reference_id,
                    party_type, party_id, debit, credit, narration, created_at
                  ) VALUES (1, 'opening_balance', 'customer', ?, 'customer', ?, ?, 0.0, ?, ?)
                ''', [cid, cid, bal, 'Migrated opening balance for $cname', nowSeconds]);

                await customStatement('''
                  INSERT INTO ledger_entries (
                    workspace_id, transaction_type, reference_type, reference_id,
                    debit, credit, narration, created_at
                  ) VALUES (1, 'opening_balance', 'equity', 0, 0.0, ?, 'Offsetting opening balance credit to Capital/Equity', ?)
                ''', [bal, nowSeconds]);
              }
            }

            // 6. Migrate existing non-zero supplier balances into double-entry ledger opening entries
            final suppRows = await customSelect(
              'SELECT id, name, balance FROM suppliers WHERE balance != 0;',
              readsFrom: {suppliers},
            ).get();

            for (final row in suppRows) {
              final sid = row.data['id'] as int;
              final sname = row.data['name'] as String? ?? 'Supplier';
              final bal = (row.data['balance'] as num).toDouble();

              if (bal > 0) {
                await customStatement('''
                  INSERT INTO ledger_entries (
                    workspace_id, transaction_type, reference_type, reference_id,
                    debit, credit, narration, created_at
                  ) VALUES (1, 'opening_balance', 'equity', 0, ?, 0.0, 'Offsetting opening balance debit to Capital/Equity', ?)
                ''', [bal, nowSeconds]);

                await customStatement('''
                  INSERT INTO ledger_entries (
                    workspace_id, transaction_type, reference_type, reference_id,
                    party_type, party_id, debit, credit, narration, created_at
                  ) VALUES (1, 'opening_balance', 'supplier', ?, 'supplier', ?, 0.0, ?, ?, ?)
                ''', [sid, sid, bal, 'Migrated opening payable balance for $sname', nowSeconds]);
              }
            }
          }

          if (from < 4) {
            // Create P3 tables: Vikshha Plots, CRM Leads, Quotations, Bookings, Shipping & Deliveries
            await m.createTable(projects);
            await m.createTable(plots);
            await m.createTable(leads);
            await m.createTable(siteVisits);
            await m.createTable(leadActivities);
            await m.createTable(quotations);
            await m.createTable(quotationItems);
            await m.createTable(plotBookings);
            await m.createTable(bookingInstallments);
            await m.createTable(deliveryOrders);
            await m.createTable(deliveryOrderItems);
          }

          await sanitizeDateTimeColumns();
        },
      );

  /// Ensures Group 1 (Products, Batches, Stock Movements) tables and columns are present
  Future<void> ensureGroup1SchemaTables() async {
    // 1. Ensure product_batches table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS product_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        product_id INTEGER NOT NULL,
        batch_number TEXT NOT NULL,
        mfg_date INTEGER,
        expiry_date INTEGER,
        cost_price REAL NOT NULL DEFAULT 0.0,
        selling_price REAL NOT NULL DEFAULT 0.0,
        quantity INTEGER NOT NULL DEFAULT 0,
        initial_quantity INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        supplier_id INTEGER,
        purchase_invoice_id INTEGER,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
      );
    ''');

    // 2. Add columns to products if missing
    for (final colSql in [
      'ALTER TABLE products ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;',
      'ALTER TABLE products ADD COLUMN mrp REAL DEFAULT 0.0;',
      'ALTER TABLE products ADD COLUMN brand TEXT;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 3. Add columns to stock_movements if missing
    for (final colSql in [
      'ALTER TABLE stock_movements ADD COLUMN workspace_id INTEGER NOT NULL DEFAULT 1;',
      'ALTER TABLE stock_movements ADD COLUMN batch_number TEXT;',
      'ALTER TABLE stock_movements ADD COLUMN balance_after INTEGER;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }
  }

  /// Ensures Group 2 (Employee Management, Shifts, Leaves, Payroll, Sales Targets) tables & columns are present
  Future<void> ensureGroup2SchemaTables() async {
    // 1. Shifts table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        start_time TEXT NOT NULL,
        end_time TEXT NOT NULL,
        break_minutes INTEGER NOT NULL DEFAULT 30,
        grace_minutes INTEGER NOT NULL DEFAULT 15,
        is_overnight INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      );
    ''');

    // 2. Holidays table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS holidays (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        date TEXT NOT NULL,
        description TEXT,
        is_optional INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');

    // 3. Employee audit logs table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS employee_audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        employee_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        field_name TEXT,
        old_value TEXT,
        new_value TEXT,
        performed_by TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    // 4. Non-destructive column expansion for employees
    for (final colSql in [
      'ALTER TABLE employees ADD COLUMN date_of_birth TEXT;',
      'ALTER TABLE employees ADD COLUMN gender TEXT DEFAULT "male";',
      'ALTER TABLE employees ADD COLUMN address TEXT;',
      'ALTER TABLE employees ADD COLUMN emergency_contact TEXT;',
      'ALTER TABLE employees ADD COLUMN employment_type TEXT DEFAULT "full_time";',
      'ALTER TABLE employees ADD COLUMN work_location TEXT DEFAULT "Hubli Store";',
      'ALTER TABLE employees ADD COLUMN salary_type TEXT DEFAULT "monthly";',
      'ALTER TABLE employees ADD COLUMN allowances REAL DEFAULT 0.0;',
      'ALTER TABLE employees ADD COLUMN fixed_deductions REAL DEFAULT 0.0;',
      'ALTER TABLE employees ADD COLUMN bank_account_name TEXT;',
      'ALTER TABLE employees ADD COLUMN bank_name TEXT;',
      'ALTER TABLE employees ADD COLUMN bank_account_number TEXT;',
      'ALTER TABLE employees ADD COLUMN bank_ifsc TEXT;',
      'ALTER TABLE employees ADD COLUMN shift_id INTEGER;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 5. Non-destructive column expansion for attendances
    for (final colSql in [
      'ALTER TABLE attendances ADD COLUMN shift_id INTEGER;',
      'ALTER TABLE attendances ADD COLUMN break_minutes INTEGER DEFAULT 0;',
      'ALTER TABLE attendances ADD COLUMN is_late INTEGER DEFAULT 0;',
      'ALTER TABLE attendances ADD COLUMN overtime_hours REAL DEFAULT 0.0;',
      'ALTER TABLE attendances ADD COLUMN corrected_by TEXT;',
      'ALTER TABLE attendances ADD COLUMN correction_reason TEXT;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 6. Non-destructive column expansion for leave_requests
    for (final colSql in [
      'ALTER TABLE leave_requests ADD COLUMN total_days REAL DEFAULT 1.0;',
      'ALTER TABLE leave_requests ADD COLUMN approved_by TEXT;',
      'ALTER TABLE leave_requests ADD COLUMN approver_remarks TEXT;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 7. Non-destructive column expansion for incentive_claims
    for (final colSql in [
      'ALTER TABLE incentive_claims ADD COLUMN paid_from_account_id INTEGER;',
      'ALTER TABLE incentive_claims ADD COLUMN paid_date INTEGER;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 8. Non-destructive column expansion for sales_targets
    for (final colSql in [
      'ALTER TABLE sales_targets ADD COLUMN target_type TEXT DEFAULT "revenue";',
      'ALTER TABLE sales_targets ADD COLUMN target_amount REAL DEFAULT 0.0;',
      'ALTER TABLE sales_targets ADD COLUMN current_amount REAL DEFAULT 0.0;',
      'ALTER TABLE sales_targets ADD COLUMN start_date INTEGER;',
      'ALTER TABLE sales_targets ADD COLUMN end_date INTEGER;',
      'ALTER TABLE sales_targets ADD COLUMN status TEXT DEFAULT "in_progress";',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }
  }

  /// Ensures Phase 5.1 (Financial, Security, Return & Isolation Hardening) schema extensions
  Future<void> ensurePhase5_1SchemaTables() async {
    for (final colSql in [
      'ALTER TABLE sales ADD COLUMN original_sale_id INTEGER;',
      'ALTER TABLE sale_items ADD COLUMN original_sale_item_id INTEGER;',
      'ALTER TABLE sale_items ADD COLUMN cgst REAL DEFAULT 0.0;',
      'ALTER TABLE sale_items ADD COLUMN sgst REAL DEFAULT 0.0;',
      'ALTER TABLE sale_items ADD COLUMN igst REAL DEFAULT 0.0;',
      'ALTER TABLE sale_items ADD COLUMN tax_amount REAL DEFAULT 0.0;',
      'ALTER TABLE incentive_claims ADD COLUMN original_amount REAL DEFAULT 0.0;',
      'ALTER TABLE incentive_claims ADD COLUMN reversed_amount REAL DEFAULT 0.0;',
      'ALTER TABLE product_batches ADD COLUMN workspace_id INTEGER DEFAULT 1;',
      'ALTER TABLE categories ADD COLUMN workspace_id INTEGER DEFAULT 1;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }
  }

  /// Ensures Group 3 (Purchases, Parties, Financial Accounts & Allocations) tables and columns are present
  Future<void> ensureGroup3SchemaTables() async {
    // 1. Purchase returns table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS purchase_returns (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        purchase_invoice_id INTEGER NOT NULL,
        supplier_id INTEGER NOT NULL,
        debit_note_number TEXT NOT NULL,
        return_date INTEGER NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0.0,
        tax_total REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL DEFAULT 0.0,
        reason TEXT,
        status TEXT NOT NULL DEFAULT 'completed',
        created_at INTEGER NOT NULL,
        FOREIGN KEY (purchase_invoice_id) REFERENCES purchase_invoices(id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers(id)
      );
    ''');

    // 2. Purchase return items table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS purchase_return_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_return_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        batch_number TEXT,
        quantity INTEGER NOT NULL,
        unit_cost REAL NOT NULL,
        gst_rate REAL NOT NULL DEFAULT 0.0,
        tax_amount REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL,
        FOREIGN KEY (purchase_return_id) REFERENCES purchase_returns(id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES products(id)
      );
    ''');

    // 3. Party payment allocations table (invoice-wise payment settlement)
    await customStatement('''
      CREATE TABLE IF NOT EXISTS party_payment_allocations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        payment_id INTEGER NOT NULL,
        party_type TEXT NOT NULL,
        party_id INTEGER NOT NULL,
        invoice_type TEXT NOT NULL,
        invoice_id INTEGER NOT NULL,
        allocated_amount REAL NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (payment_id) REFERENCES payments(id) ON DELETE CASCADE
      );
    ''');

    // 4. Non-destructive column expansion for purchase_invoices
    for (final colSql in [
      'ALTER TABLE purchase_invoices ADD COLUMN internal_reference TEXT;',
      'ALTER TABLE purchase_invoices ADD COLUMN supplier_invoice_date INTEGER;',
      'ALTER TABLE purchase_invoices ADD COLUMN gross_subtotal REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoices ADD COLUMN item_discount_total REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoices ADD COLUMN invoice_discount REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoices ADD COLUMN taxable_value REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoices ADD COLUMN cgst REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoices ADD COLUMN sgst REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoices ADD COLUMN igst REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoices ADD COLUMN round_off REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoices ADD COLUMN is_gst_inclusive INTEGER DEFAULT 0;',
      'ALTER TABLE purchase_invoices ADD COLUMN is_cancelled INTEGER DEFAULT 0;',
      'ALTER TABLE purchase_invoices ADD COLUMN returned_amount REAL DEFAULT 0.0;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 5. Non-destructive column expansion for purchase_invoice_items
    for (final colSql in [
      'ALTER TABLE purchase_invoice_items ADD COLUMN batch_number TEXT;',
      'ALTER TABLE purchase_invoice_items ADD COLUMN mfg_date INTEGER;',
      'ALTER TABLE purchase_invoice_items ADD COLUMN expiry_date INTEGER;',
      'ALTER TABLE purchase_invoice_items ADD COLUMN hsn_code TEXT;',
      'ALTER TABLE purchase_invoice_items ADD COLUMN purchase_unit TEXT DEFAULT "Unit";',
      'ALTER TABLE purchase_invoice_items ADD COLUMN returned_qty INTEGER DEFAULT 0;',
      'ALTER TABLE purchase_invoice_items ADD COLUMN cgst REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoice_items ADD COLUMN sgst REAL DEFAULT 0.0;',
      'ALTER TABLE purchase_invoice_items ADD COLUMN igst REAL DEFAULT 0.0;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 6. Non-destructive column expansion for customers
    for (final colSql in [
      'ALTER TABLE customers ADD COLUMN code TEXT;',
      'ALTER TABLE customers ADD COLUMN alternate_phone TEXT;',
      'ALTER TABLE customers ADD COLUMN email TEXT;',
      'ALTER TABLE customers ADD COLUMN state TEXT DEFAULT "Karnataka";',
      'ALTER TABLE customers ADD COLUMN customer_type TEXT DEFAULT "individual";',
      'ALTER TABLE customers ADD COLUMN credit_period_days INTEGER DEFAULT 30;',
      'ALTER TABLE customers ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;',
      'ALTER TABLE customers ADD COLUMN opening_balance REAL DEFAULT 0.0;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 7. Non-destructive column expansion for suppliers
    for (final colSql in [
      'ALTER TABLE suppliers ADD COLUMN code TEXT;',
      'ALTER TABLE suppliers ADD COLUMN contact_person TEXT;',
      'ALTER TABLE suppliers ADD COLUMN email TEXT;',
      'ALTER TABLE suppliers ADD COLUMN state TEXT DEFAULT "Karnataka";',
      'ALTER TABLE suppliers ADD COLUMN payment_terms TEXT DEFAULT "30 Days";',
      'ALTER TABLE suppliers ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;',
      'ALTER TABLE suppliers ADD COLUMN opening_balance REAL DEFAULT 0.0;',
      'ALTER TABLE suppliers ADD COLUMN notes TEXT;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 8. Non-destructive column expansion for accounts
    for (final colSql in [
      'ALTER TABLE accounts ADD COLUMN bank_name TEXT;',
      'ALTER TABLE accounts ADD COLUMN ifsc TEXT;',
      'ALTER TABLE accounts ADD COLUMN upi_id TEXT;',
      'ALTER TABLE accounts ADD COLUMN is_active INTEGER NOT NULL DEFAULT 1;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 9. Non-destructive column expansion for expenses
    for (final colSql in [
      'ALTER TABLE expenses ADD COLUMN vendor_payee TEXT;',
      'ALTER TABLE expenses ADD COLUMN tax_amount REAL DEFAULT 0.0;',
      'ALTER TABLE expenses ADD COLUMN is_cancelled INTEGER DEFAULT 0;',
      'ALTER TABLE expenses ADD COLUMN attachment_url TEXT;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 10. Non-destructive column expansion for payments
    for (final colSql in [
      'ALTER TABLE payments ADD COLUMN payment_date INTEGER;',
      'ALTER TABLE payments ADD COLUMN status TEXT DEFAULT "completed";',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }
  }

  /// Ensures Group 4 (POS Redesign, Held Bills, Split Payments & Sales Details) tables and columns are present
  Future<void> ensureGroup4SchemaTables() async {
    // 1. Held Bills table for parking orders
    await customStatement('''
      CREATE TABLE IF NOT EXISTS held_bills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        reference_note TEXT,
        customer_id INTEGER,
        customer_name TEXT,
        customer_phone TEXT,
        cart_data TEXT NOT NULL,
        order_discount REAL NOT NULL DEFAULT 0.0,
        tax_enabled INTEGER NOT NULL DEFAULT 0,
        tax_rate REAL NOT NULL DEFAULT 0.18,
        subtotal REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL DEFAULT 0.0,
        item_count INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL
      );
    ''');

    // 2. Non-destructive column expansion for sales
    for (final colSql in [
      'ALTER TABLE sales ADD COLUMN cashier_name TEXT;',
      'ALTER TABLE sales ADD COLUMN notes TEXT;',
      'ALTER TABLE sales ADD COLUMN payment_details TEXT;',
      'ALTER TABLE sales ADD COLUMN customer_name TEXT;',
      'ALTER TABLE sales ADD COLUMN customer_phone TEXT;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 3. Non-destructive column expansion for sale_items
    for (final colSql in [
      'ALTER TABLE sale_items ADD COLUMN batch_id INTEGER;',
      'ALTER TABLE sale_items ADD COLUMN batch_number TEXT;',
      'ALTER TABLE sale_items ADD COLUMN unit TEXT DEFAULT "Unit";',
      'ALTER TABLE sale_items ADD COLUMN line_note TEXT;',
      'ALTER TABLE sale_items ADD COLUMN discount_amount REAL DEFAULT 0.0;',
      'ALTER TABLE sale_items ADD COLUMN tax_rate REAL DEFAULT 0.0;',
      'ALTER TABLE sale_items ADD COLUMN hsn_code TEXT;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }
  }

  /// Ensures Phase 4.4 (Reports, Settings, Printer SSEZNIK2POS, Backups & User Access Management) tables & columns
  Future<void> ensurePhase4_4SchemaTables() async {
    // 1. Users table for role-based authentication and operational staff
    await customStatement('''
      CREATE TABLE IF NOT EXISTS users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        username TEXT NOT NULL UNIQUE,
        email TEXT,
        phone TEXT NOT NULL,
        role TEXT NOT NULL DEFAULT 'cashier',
        is_active INTEGER NOT NULL DEFAULT 1,
        password_hash TEXT,
        pin_hash TEXT,
        salt TEXT NOT NULL,
        last_login_at INTEGER,
        created_at INTEGER NOT NULL,
        updated_at INTEGER
      );
    ''');

    // 2. User activity logs & audit trails
    await customStatement('''
      CREATE TABLE IF NOT EXISTS user_activity_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        user_id INTEGER,
        username TEXT NOT NULL,
        module TEXT NOT NULL,
        action TEXT NOT NULL,
        details TEXT NOT NULL,
        ip_address TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    // 3. Database backups history and verification table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS backup_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        filename TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER NOT NULL,
        record_count INTEGER NOT NULL,
        checksum TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'valid',
        created_at INTEGER NOT NULL
      );
    ''');

    // 4. Non-destructive column expansion for workspaces
    for (final colSql in [
      'ALTER TABLE workspaces ADD COLUMN email TEXT DEFAULT "darvigroups@gmail.com";',
      'ALTER TABLE workspaces ADD COLUMN state TEXT DEFAULT "Karnataka";',
      'ALTER TABLE workspaces ADD COLUMN state_code TEXT DEFAULT "29";',
      'ALTER TABLE workspaces ADD COLUMN invoice_prefix TEXT DEFAULT "DARVI-";',
      'ALTER TABLE workspaces ADD COLUMN invoice_suffix TEXT DEFAULT "";',
      'ALTER TABLE workspaces ADD COLUMN next_invoice_number INTEGER DEFAULT 1001;',
      'ALTER TABLE workspaces ADD COLUMN payment_terms TEXT DEFAULT "Immediate";',
      'ALTER TABLE workspaces ADD COLUMN round_off_mode TEXT DEFAULT "nearest";',
      'ALTER TABLE workspaces ADD COLUMN printer_name TEXT DEFAULT "SSEZNIK2POS";',
      'ALTER TABLE workspaces ADD COLUMN printer_mac TEXT;',
      'ALTER TABLE workspaces ADD COLUMN paper_width_mm INTEGER DEFAULT 58;',
      'ALTER TABLE workspaces ADD COLUMN reprint_count INTEGER DEFAULT 1;',
      'ALTER TABLE workspaces ADD COLUMN logo_path TEXT DEFAULT "assets/darvi_logo.png";',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }
  }

  /// Vikshha CRM & Plot Management Schema Expansion (Group 1 to Group 6)
  Future<void> ensureVikshhaCrmSchemaTables() async {
    // 0. Ensure core Vikshha Farmlands & CRM tables exist
    await customStatement('''
      CREATE TABLE IF NOT EXISTS projects (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        code TEXT NOT NULL UNIQUE,
        location TEXT NOT NULL,
        total_area REAL NOT NULL DEFAULT 0.0,
        total_plots INTEGER NOT NULL DEFAULT 0,
        description TEXT,
        amenities TEXT,
        legal_status TEXT DEFAULT 'clear_title',
        address TEXT,
        gps_coordinates TEXT,
        status TEXT NOT NULL DEFAULT 'active',
        created_at INTEGER NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS plots (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        project_id INTEGER NOT NULL,
        plot_number TEXT NOT NULL,
        unique_plot_id TEXT NOT NULL UNIQUE,
        dimensions TEXT NOT NULL,
        area_sq_ft REAL NOT NULL,
        survey_number TEXT,
        facing TEXT DEFAULT 'East',
        price_per_sq_ft REAL DEFAULT 0.0,
        status TEXT NOT NULL DEFAULT 'available',
        base_price REAL NOT NULL,
        total_price REAL NOT NULL,
        crop_type TEXT,
        plantation_details TEXT,
        image_path TEXT,
        document_path TEXT,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS leads (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        alternate_phone TEXT,
        email TEXT,
        address TEXT,
        city TEXT,
        district TEXT,
        source TEXT NOT NULL DEFAULT 'Walk-in',
        priority TEXT NOT NULL DEFAULT 'medium',
        interested_project_id INTEGER,
        interested_plot_id INTEGER,
        interested_plot_size TEXT,
        budget REAL NOT NULL DEFAULT 0.0,
        requirements TEXT,
        stage TEXT NOT NULL DEFAULT 'new',
        assigned_employee_id INTEGER,
        next_follow_up_date INTEGER,
        notes TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS site_visits (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        lead_id INTEGER NOT NULL,
        project_id INTEGER,
        plot_id INTEGER,
        scheduled_date INTEGER NOT NULL,
        conducted_by_employee_id INTEGER,
        feedback TEXT,
        status TEXT NOT NULL DEFAULT 'scheduled',
        created_at INTEGER NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS lead_activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        lead_id INTEGER NOT NULL,
        employee_id INTEGER,
        activity_type TEXT NOT NULL,
        notes TEXT NOT NULL,
        created_at INTEGER NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS quotations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        quotation_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER,
        lead_id INTEGER,
        customer_name TEXT NOT NULL,
        customer_phone TEXT NOT NULL,
        quotation_date INTEGER NOT NULL,
        valid_until INTEGER NOT NULL,
        subtotal REAL NOT NULL,
        discount_total REAL NOT NULL DEFAULT 0.0,
        tax_total REAL NOT NULL DEFAULT 0.0,
        cgst_total REAL NOT NULL DEFAULT 0.0,
        sgst_total REAL NOT NULL DEFAULT 0.0,
        igst_total REAL NOT NULL DEFAULT 0.0,
        total_amount REAL NOT NULL,
        status TEXT NOT NULL DEFAULT 'draft',
        terms TEXT,
        notes TEXT,
        converted_reference_type TEXT,
        converted_reference_id INTEGER,
        created_at INTEGER NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS quotation_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        quotation_id INTEGER NOT NULL,
        item_type TEXT NOT NULL DEFAULT 'product',
        reference_id INTEGER,
        description TEXT NOT NULL,
        quantity REAL NOT NULL DEFAULT 1.0,
        unit_price REAL NOT NULL,
        discount REAL NOT NULL DEFAULT 0.0,
        gst_rate REAL NOT NULL DEFAULT 0.0,
        total REAL NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS plot_bookings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        booking_number TEXT NOT NULL UNIQUE,
        plot_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        lead_id INTEGER,
        employee_id INTEGER,
        booking_date INTEGER NOT NULL,
        total_plot_value REAL NOT NULL,
        booking_amount REAL NOT NULL,
        payment_account_id INTEGER,
        payment_mode TEXT NOT NULL DEFAULT 'upi',
        reference_no TEXT,
        status TEXT NOT NULL DEFAULT 'booked',
        cancellation_reason TEXT,
        refund_amount REAL NOT NULL DEFAULT 0.0,
        refund_account_id INTEGER,
        refund_date INTEGER,
        reservation_amount REAL DEFAULT 0.0,
        reservation_expiry INTEGER,
        discount REAL DEFAULT 0.0,
        agreement_status TEXT DEFAULT 'draft',
        notes TEXT,
        created_at INTEGER NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS booking_installments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        booking_id INTEGER NOT NULL,
        installment_number INTEGER NOT NULL,
        title TEXT NOT NULL,
        due_date INTEGER NOT NULL,
        amount REAL NOT NULL,
        paid_amount REAL NOT NULL DEFAULT 0.0,
        paid_date INTEGER
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS delivery_orders (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        order_number TEXT NOT NULL UNIQUE,
        sale_id INTEGER NOT NULL,
        customer_id INTEGER NOT NULL,
        delivery_address TEXT NOT NULL,
        contact_phone TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        tracking_number TEXT,
        carrier TEXT,
        shipping_notes TEXT,
        delivered_at INTEGER,
        created_at INTEGER NOT NULL
      );
    ''');

    await customStatement('''
      CREATE TABLE IF NOT EXISTS delivery_order_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        delivery_order_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        product_name TEXT NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_price REAL NOT NULL
      );
    ''');

    // 1. Follow-up Tracking Table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS crm_follow_ups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        lead_id INTEGER REFERENCES leads(id) ON DELETE CASCADE,
        customer_id INTEGER REFERENCES customers(id) ON DELETE SET NULL,
        employee_id INTEGER REFERENCES employees(id) ON DELETE SET NULL,
        scheduled_date INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        remarks TEXT,
        created_at INTEGER NOT NULL,
        completed_at INTEGER
      );
    ''');

    // 2. Vikshha CRM Documents & Agreements Table
    await customStatement('''
      CREATE TABLE IF NOT EXISTS crm_documents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        workspace_id INTEGER NOT NULL DEFAULT 1,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        document_type TEXT NOT NULL,
        title TEXT NOT NULL,
        file_path TEXT NOT NULL,
        file_size INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT 'active',
        uploaded_by INTEGER REFERENCES employees(id) ON DELETE SET NULL,
        created_at INTEGER NOT NULL
      );
    ''');

    // 3. Non-destructive column expansion for leads
    for (final colSql in [
      'ALTER TABLE leads ADD COLUMN alternate_phone TEXT;',
      'ALTER TABLE leads ADD COLUMN address TEXT;',
      'ALTER TABLE leads ADD COLUMN city TEXT;',
      'ALTER TABLE leads ADD COLUMN district TEXT;',
      "ALTER TABLE leads ADD COLUMN priority TEXT NOT NULL DEFAULT 'medium';",
      'ALTER TABLE leads ADD COLUMN interested_plot_size TEXT;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 4. Non-destructive column expansion for projects
    for (final colSql in [
      'ALTER TABLE projects ADD COLUMN amenities TEXT;',
      "ALTER TABLE projects ADD COLUMN legal_status TEXT DEFAULT 'clear_title';",
      'ALTER TABLE projects ADD COLUMN address TEXT;',
      'ALTER TABLE projects ADD COLUMN gps_coordinates TEXT;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 5. Non-destructive column expansion for plots
    for (final colSql in [
      "ALTER TABLE plots ADD COLUMN facing TEXT DEFAULT 'East';",
      'ALTER TABLE plots ADD COLUMN price_per_sq_ft REAL DEFAULT 0.0;',
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }

    // 6. Non-destructive column expansion for plot_bookings
    for (final colSql in [
      'ALTER TABLE plot_bookings ADD COLUMN reservation_amount REAL DEFAULT 0.0;',
      'ALTER TABLE plot_bookings ADD COLUMN reservation_expiry INTEGER;',
      'ALTER TABLE plot_bookings ADD COLUMN discount REAL DEFAULT 0.0;',
      "ALTER TABLE plot_bookings ADD COLUMN agreement_status TEXT DEFAULT 'draft';",
    ]) {
      try {
        await customStatement(colSql);
      } catch (_) {}
    }
  }

  /// Automatically sanitizes and repairs SQLite DateTime columns that might have been
  /// written as ISO-8601 strings, converting them into standard Unix timestamp integers.
  Future<void> sanitizeDateTimeColumns() async {
    // Dynamic universal schema sweep: find ALL tables and ALL columns containing date/time strings
    try {
      final tables = await customSelect(
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%';",
      ).get();

      for (final table in tables) {
        final tName = table.data['name'] as String;
        final colInfo = await customSelect("PRAGMA table_info('$tName');").get();
        for (final c in colInfo) {
          final cName = c.data['name'] as String;
          final cType = (c.data['type'] as String? ?? '').toUpperCase();
          final lower = cName.toLowerCase();

          // Only target columns intended for dates or timestamps
          final isDateColumn = lower.endsWith('_at') ||
              lower.endsWith('_date') ||
              lower.contains('date') ||
              lower.contains('time') ||
              cType == 'DATETIME' ||
              cType == 'TIMESTAMP';

          if (isDateColumn) {
            try {
              await customStatement('''
                UPDATE "$tName"
                SET "$cName" = CASE 
                  WHEN "$cName" GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*'
                    THEN COALESCE(CAST(strftime('%s', "$cName") AS INTEGER), CAST(strftime('%s', 'now') AS INTEGER))
                  WHEN typeof("$cName") = 'text' THEN CAST("$cName" AS INTEGER)
                  ELSE "$cName"
                END
                WHERE "$cName" GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' OR (typeof("$cName") = 'text' AND "$cName" GLOB '[0-9]*');
              ''');
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'mini_pos_inventory.sqlite'));

    // Automatic pre-migration backup
    if (await file.exists()) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final backupFile = File(p.join(dbFolder.path, 'mini_pos_inventory_backup_v2_$timestamp.sqlite'));
      try {
        await file.copy(backupFile.path);
      } catch (_) {
        // Filesystem lock fallback
      }
    }

    return NativeDatabase(file);
  });
}
