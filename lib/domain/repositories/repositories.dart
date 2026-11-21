import '../../core/models/app_models.dart';
import '../entities/app_entities.dart';

class SaleCheckoutResult {
  const SaleCheckoutResult({
    required this.saleId,
    required this.invoiceNo,
    required this.total,
    required this.paid,
    required this.change,
  });

  final int saleId;
  final String invoiceNo;
  final double total;
  final double paid;
  final double change;
}

class ReturnResult {
  const ReturnResult({required this.returnSaleId, required this.invoiceNo});

  final int returnSaleId;
  final String invoiceNo;
}

class SalesReportRow {
  const SalesReportRow({
    required this.invoiceNo,
    required this.date,
    required this.total,
    required this.paymentMethod,
    required this.status,
  });

  final String invoiceNo;
  final DateTime date;
  final double total;
  final String paymentMethod;
  final String status;
}

class InventoryReportRow {
  const InventoryReportRow({
    required this.name,
    required this.sku,
    required this.category,
    required this.stock,
    required this.cost,
    required this.price,
    required this.lowStock,
  });

  final String name;
  final String sku;
  final String category;
  final int stock;
  final double cost;
  final double price;
  final bool lowStock;
}

abstract class AuthRepository {
  Future<UserRole?> loginWithPin(String pin);

  Future<UserRole?> loginAsAdmin(String password);

  Future<AuthSession?> loginWithCredentials(String username, String password);

  Future<AuthSession?> loginWithUserPin(String pin);

  Future<List<UserModel>> getUsers({int workspaceId = 1});

  Future<UserModel?> getUserById(int id);

  Future<int> createUser(UserModel user, {String? password, String? pin});

  Future<void> updateUser(UserModel user);

  Future<void> setUserActive(int id, bool isActive);

  Future<void> resetCredentials(int id, {String? password, String? pin});

  Future<void> logActivity({
    int workspaceId = 1,
    int? userId,
    required String username,
    required String module,
    required String action,
    required String details,
    String? ipAddress,
  });

  Future<List<UserActivityLog>> getActivityLogs({int workspaceId = 1, int limit = 100});

  Future<void> logout();
}

abstract class SettingsRepository {
  Future<AppSettingsModel> getSettings();

  Future<void> updateSettings(AppSettingsModel settings);

  Future<BusinessProfileModel> getBusinessProfile({int workspaceId = 1});

  Future<void> updateBusinessProfile(BusinessProfileModel profile);

  Future<BackupRecord> createBackup({int workspaceId = 1});

  Future<List<BackupRecord>> getBackupHistory({int workspaceId = 1});

  Future<bool> validateBackup(String filePath);

  Future<bool> restoreBackup(String filePath, {int workspaceId = 1});
}

abstract class ProductRepository {
  Future<List<ProductView>> getProducts({ProductFilter filter = const ProductFilter(), int workspaceId = 1});

  Future<List<ProductView>> getPopularProducts();

  Future<ProductView?> getProduct(int id, {int? workspaceId});

  Future<ProductView?> findByBarcode(String barcode);

  Future<int> upsertProduct(ProductUpsertInput input, {int workspaceId = 1, UserRole? callerRole});

  Future<bool> canDeleteProduct(int id);

  Future<void> deleteProduct(int id, {UserRole? callerRole});

  Future<void> archiveProduct(int id, bool isActive, {UserRole? callerRole});

  Future<List<CategoryModel>> getCategories();

  Future<int> addCategory(String name);

  Future<void> updateCategory(CategoryModel category);

  Future<void> deleteCategory(int id);

  Future<void> addStockMovement(StockMovementInput input);

  Future<List<StockMovementView>> getStockMovements({int? productId, int limit = 100, int workspaceId = 1});

  Future<List<ProductBatchView>> getBatches({int? productId, String? status, int workspaceId = 1});

  Future<int> addBatch(ProductBatchView batch);

  Future<void> adjustStock({
    required int productId,
    required int newQuantity,
    required String reason,
    int? batchId,
    UserRole? callerRole,
  });

  Future<void> writeOffStock({
    required int productId,
    required int quantity,
    required String reason,
    int? batchId,
    UserRole? callerRole,
  });

  Future<void> inwardStock({
    required int productId,
    required int quantity,
    required double costPrice,
    String? batchNumber,
    DateTime? expiryDate,
    int? supplierId,
    String? notes,
  });

  Future<List<ProductView>> getLowStockProducts({int workspaceId = 1});
}

abstract class SalesRepository {
  Future<SaleCheckoutResult> checkout(SaleCheckoutInput input);

  Future<List<SaleSummary>> getInvoices({InvoiceFilter filter = const InvoiceFilter(), int workspaceId = 1});

  Future<SaleDetailView?> getInvoiceDetail(int saleId, {int? workspaceId});

  Future<ReturnResult> returnItems({
    required int saleId,
    required List<ReturnItemInput> items,
    UserRole? callerRole,
  });

  Future<List<HeldBillModel>> getHeldBills({int workspaceId = 1});
  Future<int> saveHeldBill(HeldBillModel bill);
  Future<void> deleteHeldBill(int id);
}

abstract class ReportsRepository {
  Future<DashboardMetrics> getDashboardMetrics({int workspaceId = 1});

  Future<List<SalesByProductMetric>> salesByProduct({DateTime? from, DateTime? to, int workspaceId = 1});

  Future<List<ProductView>> lowStockProducts({int workspaceId = 1});

  Future<List<SalesReportRow>> salesReportRows({DateTime? from, DateTime? to, int workspaceId = 1});

  Future<List<InventoryReportRow>> inventoryReportRows({int workspaceId = 1});

  Future<ComprehensiveReportSummary> getComprehensiveSummary({DateTime? from, DateTime? to, int workspaceId = 1});

  Future<List<GstReportRow>> getGstReportRows({DateTime? from, DateTime? to, int workspaceId = 1});

  Future<List<FinancialTrialBalanceRow>> getFinancialTrialBalance({DateTime? from, DateTime? to, int workspaceId = 1});

  Future<List<PurchaseReportRow>> getPurchaseReportRows({DateTime? from, DateTime? to, int workspaceId = 1});

  Future<HrReportSummary> getHrReportSummary({int? month, int? year, int workspaceId = 1});
}

abstract class PartyRepository {
  Future<List<CustomerModel>> getCustomers({int workspaceId = 1, bool activeOnly = false});

  Future<CustomerModel?> getCustomerById(int id);

  Future<int> upsertCustomer({
    int? id,
    int workspaceId = 1,
    required String name,
    String? phone,
    String? notes,
    double balance = 0,
    String? gstin,
    String? address,
    double creditLimit = 10000.0,
    String? code,
    String? alternatePhone,
    String? email,
    String state = 'Karnataka',
    String customerType = 'individual',
    int creditPeriodDays = 30,
    bool isActive = true,
    double openingBalance = 0.0,
  });

  Future<void> deleteCustomer(int id);

  Future<List<SupplierModel>> getSuppliers({int workspaceId = 1, bool activeOnly = false});

  Future<SupplierModel?> getSupplierById(int id);

  Future<int> upsertSupplier({
    int? id,
    int workspaceId = 1,
    required String name,
    String? phone,
    String? gstin,
    String? address,
    double balance = 0,
    String? code,
    String? contactPerson,
    String? email,
    String state = 'Karnataka',
    String paymentTerms = '30 Days',
    bool isActive = true,
    double openingBalance = 0.0,
    String? notes,
  });

  Future<void> deleteSupplier(int id);

  Future<Map<String, dynamic>> getCustomerProfile(int customerId, {int workspaceId = 1});

  Future<Map<String, dynamic>> getSupplierProfile(int supplierId, {int workspaceId = 1});

  Future<void> recordCustomerCollection({
    int workspaceId = 1,
    required int customerId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
    List<Map<String, dynamic>>? invoiceAllocations,
  });

  Future<void> recordSupplierPayout({
    int workspaceId = 1,
    required int supplierId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
    List<Map<String, dynamic>>? invoiceAllocations,
  });

  Future<void> adjustPartyOpeningBalance({
    int workspaceId = 1,
    required String partyType,
    required int partyId,
    required double newOpeningBalance,
    required String reason,
  });
}

abstract class LedgerRepository {
  Future<void> postTransaction({
    int workspaceId = 1,
    required List<LedgerPostingItem> entries,
  });

  Future<double> getCustomerBalance(int customerId, {int workspaceId = 1});

  Future<double> getSupplierBalance(int supplierId, {int workspaceId = 1});

  Future<double> getAccountBalance(int accountId, {int workspaceId = 1});

  Future<List<LedgerEntryModel>> getCustomerStatement(
    int customerId, {
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<LedgerEntryModel>> getSupplierStatement(
    int supplierId, {
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<LedgerEntryModel>> getAccountStatement(
    int accountId, {
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<List<LedgerEntryModel>> getRecentLedgerEntries({
    int workspaceId = 1,
    int limit = 100,
    int? accountId,
    String? transactionType,
    DateTime? fromDate,
    DateTime? toDate,
    String? search,
  });

  Future<Map<String, dynamic>> reconcileBalances({int workspaceId = 1});
}

abstract class AccountRepository {
  Future<List<AccountModel>> getAccounts({int workspaceId = 1, bool activeOnly = true});

  Future<AccountModel?> getDefaultAccount({int workspaceId = 1});

  Future<int> createAccount({
    int workspaceId = 1,
    required String name,
    required String type,
    String? accountNumber,
    double initialBalance = 0,
    bool isDefault = false,
    String? bankName,
    String? ifsc,
    String? upiId,
  });

  Future<void> updateAccount({
    required int id,
    int workspaceId = 1,
    required String name,
    required String type,
    String? accountNumber,
    bool? isDefault,
    String? bankName,
    String? ifsc,
    String? upiId,
    bool? isActive,
  });

  Future<void> deactivateAccount(int id);

  Future<void> transferFunds({
    int workspaceId = 1,
    required int fromAccountId,
    required int toAccountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? transferDate,
  });

  Future<void> recordPayment({
    int workspaceId = 1,
    required String paymentType,
    int? customerId,
    int? supplierId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
  });

  Future<void> recordMoneyReceived({
    int workspaceId = 1,
    required int accountId,
    required double amount,
    required String category,
    int? customerId,
    String? referenceNo,
    String? description,
    DateTime? receiptDate,
  });

  Future<void> recordMoneyPaid({
    int workspaceId = 1,
    required int accountId,
    required double amount,
    required String category,
    int? supplierId,
    int? employeeId,
    String? referenceNo,
    String? description,
    DateTime? paymentDate,
  });

  Future<List<CashbookEntry>> getCashbookEntries({
    int workspaceId = 1,
    int? accountId,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<FinancialDashboardMetrics> getFinancialDashboardMetrics({
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  });

  Future<Map<String, dynamic>> getProfitAndLossReport({
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  });
}

abstract class PurchaseRepository {
  Future<int> createPurchaseInvoice(PurchaseInvoiceInput input);

  Future<List<Map<String, dynamic>>> getPurchaseInvoices({
    int workspaceId = 1,
    String? searchQuery,
    String? statusFilter,
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
  });

  Future<Map<String, dynamic>?> getPurchaseInvoiceDetail(int id);

  Future<void> editPurchaseInvoice(int id, PurchaseInvoiceInput input);

  Future<void> cancelPurchaseInvoice(int id, {String? reason});

  Future<void> recordPurchasePayment({
    required int purchaseInvoiceId,
    required int accountId,
    required double amount,
    String? referenceNo,
    String? narration,
    DateTime? paymentDate,
  });

  Future<int> createPurchaseReturn(PurchaseReturnInput input);

  Future<List<PurchaseReturnModel>> getPurchaseReturns({
    int workspaceId = 1,
    int? purchaseInvoiceId,
    int? supplierId,
  });

  Future<Map<String, dynamic>?> getPurchaseReturnDetail(int returnId);

  Future<PurchaseDashboardMetrics> getPurchaseDashboardMetrics({
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
    int? supplierId,
    String? paymentStatus,
  });

  Future<Map<String, dynamic>> getPurchaseReport({
    int workspaceId = 1,
    DateTime? fromDate,
    DateTime? toDate,
  });
}

abstract class ExpenseRepository {
  Future<List<ExpenseModel>> getExpenses({
    int workspaceId = 1,
    DateTime? from,
    DateTime? to,
    String? category,
    String? search,
  });

  Future<int> addExpense({
    int workspaceId = 1,
    required int accountId,
    required String category,
    required double amount,
    DateTime? expenseDate,
    String? referenceNo,
    String? notes,
    String? vendorPayee,
    double taxAmount = 0.0,
    String? attachmentUrl,
  });

  Future<void> updateExpense({
    required int id,
    int workspaceId = 1,
    required int accountId,
    required String category,
    required double amount,
    DateTime? expenseDate,
    String? referenceNo,
    String? notes,
    String? vendorPayee,
    double taxAmount = 0.0,
  });

  Future<void> deleteExpense(int id);

  Future<void> cancelExpense(int id, {String? reason});
}

abstract class EmployeeRepository {
  Future<List<EmployeeModel>> getEmployees({int workspaceId = 1, bool activeOnly = true, UserRole? callerRole});

  Future<EmployeeModel?> getEmployee(int id, {int? workspaceId, UserRole? callerRole});

  Future<EmployeeModel?> getEmployeeByPin(String pin);

  Future<int> upsertEmployee(EmployeeModel employee, {UserRole? callerRole});

  Future<void> setEmployeeStatus(int id, bool isActive, {UserRole? callerRole});

  Future<bool> canDeleteEmployee(int id);

  Future<void> deleteEmployee(int id, {UserRole? callerRole});

  // Shifts
  Future<List<ShiftModel>> getShifts({int workspaceId = 1});

  Future<int> saveShift(ShiftModel shift);

  Future<void> deleteShift(int id);

  // Attendance
  Future<List<AttendanceModel>> getAttendance({int workspaceId = 1, required DateTime date});

  Future<void> recordAttendance({
    int workspaceId = 1,
    required int employeeId,
    required DateTime date,
    DateTime? checkIn,
    DateTime? checkOut,
    String status = 'present',
    double workingHours = 8.0,
    String? notes,
    int? shiftId,
    int breakMinutes = 0,
    bool isLate = false,
    double overtimeHours = 0.0,
  });

  Future<void> correctAttendance({
    required int attendanceId,
    required String status,
    double? workingHours,
    DateTime? checkIn,
    DateTime? checkOut,
    required String reason,
    required String correctedBy,
  });

  Future<List<AttendanceSummaryModel>> getMonthlyAttendanceSummary({
    required int month,
    required int year,
    int workspaceId = 1,
  });

  // Leaves
  Future<List<LeaveRequestModel>> getLeaves({int? employeeId, int workspaceId = 1});

  Future<int> requestLeave(LeaveRequestModel leave);

  Future<void> approveLeave({
    required int leaveId,
    required bool approved,
    String? remarks,
    String? approvedBy,
  });

  // Holidays
  Future<List<HolidayModel>> getHolidays({int workspaceId = 1});

  Future<int> saveHoliday(HolidayModel holiday);

  // Payroll
  Future<List<PayrollRecordModel>> getPayrollRecords({int workspaceId = 1, int? month, int? year, UserRole? callerRole});

  Future<int> processPayroll({
    int workspaceId = 1,
    required int employeeId,
    required int month,
    required int year,
    required double basicSalary,
    double incentiveAmount = 0.0,
    double allowances = 0.0,
    double deductions = 0.0,
    String? notes,
    UserRole? callerRole,
  });

  Future<void> disbursePayroll({
    required int payrollId,
    required int fromAccountId,
    UserRole? callerRole,
  });

  // Sales Attribution & Targets
  Future<List<SalesTargetModel>> getSalesTargets({int? employeeId, int workspaceId = 1});

  Future<int> saveSalesTarget(SalesTargetModel target);

  Future<Map<String, dynamic>> calculateSalesAttributed({
    required int employeeId,
    required DateTime startDate,
    required DateTime endDate,
    int workspaceId = 1,
  });

  Future<double> calculateIncentivesFromSales({
    required int employeeId,
    required DateTime startDate,
    required DateTime endDate,
    int workspaceId = 1,
  });

  // Incentives
  Future<List<IncentiveRuleModel>> getIncentiveRules({int workspaceId = 1});

  Future<int> createIncentiveRule(IncentiveRuleModel rule);

  Future<List<IncentiveClaimModel>> getIncentiveClaims({int workspaceId = 1, String? status});

  Future<void> approveIncentiveClaim(int claimId, bool approve, {UserRole? callerRole});

  Future<void> payoutIncentiveClaim({
    required int claimId,
    required int fromAccountId,
    UserRole? callerRole,
  });

  Future<int> createIncentiveClaim(IncentiveClaimModel claim);

  Future<void> reverseIncentiveClaimForSale(int saleId, {UserRole? callerRole});
}

abstract class SyncService {
  Future<void> syncNow();
}

abstract class PrinterService {
  Future<void> printReceiptPdfBytes(List<int> bytes);
}

abstract class BarcodeScannerService {
  Future<String?> scanBarcode();
}

// -------------------------------------------------------------
// P3 BUSINESS EXTENSIONS REPOSITORY CONTRACTS
// -------------------------------------------------------------

abstract class PlotRepository {
  Future<List<dynamic>> getProjects({int workspaceId = 1});
  Future<Map<String, dynamic>> getProjectSummary(int projectId);
  Future<int> saveProject({
    int? id,
    int workspaceId = 1,
    required String name,
    required String code,
    required String location,
    double totalArea = 0.0,
    int totalPlots = 0,
    String? description,
    String? amenities,
    String? legalStatus,
    String? address,
    String? gpsCoordinates,
    String status = 'active',
  });
  Future<List<dynamic>> getPlots({
    int workspaceId = 1,
    int? projectId,
    String? status,
    String? facing,
    double? minPrice,
    double? maxPrice,
    String? query,
  });
  Future<dynamic> getPlotById(int plotId);
  Future<int> savePlot({
    int? id,
    int workspaceId = 1,
    required int projectId,
    required String plotNumber,
    required String uniquePlotId,
    required String dimensions,
    required double areaSqFt,
    String? surveyNumber,
    String? facing,
    double pricePerSqFt = 0.0,
    String status = 'available',
    required double basePrice,
    required double totalPrice,
    String? cropType,
    String? plantationDetails,
    String? imagePath,
    String? documentPath,
    String? notes,
  });
  Future<void> updatePlotStatus(int plotId, String status);
  Future<void> deletePlot(int plotId);
  Future<List<Map<String, dynamic>>> getPlotHistory(int plotId);
}

abstract class CrmRepository {
  Future<List<dynamic>> getLeads({
    int workspaceId = 1,
    String? stage,
    int? employeeId,
    String? source,
    String? priority,
    String? query,
  });
  Future<dynamic> getLeadById(int leadId);
  Future<dynamic> checkDuplicateLead({required String phone, int? excludeId, int workspaceId = 1});
  Future<int> saveLead({
    int? id,
    int workspaceId = 1,
    required String name,
    required String phone,
    String? alternatePhone,
    String? email,
    String? address,
    String? city,
    String? district,
    String source = 'Walk-in',
    String priority = 'medium',
    int? interestedProjectId,
    int? interestedPlotId,
    String? interestedPlotSize,
    double budget = 0.0,
    String? requirements,
    String stage = 'new',
    int? assignedEmployeeId,
    DateTime? nextFollowUpDate,
    String? notes,
  });
  Future<void> updateLeadStage(int leadId, String stage);
  Future<void> deleteLead(int leadId);
  Future<void> logLeadActivity({
    int workspaceId = 1,
    required int leadId,
    int? employeeId,
    required String activityType,
    required String notes,
  });
  Future<List<dynamic>> getLeadActivities(int leadId);
  Future<int> scheduleSiteVisit({
    int workspaceId = 1,
    required int leadId,
    int? projectId,
    int? plotId,
    required DateTime scheduledDate,
    int? conductedByEmployeeId,
    String? feedback,
    String status = 'scheduled',
  });
  Future<List<dynamic>> getSiteVisits({int workspaceId = 1, int? leadId, int? employeeId, String? status});
  Future<void> updateSiteVisitStatus(int visitId, String status, {String? feedback, DateTime? nextFollowUpDate});
  Future<int> convertLeadToCustomer(int leadId);
  Future<Map<String, dynamic>> getCustomerCrmProfile(int customerId);

  // Vikshha Follow-ups
  Future<int> createFollowUp({
    int workspaceId = 1,
    int? leadId,
    int? customerId,
    int? employeeId,
    required DateTime scheduledDate,
    String status = 'pending',
    String? remarks,
  });
  Future<List<Map<String, dynamic>>> getFollowUps({
    int workspaceId = 1,
    int? leadId,
    int? customerId,
    int? employeeId,
    String? status,
  });
  Future<void> updateFollowUpStatus(
    int followUpId,
    String status, {
    String? remarks,
    DateTime? rescheduleDate,
  });
  Future<int> getOverdueFollowUpsCount({int workspaceId = 1});

  // Vikshha CRM Documents
  Future<int> addDocument({
    int workspaceId = 1,
    required String entityType,
    required int entityId,
    required String documentType,
    required String title,
    required String filePath,
    int fileSize = 0,
    int? uploadedBy,
  });
  Future<List<Map<String, dynamic>>> getDocuments({
    int workspaceId = 1,
    required String entityType,
    required int entityId,
  });
  Future<void> deleteDocument(int documentId);
}

abstract class QuotationRepository {
  Future<List<dynamic>> getQuotations({int workspaceId = 1, String? status, String? query});
  Future<dynamic> getQuotationById(int quotationId);
  Future<List<dynamic>> getQuotationItems(int quotationId);
  Future<int> createQuotation({
    int workspaceId = 1,
    required String quotationNumber,
    int? customerId,
    int? leadId,
    required String customerName,
    required String customerPhone,
    required DateTime validUntil,
    required double subtotal,
    double discountTotal = 0.0,
    double taxTotal = 0.0,
    double cgstTotal = 0.0,
    double sgstTotal = 0.0,
    double igstTotal = 0.0,
    required double totalAmount,
    String status = 'draft',
    String? terms,
    String? notes,
    required List<Map<String, dynamic>> items,
  });
  Future<void> updateQuotationStatus(int quotationId, String status);
  Future<int> convertQuotationToSale({
    required int quotationId,
    required int accountId,
    required String paymentMode,
  });
}

abstract class BookingRepository {
  Future<List<dynamic>> getBookings({int workspaceId = 1, String? status, String? query});
  Future<dynamic> getBookingById(int bookingId);
  Future<List<dynamic>> getInstallments(int bookingId);
  Future<int> reservePlot({
    int workspaceId = 1,
    required int plotId,
    required int customerId,
    int? leadId,
    int? employeeId,
    required double totalPlotValue,
    required double reservationAmount,
    required int paymentAccountId,
    String paymentMode = 'upi',
    int expiryDays = 7,
    String? notes,
  });
  Future<int> createBooking({
    int workspaceId = 1,
    required String bookingNumber,
    required int plotId,
    required int customerId,
    int? leadId,
    int? employeeId,
    required double totalPlotValue,
    required double bookingAmount,
    double discount = 0.0,
    required int paymentAccountId,
    String paymentMode = 'upi',
    String? referenceNo,
    String? notes,
    required List<Map<String, dynamic>> installments,
  });
  Future<void> payInstallment({
    required int installmentId,
    required double amount,
    required int paymentAccountId,
    String paymentMode = 'upi',
    String? referenceNo,
  });
  Future<void> cancelBooking({
    required int bookingId,
    required String reason,
    required double refundAmount,
    required int refundAccountId,
  });
  Future<void> releaseExpiredReservations({int workspaceId = 1});
  Future<Map<String, dynamic>> getBookingStatement(int bookingId);
  Future<void> updateAgreementStatus(int bookingId, String agreementStatus);
  Future<int> claimSalesCommission({
    int workspaceId = 1,
    required int bookingId,
    required int employeeId,
    required double commissionRate, // percentage e.g. 2.0%
    String? remarks,
  });
}

abstract class DeliveryRepository {
  Future<List<dynamic>> getDeliveries({int workspaceId = 1, String? status, String? query});
  Future<dynamic> getDeliveryById(int deliveryId);
  Future<List<dynamic>> getDeliveryItems(int deliveryId);
  Future<int> createDelivery({
    int workspaceId = 1,
    required String deliveryNumber,
    int? saleId,
    required int customerId,
    required String deliveryAddress,
    String? transporterName,
    String? vehicleNumber,
    String? trackingNumber,
    double shippingCharges = 0.0,
    DateTime? dispatchDate,
    DateTime? expectedDeliveryDate,
    String status = 'pending',
    String? notes,
    required List<Map<String, dynamic>> items,
  });
  Future<void> updateDeliveryStatus({
    required int deliveryId,
    required String status,
    DateTime? deliveredDate,
    String? proofOfDelivery,
    String? notes,
  });
}
