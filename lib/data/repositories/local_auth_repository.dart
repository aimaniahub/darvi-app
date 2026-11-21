import 'package:drift/drift.dart';

import '../../core/errors/app_exception.dart';
import '../../core/models/app_models.dart';
import '../../domain/entities/app_entities.dart';
import '../../domain/repositories/repositories.dart';
import '../local/db/app_database.dart';

class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(this._db);

  final AppDatabase _db;

  @override
  Future<UserRole?> loginAsAdmin(String password) async {
    // 1. Try to check users table for admin user with salted hash
    try {
      final rows = await _db.customSelect(
        'SELECT * FROM users WHERE (username = "admin" OR role = "admin") AND is_active = 1 LIMIT 1',
      ).get();

      if (rows.isNotEmpty) {
        final data = rows.first.data;
        final salt = data['salt'] as String? ?? '';
        final storedHash = data['password_hash'] as String?;
        if (storedHash != null) {
          final verifyResult = HashHelper.verify(password, storedHash, legacySalt: salt);
          if (verifyResult.isValid) {
            final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            if (verifyResult.needsRehash) {
              final newHash = HashHelper.hashPassword(password);
              await _db.customStatement('UPDATE users SET password_hash = ?, last_login_at = ? WHERE id = ?', [newHash, nowSeconds, data['id']]);
            } else {
              await _db.customStatement('UPDATE users SET last_login_at = ? WHERE id = ?', [nowSeconds, data['id']]);
            }
            await logActivity(
              userId: data['id'] as int?,
              username: data['username'] as String? ?? 'admin',
              module: 'auth',
              action: 'login',
              details: 'Administrator logged in with password credentials',
            );
            return UserRole.admin;
          }
        }
      }
    } catch (_) {}

    // 2. Legacy fallback to app_settings table
    final settings = await _settings();
    if (settings.adminPassword == password) {
      return UserRole.admin;
    }
    return null;
  }

  @override
  Future<UserRole?> loginWithPin(String pin) async {
    // 1. Try to check users table for matching PIN
    try {
      final rows = await _db.customSelect('SELECT * FROM users WHERE is_active = 1').get();
      for (final row in rows) {
        final data = row.data;
        final salt = data['salt'] as String? ?? '';
        final storedPinHash = data['pin_hash'] as String?;
        if (storedPinHash != null) {
          final verifyResult = HashHelper.verify(pin.trim(), storedPinHash, legacySalt: salt);
          if (verifyResult.isValid) {
            final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
            if (verifyResult.needsRehash) {
              final newHash = HashHelper.hashPin(pin.trim());
              await _db.customStatement('UPDATE users SET pin_hash = ?, last_login_at = ? WHERE id = ?', [newHash, nowSeconds, data['id']]);
            } else {
              await _db.customStatement('UPDATE users SET last_login_at = ? WHERE id = ?', [nowSeconds, data['id']]);
            }
            final roleStr = data['role'] as String? ?? 'cashier';
            await logActivity(
              userId: data['id'] as int?,
              username: data['username'] as String? ?? 'user',
              module: 'auth',
              action: 'pin_login',
              details: 'User logged in via Quick PIN',
            );
            return UserRoleX.fromValue(roleStr);
          }
        }
      }
    } catch (_) {}

    // 2. Legacy fallback to app_settings table
    final settings = await _settings();
    if (settings.cashierPin == pin) {
      return UserRole.cashier;
    }
    return null;
  }

  @override
  Future<AuthSession?> loginWithCredentials(String username, String password) async {
    final rows = await _db.customSelect(
      'SELECT * FROM users WHERE username = ? LIMIT 1',
      variables: [Variable.withString(username.trim().toLowerCase())],
    ).get();

    if (rows.isEmpty) {
      throw AppException('User not found. Please verify username.');
    }

    final data = rows.first.data;
    final isActive = (data['is_active'] as num? ?? 1) == 1;
    if (!isActive) {
      throw AppException('Account deactivated. Please contact your system administrator.');
    }

    final salt = data['salt'] as String? ?? '';
    final storedHash = data['password_hash'] as String?;

    if (storedHash == null) {
      throw AppException('Invalid password. Access denied.');
    }

    final verifyResult = HashHelper.verify(password, storedHash, legacySalt: salt);
    if (!verifyResult.isValid) {
      throw AppException('Invalid password. Access denied.');
    }

    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (verifyResult.needsRehash) {
      final newHash = HashHelper.hashPassword(password);
      await _db.customStatement('UPDATE users SET password_hash = ?, last_login_at = ? WHERE id = ?', [newHash, nowSeconds, data['id']]);
    } else {
      await _db.customStatement('UPDATE users SET last_login_at = ? WHERE id = ?', [nowSeconds, data['id']]);
    }

    final role = UserRoleX.fromValue(data['role'] as String? ?? 'cashier');
    final session = AuthSession(
      role: role,
      loginTime: DateTime.now(),
      userId: data['id'] as int?,
      username: data['username'] as String?,
      displayName: data['name'] as String?,
    );

    await logActivity(
      userId: data['id'] as int?,
      username: data['username'] as String? ?? username,
      module: 'auth',
      action: 'login',
      details: 'Successful username/password authentication as ${role.displayName}',
    );

    return session;
  }

  @override
  Future<AuthSession?> loginWithUserPin(String pin) async {
    final rows = await _db.customSelect('SELECT * FROM users WHERE is_active = 1').get();

    for (final row in rows) {
      final data = row.data;
      final salt = data['salt'] as String? ?? '';
      final storedPinHash = data['pin_hash'] as String?;

      if (storedPinHash != null) {
        final verifyResult = HashHelper.verify(pin.trim(), storedPinHash, legacySalt: salt);
        if (verifyResult.isValid) {
          final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
          if (verifyResult.needsRehash) {
            final newHash = HashHelper.hashPin(pin.trim());
            await _db.customStatement('UPDATE users SET pin_hash = ?, last_login_at = ? WHERE id = ?', [newHash, nowSeconds, data['id']]);
          } else {
            await _db.customStatement('UPDATE users SET last_login_at = ? WHERE id = ?', [nowSeconds, data['id']]);
          }

          final role = UserRoleX.fromValue(data['role'] as String? ?? 'cashier');
          final session = AuthSession(
            role: role,
            loginTime: DateTime.now(),
            userId: data['id'] as int?,
            username: data['username'] as String?,
            displayName: data['name'] as String?,
          );

          await logActivity(
            userId: data['id'] as int?,
            username: data['username'] as String? ?? 'user',
            module: 'auth',
            action: 'pin_login',
            details: 'PIN authenticated as ${role.displayName}',
          );

          return session;
        }
      }
    }

    // Fallback to settings cashier PIN
    final settings = await _settings();
    if (settings.cashierPin == pin.trim()) {
      return AuthSession(
        role: UserRole.cashier,
        loginTime: DateTime.now(),
        username: 'cashier',
        displayName: 'Cashier Staff',
      );
    }

    throw AppException('Invalid PIN. Access denied.');
  }

  @override
  Future<List<UserModel>> getUsers({int workspaceId = 1}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM users WHERE workspace_id = ? ORDER BY id ASC',
      variables: [Variable.withInt(workspaceId)],
    ).get();

    return rows.map((r) {
      final d = r.data;
      return UserModel(
        id: d['id'] as int,
        workspaceId: d['workspace_id'] as int? ?? 1,
        name: d['name'] as String? ?? '',
        username: d['username'] as String? ?? '',
        email: d['email'] as String?,
        phone: d['phone'] as String? ?? '',
        role: d['role'] as String? ?? 'cashier',
        isActive: (d['is_active'] as num? ?? 1) == 1,
        lastLoginAt: d['last_login_at'] != null ? DateTime.fromMillisecondsSinceEpoch((d['last_login_at'] as int) * 1000) : null,
        createdAt: DateTime.fromMillisecondsSinceEpoch(((d['created_at'] as int?) ?? 0) * 1000),
        updatedAt: d['updated_at'] != null ? DateTime.fromMillisecondsSinceEpoch((d['updated_at'] as int) * 1000) : null,
      );
    }).toList();
  }

  @override
  Future<UserModel?> getUserById(int id) async {
    final rows = await _db.customSelect(
      'SELECT * FROM users WHERE id = ? LIMIT 1',
      variables: [Variable.withInt(id)],
    ).get();

    if (rows.isEmpty) return null;
    final d = rows.first.data;
    return UserModel(
      id: d['id'] as int,
      workspaceId: d['workspace_id'] as int? ?? 1,
      name: d['name'] as String? ?? '',
      username: d['username'] as String? ?? '',
      email: d['email'] as String?,
      phone: d['phone'] as String? ?? '',
      role: d['role'] as String? ?? 'cashier',
      isActive: (d['is_active'] as num? ?? 1) == 1,
      lastLoginAt: d['last_login_at'] != null ? DateTime.fromMillisecondsSinceEpoch((d['last_login_at'] as int) * 1000) : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(((d['created_at'] as int?) ?? 0) * 1000),
      updatedAt: d['updated_at'] != null ? DateTime.fromMillisecondsSinceEpoch((d['updated_at'] as int) * 1000) : null,
    );
  }

  @override
  Future<int> createUser(UserModel user, {String? password, String? pin}) async {
    // Check for duplicate username
    final existing = await _db.customSelect(
      'SELECT id FROM users WHERE username = ? LIMIT 1',
      variables: [Variable.withString(user.username.trim().toLowerCase())],
    ).get();

    if (existing.isNotEmpty) {
      throw AppException('A user with username "${user.username}" already exists.');
    }

    final salt = HashHelper.generateSalt();
    final pwdHash = password != null && password.isNotEmpty ? HashHelper.hashPassword(password, salt: salt) : null;
    final pinHash = pin != null && pin.isNotEmpty ? HashHelper.hashPin(pin, salt: salt) : null;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final id = await _db.customInsert(
      '''
      INSERT INTO users (workspace_id, name, username, email, phone, role, is_active, password_hash, pin_hash, salt, created_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      variables: [
        Variable.withInt(user.workspaceId),
        Variable.withString(user.name.trim()),
        Variable.withString(user.username.trim().toLowerCase()),
        Variable.withString(user.email?.trim() ?? ''),
        Variable.withString(user.phone.trim()),
        Variable.withString(user.role),
        Variable.withInt(user.isActive ? 1 : 0),
        Variable.withString(pwdHash ?? ''),
        Variable.withString(pinHash ?? ''),
        Variable.withString(salt),
        Variable.withInt(nowSeconds),
      ],
    );

    await logActivity(
      userId: id,
      username: user.username,
      module: 'users',
      action: 'create',
      details: 'Created new user "${user.name}" with role ${user.role}',
    );

    return id;
  }

  @override
  Future<void> updateUser(UserModel user) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.customStatement(
      '''
      UPDATE users 
      SET name = ?, email = ?, phone = ?, role = ?, is_active = ?, updated_at = ?
      WHERE id = ?
      ''',
      [user.name.trim(), user.email?.trim() ?? '', user.phone.trim(), user.role, user.isActive ? 1 : 0, nowSeconds, user.id],
    );

    await logActivity(
      userId: user.id,
      username: user.username,
      module: 'users',
      action: 'update',
      details: 'Updated profile/role for user "${user.name}" (${user.role})',
    );
  }

  @override
  Future<void> setUserActive(int id, bool isActive) async {
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _db.customStatement(
      'UPDATE users SET is_active = ?, updated_at = ? WHERE id = ?',
      [isActive ? 1 : 0, nowSeconds, id],
    );

    final user = await getUserById(id);
    await logActivity(
      userId: id,
      username: user?.username ?? 'user#$id',
      module: 'users',
      action: isActive ? 'activate' : 'deactivate',
      details: 'Changed status of user #${user?.username ?? id} to ${isActive ? "ACTIVE" : "INACTIVE"}',
    );
  }

  @override
  Future<void> resetCredentials(int id, {String? password, String? pin}) async {
    final user = await getUserById(id);
    if (user == null) throw AppException('User not found.');

    final salt = HashHelper.generateSalt();
    final pwdHash = password != null && password.isNotEmpty ? HashHelper.hashPassword(password, salt: salt) : null;
    final pinHash = pin != null && pin.isNotEmpty ? HashHelper.hashPin(pin, salt: salt) : null;
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    if (pwdHash != null && pinHash != null) {
      await _db.customStatement(
        'UPDATE users SET password_hash = ?, pin_hash = ?, salt = ?, updated_at = ? WHERE id = ?',
        [pwdHash, pinHash, salt, nowSeconds, id],
      );
    } else if (pwdHash != null) {
      await _db.customStatement(
        'UPDATE users SET password_hash = ?, salt = ?, updated_at = ? WHERE id = ?',
        [pwdHash, salt, nowSeconds, id],
      );
    } else if (pinHash != null) {
      await _db.customStatement(
        'UPDATE users SET pin_hash = ?, salt = ?, updated_at = ? WHERE id = ?',
        [pinHash, salt, nowSeconds, id],
      );
    }

    await logActivity(
      userId: id,
      username: user.username,
      module: 'users',
      action: 'reset_credentials',
      details: 'Credentials securely updated (SHA-256 hashed with salt) for user "${user.name}"',
    );
  }

  @override
  Future<void> logActivity({
    int workspaceId = 1,
    int? userId,
    required String username,
    required String module,
    required String action,
    required String details,
    String? ipAddress,
  }) async {
    try {
      final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _db.customInsert(
        '''
        INSERT INTO user_activity_logs (workspace_id, user_id, username, module, action, details, ip_address, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
        ''',
        variables: [
          Variable.withInt(workspaceId),
          Variable.withInt(userId ?? 1),
          Variable.withString(username),
          Variable.withString(module),
          Variable.withString(action),
          Variable.withString(details),
          Variable.withString(ipAddress ?? '127.0.0.1'),
          Variable.withInt(nowSeconds),
        ],
      );
    } catch (_) {}
  }

  @override
  Future<List<UserActivityLog>> getActivityLogs({int workspaceId = 1, int limit = 100}) async {
    final rows = await _db.customSelect(
      'SELECT * FROM user_activity_logs WHERE workspace_id = ? ORDER BY created_at DESC LIMIT ?',
      variables: [Variable.withInt(workspaceId), Variable.withInt(limit)],
    ).get();

    return rows.map((r) {
      final d = r.data;
      return UserActivityLog(
        id: d['id'] as int,
        workspaceId: d['workspace_id'] as int? ?? 1,
        userId: d['user_id'] as int?,
        username: d['username'] as String? ?? 'system',
        module: d['module'] as String? ?? '',
        action: d['action'] as String? ?? '',
        details: d['details'] as String? ?? '',
        ipAddress: d['ip_address'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(((d['created_at'] as int?) ?? 0) * 1000),
      );
    }).toList();
  }

  @override
  Future<void> logout() async {
    await logActivity(
      username: 'user',
      module: 'auth',
      action: 'logout',
      details: 'User session closed / logged out',
    );
  }

  Future<AppSetting> _settings() async {
    final row = await (_db.select(_db.appSettings)..where((tbl) => tbl.id.equals(1))).getSingleOrNull();
    if (row != null) {
      return row;
    }
    throw AppException('Settings not found');
  }
}

