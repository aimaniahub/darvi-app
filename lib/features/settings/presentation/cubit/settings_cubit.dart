import 'dart:io';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/models/app_models.dart';
import '../../../../core/services/receipt_pdf_service.dart';
import '../../../../core/services/thermal_printer_service.dart';
import '../../../../domain/repositories/repositories.dart';

class SettingsState extends Equatable {
  const SettingsState({
    this.loading = false,
    this.error,
    this.successMessage,
    this.selectedTab = 0,
    this.businessProfile = BusinessProfileModel.defaultDarvi,
    this.appSettings = AppSettingsModel.fallback,
    this.printerStatus = BluetoothPrinterStatus.disconnected,
    this.connectedPrinterAddress,
    this.pairedDevices = const [],
    this.backups = const [],
    this.users = const [],
    this.activityLogs = const [],
    this.selectedMatrixRole = UserRole.admin,
    this.searchUserQuery = '',
    this.selectedUserRoleFilter,
    this.isScanningDevices = false,
  });

  final bool loading;
  final String? error;
  final String? successMessage;
  final int selectedTab;
  final BusinessProfileModel businessProfile;
  final AppSettingsModel appSettings;
  final BluetoothPrinterStatus printerStatus;
  final String? connectedPrinterAddress;
  final List<BluetoothDeviceInfo> pairedDevices;
  final List<BackupRecord> backups;
  final List<UserModel> users;
  final List<UserActivityLog> activityLogs;
  final UserRole selectedMatrixRole;
  final String searchUserQuery;
  final String? selectedUserRoleFilter;
  final bool isScanningDevices;

  List<UserModel> get filteredUsers {
    return users.where((u) {
      if (searchUserQuery.isNotEmpty) {
        final q = searchUserQuery.toLowerCase();
        final matchName = u.name.toLowerCase().contains(q);
        final matchUsername = u.username.toLowerCase().contains(q);
        final matchPhone = u.phone.contains(q);
        if (!matchName && !matchUsername && !matchPhone) return false;
      }
      if (selectedUserRoleFilter != null && selectedUserRoleFilter!.isNotEmpty) {
        if (u.role != selectedUserRoleFilter) return false;
      }
      return true;
    }).toList();
  }

  SettingsState copyWith({
    bool? loading,
    String? error,
    bool clearError = false,
    String? successMessage,
    bool clearSuccess = false,
    int? selectedTab,
    BusinessProfileModel? businessProfile,
    AppSettingsModel? appSettings,
    BluetoothPrinterStatus? printerStatus,
    String? connectedPrinterAddress,
    bool clearPrinterAddress = false,
    List<BluetoothDeviceInfo>? pairedDevices,
    List<BackupRecord>? backups,
    List<UserModel>? users,
    List<UserActivityLog>? activityLogs,
    UserRole? selectedMatrixRole,
    String? searchUserQuery,
    String? selectedUserRoleFilter,
    bool clearRoleFilter = false,
    bool? isScanningDevices,
  }) {
    return SettingsState(
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      successMessage: clearSuccess ? null : successMessage ?? this.successMessage,
      selectedTab: selectedTab ?? this.selectedTab,
      businessProfile: businessProfile ?? this.businessProfile,
      appSettings: appSettings ?? this.appSettings,
      printerStatus: printerStatus ?? this.printerStatus,
      connectedPrinterAddress: clearPrinterAddress ? null : connectedPrinterAddress ?? this.connectedPrinterAddress,
      pairedDevices: pairedDevices ?? this.pairedDevices,
      backups: backups ?? this.backups,
      users: users ?? this.users,
      activityLogs: activityLogs ?? this.activityLogs,
      selectedMatrixRole: selectedMatrixRole ?? this.selectedMatrixRole,
      searchUserQuery: searchUserQuery ?? this.searchUserQuery,
      selectedUserRoleFilter: clearRoleFilter ? null : selectedUserRoleFilter ?? this.selectedUserRoleFilter,
      isScanningDevices: isScanningDevices ?? this.isScanningDevices,
    );
  }

  @override
  List<Object?> get props => [
        loading,
        error,
        successMessage,
        selectedTab,
        businessProfile,
        appSettings,
        printerStatus,
        connectedPrinterAddress,
        pairedDevices,
        backups,
        users,
        activityLogs,
        selectedMatrixRole,
        searchUserQuery,
        selectedUserRoleFilter,
        isScanningDevices,
      ];
}

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required SettingsRepository settingsRepository,
    required AuthRepository authRepository,
    required ReceiptPdfService receiptPdfService,
  })  : _settingsRepository = settingsRepository,
        _authRepository = authRepository,
        _receiptPdfService = receiptPdfService,
        super(const SettingsState());

  final SettingsRepository _settingsRepository;
  final AuthRepository _authRepository;
  final ReceiptPdfService _receiptPdfService;

  Future<void> load() async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      final appSettings = await _settingsRepository.getSettings();
      final businessProfile = await _settingsRepository.getBusinessProfile();
      final backups = await _settingsRepository.getBackupHistory();
      final users = await _authRepository.getUsers();
      final logs = await _authRepository.getActivityLogs(limit: 50);

      final printerService = _receiptPdfService.thermalPrinterService;
      final paired = await printerService.getPairedDevices();

      emit(
        state.copyWith(
          loading: false,
          appSettings: appSettings,
          businessProfile: businessProfile,
          backups: backups,
          users: users,
          activityLogs: logs,
          pairedDevices: paired,
          printerStatus: printerService.status,
          connectedPrinterAddress: printerService.connectedAddress,
        ),
      );
    } on AppException catch (e) {
      emit(state.copyWith(loading: false, error: e.message));
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  void selectTab(int index) {
    emit(state.copyWith(selectedTab: index, clearError: true, clearSuccess: true));
  }

  void selectMatrixRole(UserRole role) {
    emit(state.copyWith(selectedMatrixRole: role));
  }

  // Business Profile Updates
  Future<void> updateBusinessProfile(BusinessProfileModel profile) async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      await _settingsRepository.updateBusinessProfile(profile);
      await _authRepository.logActivity(
        username: 'admin',
        module: 'settings',
        action: 'update_business_profile',
        details: 'Updated business profile for ${profile.businessName}',
      );
      emit(
        state.copyWith(
          loading: false,
          businessProfile: profile,
          successMessage: 'Business Profile updated successfully!',
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  // Invoice & System Settings Updates
  Future<void> updateAppSettings(AppSettingsModel settings) async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      await _settingsRepository.updateSettings(settings);
      await _authRepository.logActivity(
        username: 'admin',
        module: 'settings',
        action: 'update_invoice_settings',
        details: 'Updated store & invoice configuration',
      );
      emit(
        state.copyWith(
          loading: false,
          appSettings: settings,
          successMessage: 'Invoice & System preferences saved!',
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  // SSEZNIK2POS Bluetooth Thermal Printer Management
  Future<void> scanBluetoothPrinters() async {
    emit(state.copyWith(isScanningDevices: true, clearError: true));
    try {
      final printerService = _receiptPdfService.thermalPrinterService;
      final paired = await printerService.getPairedDevices();
      emit(
        state.copyWith(
          isScanningDevices: false,
          pairedDevices: paired,
          printerStatus: printerService.status,
          connectedPrinterAddress: printerService.connectedAddress,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isScanningDevices: false, error: e.toString()));
    }
  }

  Future<void> connectPrinter(String address) async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      final printerService = _receiptPdfService.thermalPrinterService;
      final success = await printerService.connect(address);
      if (success) {
        emit(
          state.copyWith(
            loading: false,
            printerStatus: BluetoothPrinterStatus.connected,
            connectedPrinterAddress: address,
            successMessage: 'Connected to thermal printer at $address',
          ),
        );
      } else {
        emit(
          state.copyWith(
            loading: false,
            printerStatus: printerService.status,
            error: printerService.errorMessage ?? 'Failed to connect to printer',
          ),
        );
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> disconnectPrinter() async {
    final printerService = _receiptPdfService.thermalPrinterService;
    await printerService.disconnect();
    emit(
      state.copyWith(
        printerStatus: BluetoothPrinterStatus.disconnected,
        clearPrinterAddress: true,
        successMessage: 'Printer disconnected',
      ),
    );
  }

  Future<void> testPrint() async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      final success = await _receiptPdfService.printDiagnosticSelfTest();
      if (success) {
        emit(state.copyWith(loading: false, successMessage: 'Diagnostic test sent to printer!'));
      } else {
        final err = _receiptPdfService.thermalPrinterService.errorMessage ?? 'Printer is not connected';
        emit(state.copyWith(loading: false, error: err));
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  // Backup & Restore
  Future<void> createBackup() async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      final record = await _settingsRepository.createBackup();
      final backups = await _settingsRepository.getBackupHistory();
      await _authRepository.logActivity(
        username: 'admin',
        module: 'backup',
        action: 'create_backup',
        details: 'Created backup ${record.filename} with ${record.recordCount} records',
      );
      emit(
        state.copyWith(
          loading: false,
          backups: backups,
          successMessage: 'Backup created: ${record.filename} (${record.recordCount} records)',
        ),
      );
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> validateBackup(String filePath) async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      final isValid = await _settingsRepository.validateBackup(filePath);
      if (isValid) {
        emit(state.copyWith(loading: false, successMessage: 'Backup integrity verified (SHA-256 match)'));
      } else {
        emit(state.copyWith(loading: false, error: 'Backup validation failed! Checksum or data mismatch'));
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> restoreBackup(String filePath) async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      final success = await _settingsRepository.restoreBackup(filePath);
      if (success) {
        await _authRepository.logActivity(
          username: 'admin',
          module: 'backup',
          action: 'restore_backup',
          details: 'Restored database from $filePath',
        );
        emit(state.copyWith(loading: false, successMessage: 'Backup restored successfully!'));
        await load();
      } else {
        emit(state.copyWith(loading: false, error: 'Restore operation failed'));
      }
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> shareBackup(String filePath) async {
    final file = File(filePath);
    if (await file.exists()) {
      await Share.shareXFiles([XFile(filePath)], text: 'Darvi Billing Database Backup');
    } else {
      emit(state.copyWith(error: 'Backup file not found on disk: $filePath'));
    }
  }

  // Access Management & Users
  void filterUsers({String? query, String? roleFilter}) {
    emit(state.copyWith(
      searchUserQuery: query ?? state.searchUserQuery,
      selectedUserRoleFilter: roleFilter ?? state.selectedUserRoleFilter,
      clearRoleFilter: roleFilter == '',
    ));
  }

  Future<void> createUser({
    required String name,
    required String username,
    String? email,
    required String phone,
    required UserRole role,
    String? password,
    String? pin,
  }) async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      final user = UserModel(
        id: 0,
        workspaceId: 1,
        name: name,
        username: username,
        email: email,
        phone: phone,
        role: role.value,
        isActive: true,
        createdAt: DateTime.now(),
      );

      await _authRepository.createUser(
        user,
        password: password,
        pin: pin,
      );

      await _authRepository.logActivity(
        username: 'admin',
        module: 'access_management',
        action: 'create_user',
        details: 'Created user $username with role ${role.displayName}',
      );

      emit(state.copyWith(loading: false, successMessage: 'User $username created successfully!'));
      await load();
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> updateUser({
    required UserModel user,
  }) async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      await _authRepository.updateUser(user);

      await _authRepository.logActivity(
        username: 'admin',
        module: 'access_management',
        action: 'update_user',
        details: 'Updated user #${user.id} details and role to ${user.role}',
      );

      emit(state.copyWith(loading: false, successMessage: 'User updated successfully!'));
      await load();
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> toggleUserActive(int id, bool isActive) async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      await _authRepository.setUserActive(id, isActive);
      await _authRepository.logActivity(
        username: 'admin',
        module: 'access_management',
        action: isActive ? 'activate_user' : 'deactivate_user',
        details: '${isActive ? 'Activated' : 'Deactivated'} user #$id',
      );
      emit(state.copyWith(loading: false, successMessage: 'User status updated!'));
      await load();
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }

  Future<void> resetCredentials({
    required int id,
    String? newPassword,
    String? newPin,
  }) async {
    emit(state.copyWith(loading: true, clearError: true, clearSuccess: true));
    try {
      await _authRepository.resetCredentials(
        id,
        password: newPassword,
        pin: newPin,
      );

      await _authRepository.logActivity(
        username: 'admin',
        module: 'access_management',
        action: 'reset_credentials',
        details: 'Reset password/PIN for user #$id',
      );

      emit(state.copyWith(loading: false, successMessage: 'Credentials reset successfully!'));
      await load();
    } catch (e) {
      emit(state.copyWith(loading: false, error: e.toString()));
    }
  }
}
