import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/models.dart';

class StoredSettings {
  const StoredSettings({
    this.profile,
    this.token = '',
    this.themeMode = ThemeMode.system,
  });
  final ConnectionProfile? profile;
  final String token;
  final ThemeMode themeMode;
}

abstract interface class SettingsStore {
  Future<StoredSettings> load();
  Future<void> saveConnection(ConnectionProfile profile, String token);
  Future<void> clearConnection();
  Future<void> saveTheme(ThemeMode mode);
}

class DeviceSettingsStore implements SettingsStore {
  static const _vault = FlutterSecureStorage();
  static const _profileKey = 'pc.connection.v1';
  static String _credentialKey(String address) =>
      'pc.token.${base64Url.encode(utf8.encode(address))}';

  @override
  Future<StoredSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    ConnectionProfile? profile;
    var token = '';
    if (raw != null) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      profile = ConnectionDraft.parse(
        name: json['name'] as String,
        address: json['baseUrl'] as String,
        token: '',
      ).profile;
      token = await _vault.read(key: _credentialKey(profile.baseUrl)) ?? '';
    }
    final name = prefs.getString('appearance') ?? 'system';
    return StoredSettings(
      profile: profile,
      token: token,
      themeMode: ThemeMode.values.firstWhere(
        (mode) => mode.name == name,
        orElse: () => ThemeMode.system,
      ),
    );
  }

  @override
  Future<void> saveConnection(ConnectionProfile profile, String token) async {
    final prefs = await SharedPreferences.getInstance();
    await _vault.write(key: _credentialKey(profile.baseUrl), value: token);
    await prefs.setString(_profileKey, profile.encode());
  }

  @override
  Future<void> clearConnection() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_profileKey);
    if (raw != null) {
      final json = jsonDecode(raw) as Map;
      await _vault.delete(key: _credentialKey(json['baseUrl'] as String));
    }
    await prefs.remove(_profileKey);
  }

  @override
  Future<void> saveTheme(ThemeMode mode) async {
    await (await SharedPreferences.getInstance()).setString(
      'appearance',
      mode.name,
    );
  }
}

/// Allows widget tests to exercise the app without platform channels or secrets.
class MemorySettingsStore implements SettingsStore {
  StoredSettings settings = const StoredSettings();
  @override
  Future<StoredSettings> load() async => settings;
  @override
  Future<void> saveConnection(ConnectionProfile profile, String token) async {
    settings = StoredSettings(
      profile: profile,
      token: token,
      themeMode: settings.themeMode,
    );
  }

  @override
  Future<void> clearConnection() async {
    settings = StoredSettings(themeMode: settings.themeMode);
  }

  @override
  Future<void> saveTheme(ThemeMode mode) async {
    settings = StoredSettings(
      profile: settings.profile,
      token: settings.token,
      themeMode: mode,
    );
  }
}
