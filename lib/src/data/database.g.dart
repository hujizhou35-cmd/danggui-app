// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $AppMetadataTable extends AppMetadata
    with TableInfo<$AppMetadataTable, AppMetaRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppMetadataTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _datasetIdMeta = const VerificationMeta(
    'datasetId',
  );
  @override
  late final GeneratedColumn<String> datasetId = GeneratedColumn<String>(
    'dataset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastIntegrityCheckAtUtcMeta =
      const VerificationMeta('lastIntegrityCheckAtUtc');
  @override
  late final GeneratedColumn<int> lastIntegrityCheckAtUtc =
      GeneratedColumn<int>(
        'last_integrity_check_at_utc',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _ftsModeMeta = const VerificationMeta(
    'ftsMode',
  );
  @override
  late final GeneratedColumn<String> ftsMode = GeneratedColumn<String>(
    'fts_mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('unknown'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    datasetId,
    createdAtUtc,
    lastIntegrityCheckAtUtc,
    ftsMode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppMetaRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('dataset_id')) {
      context.handle(
        _datasetIdMeta,
        datasetId.isAcceptableOrUnknown(data['dataset_id']!, _datasetIdMeta),
      );
    } else if (isInserting) {
      context.missing(_datasetIdMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('last_integrity_check_at_utc')) {
      context.handle(
        _lastIntegrityCheckAtUtcMeta,
        lastIntegrityCheckAtUtc.isAcceptableOrUnknown(
          data['last_integrity_check_at_utc']!,
          _lastIntegrityCheckAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('fts_mode')) {
      context.handle(
        _ftsModeMeta,
        ftsMode.isAcceptableOrUnknown(data['fts_mode']!, _ftsModeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppMetaRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppMetaRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      datasetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset_id'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      lastIntegrityCheckAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_integrity_check_at_utc'],
      ),
      ftsMode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}fts_mode'],
      )!,
    );
  }

  @override
  $AppMetadataTable createAlias(String alias) {
    return $AppMetadataTable(attachedDatabase, alias);
  }
}

class AppMetaRow extends DataClass implements Insertable<AppMetaRow> {
  final int id;
  final String datasetId;
  final int createdAtUtc;
  final int? lastIntegrityCheckAtUtc;
  final String ftsMode;
  const AppMetaRow({
    required this.id,
    required this.datasetId,
    required this.createdAtUtc,
    this.lastIntegrityCheckAtUtc,
    required this.ftsMode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['dataset_id'] = Variable<String>(datasetId);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || lastIntegrityCheckAtUtc != null) {
      map['last_integrity_check_at_utc'] = Variable<int>(
        lastIntegrityCheckAtUtc,
      );
    }
    map['fts_mode'] = Variable<String>(ftsMode);
    return map;
  }

  AppMetadataCompanion toCompanion(bool nullToAbsent) {
    return AppMetadataCompanion(
      id: Value(id),
      datasetId: Value(datasetId),
      createdAtUtc: Value(createdAtUtc),
      lastIntegrityCheckAtUtc: lastIntegrityCheckAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastIntegrityCheckAtUtc),
      ftsMode: Value(ftsMode),
    );
  }

  factory AppMetaRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppMetaRow(
      id: serializer.fromJson<int>(json['id']),
      datasetId: serializer.fromJson<String>(json['datasetId']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      lastIntegrityCheckAtUtc: serializer.fromJson<int?>(
        json['lastIntegrityCheckAtUtc'],
      ),
      ftsMode: serializer.fromJson<String>(json['ftsMode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'datasetId': serializer.toJson<String>(datasetId),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'lastIntegrityCheckAtUtc': serializer.toJson<int?>(
        lastIntegrityCheckAtUtc,
      ),
      'ftsMode': serializer.toJson<String>(ftsMode),
    };
  }

  AppMetaRow copyWith({
    int? id,
    String? datasetId,
    int? createdAtUtc,
    Value<int?> lastIntegrityCheckAtUtc = const Value.absent(),
    String? ftsMode,
  }) => AppMetaRow(
    id: id ?? this.id,
    datasetId: datasetId ?? this.datasetId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    lastIntegrityCheckAtUtc: lastIntegrityCheckAtUtc.present
        ? lastIntegrityCheckAtUtc.value
        : this.lastIntegrityCheckAtUtc,
    ftsMode: ftsMode ?? this.ftsMode,
  );
  AppMetaRow copyWithCompanion(AppMetadataCompanion data) {
    return AppMetaRow(
      id: data.id.present ? data.id.value : this.id,
      datasetId: data.datasetId.present ? data.datasetId.value : this.datasetId,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      lastIntegrityCheckAtUtc: data.lastIntegrityCheckAtUtc.present
          ? data.lastIntegrityCheckAtUtc.value
          : this.lastIntegrityCheckAtUtc,
      ftsMode: data.ftsMode.present ? data.ftsMode.value : this.ftsMode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppMetaRow(')
          ..write('id: $id, ')
          ..write('datasetId: $datasetId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('lastIntegrityCheckAtUtc: $lastIntegrityCheckAtUtc, ')
          ..write('ftsMode: $ftsMode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    datasetId,
    createdAtUtc,
    lastIntegrityCheckAtUtc,
    ftsMode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppMetaRow &&
          other.id == this.id &&
          other.datasetId == this.datasetId &&
          other.createdAtUtc == this.createdAtUtc &&
          other.lastIntegrityCheckAtUtc == this.lastIntegrityCheckAtUtc &&
          other.ftsMode == this.ftsMode);
}

class AppMetadataCompanion extends UpdateCompanion<AppMetaRow> {
  final Value<int> id;
  final Value<String> datasetId;
  final Value<int> createdAtUtc;
  final Value<int?> lastIntegrityCheckAtUtc;
  final Value<String> ftsMode;
  const AppMetadataCompanion({
    this.id = const Value.absent(),
    this.datasetId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.lastIntegrityCheckAtUtc = const Value.absent(),
    this.ftsMode = const Value.absent(),
  });
  AppMetadataCompanion.insert({
    this.id = const Value.absent(),
    required String datasetId,
    required int createdAtUtc,
    this.lastIntegrityCheckAtUtc = const Value.absent(),
    this.ftsMode = const Value.absent(),
  }) : datasetId = Value(datasetId),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<AppMetaRow> custom({
    Expression<int>? id,
    Expression<String>? datasetId,
    Expression<int>? createdAtUtc,
    Expression<int>? lastIntegrityCheckAtUtc,
    Expression<String>? ftsMode,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (datasetId != null) 'dataset_id': datasetId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (lastIntegrityCheckAtUtc != null)
        'last_integrity_check_at_utc': lastIntegrityCheckAtUtc,
      if (ftsMode != null) 'fts_mode': ftsMode,
    });
  }

  AppMetadataCompanion copyWith({
    Value<int>? id,
    Value<String>? datasetId,
    Value<int>? createdAtUtc,
    Value<int?>? lastIntegrityCheckAtUtc,
    Value<String>? ftsMode,
  }) {
    return AppMetadataCompanion(
      id: id ?? this.id,
      datasetId: datasetId ?? this.datasetId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      lastIntegrityCheckAtUtc:
          lastIntegrityCheckAtUtc ?? this.lastIntegrityCheckAtUtc,
      ftsMode: ftsMode ?? this.ftsMode,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (datasetId.present) {
      map['dataset_id'] = Variable<String>(datasetId.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (lastIntegrityCheckAtUtc.present) {
      map['last_integrity_check_at_utc'] = Variable<int>(
        lastIntegrityCheckAtUtc.value,
      );
    }
    if (ftsMode.present) {
      map['fts_mode'] = Variable<String>(ftsMode.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppMetadataCompanion(')
          ..write('id: $id, ')
          ..write('datasetId: $datasetId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('lastIntegrityCheckAtUtc: $lastIntegrityCheckAtUtc, ')
          ..write('ftsMode: $ftsMode')
          ..write(')'))
        .toString();
  }
}

class $AppSettingsTableTable extends AppSettingsTable
    with TableInfo<$AppSettingsTableTable, AppSettingsRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppSettingsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  late final GeneratedColumnWithTypeConverter<LocaleMode, String> localeMode =
      GeneratedColumn<String>(
        'locale_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<LocaleMode>($AppSettingsTableTable.$converterlocaleMode);
  @override
  late final GeneratedColumnWithTypeConverter<FontMode, String> fontMode =
      GeneratedColumn<String>(
        'font_mode',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<FontMode>($AppSettingsTableTable.$converterfontMode);
  static const VerificationMeta _textScalePercentMeta = const VerificationMeta(
    'textScalePercent',
  );
  @override
  late final GeneratedColumn<int> textScalePercent = GeneratedColumn<int>(
    'text_scale_percent',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DisplayDensity, String> density =
      GeneratedColumn<String>(
        'density',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DisplayDensity>($AppSettingsTableTable.$converterdensity);
  static const VerificationMeta _defaultSoundEnabledMeta =
      const VerificationMeta('defaultSoundEnabled');
  @override
  late final GeneratedColumn<bool> defaultSoundEnabled = GeneratedColumn<bool>(
    'default_sound_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("default_sound_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _defaultVibrationEnabledMeta =
      const VerificationMeta('defaultVibrationEnabled');
  @override
  late final GeneratedColumn<bool> defaultVibrationEnabled =
      GeneratedColumn<bool>(
        'default_vibration_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("default_vibration_enabled" IN (0, 1))',
        ),
      );
  static const VerificationMeta _defaultSnoozeMinutesMeta =
      const VerificationMeta('defaultSnoozeMinutes');
  @override
  late final GeneratedColumn<int> defaultSnoozeMinutes = GeneratedColumn<int>(
    'default_snooze_minutes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _autoBackupEnabledMeta = const VerificationMeta(
    'autoBackupEnabled',
  );
  @override
  late final GeneratedColumn<bool> autoBackupEnabled = GeneratedColumn<bool>(
    'auto_backup_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("auto_backup_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _autoBackupHourLocalMeta =
      const VerificationMeta('autoBackupHourLocal');
  @override
  late final GeneratedColumn<int> autoBackupHourLocal = GeneratedColumn<int>(
    'auto_backup_hour_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(2),
  );
  static const VerificationMeta _autoBackupMinuteLocalMeta =
      const VerificationMeta('autoBackupMinuteLocal');
  @override
  late final GeneratedColumn<int> autoBackupMinuteLocal = GeneratedColumn<int>(
    'auto_backup_minute_local',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _backupEncryptionEnabledMeta =
      const VerificationMeta('backupEncryptionEnabled');
  @override
  late final GeneratedColumn<bool> backupEncryptionEnabled =
      GeneratedColumn<bool>(
        'backup_encryption_enabled',
        aliasedName,
        false,
        type: DriftSqlType.bool,
        requiredDuringInsert: true,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("backup_encryption_enabled" IN (0, 1))',
        ),
      );
  static const VerificationMeta _helpSeenVersionMeta = const VerificationMeta(
    'helpSeenVersion',
  );
  @override
  late final GeneratedColumn<int> helpSeenVersion = GeneratedColumn<int>(
    'help_seen_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    localeMode,
    fontMode,
    textScalePercent,
    density,
    defaultSoundEnabled,
    defaultVibrationEnabled,
    defaultSnoozeMinutes,
    autoBackupEnabled,
    autoBackupHourLocal,
    autoBackupMinuteLocal,
    backupEncryptionEnabled,
    helpSeenVersion,
    updatedAtUtc,
    rowVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppSettingsRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('text_scale_percent')) {
      context.handle(
        _textScalePercentMeta,
        textScalePercent.isAcceptableOrUnknown(
          data['text_scale_percent']!,
          _textScalePercentMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_textScalePercentMeta);
    }
    if (data.containsKey('default_sound_enabled')) {
      context.handle(
        _defaultSoundEnabledMeta,
        defaultSoundEnabled.isAcceptableOrUnknown(
          data['default_sound_enabled']!,
          _defaultSoundEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultSoundEnabledMeta);
    }
    if (data.containsKey('default_vibration_enabled')) {
      context.handle(
        _defaultVibrationEnabledMeta,
        defaultVibrationEnabled.isAcceptableOrUnknown(
          data['default_vibration_enabled']!,
          _defaultVibrationEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultVibrationEnabledMeta);
    }
    if (data.containsKey('default_snooze_minutes')) {
      context.handle(
        _defaultSnoozeMinutesMeta,
        defaultSnoozeMinutes.isAcceptableOrUnknown(
          data['default_snooze_minutes']!,
          _defaultSnoozeMinutesMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_defaultSnoozeMinutesMeta);
    }
    if (data.containsKey('auto_backup_enabled')) {
      context.handle(
        _autoBackupEnabledMeta,
        autoBackupEnabled.isAcceptableOrUnknown(
          data['auto_backup_enabled']!,
          _autoBackupEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_autoBackupEnabledMeta);
    }
    if (data.containsKey('auto_backup_hour_local')) {
      context.handle(
        _autoBackupHourLocalMeta,
        autoBackupHourLocal.isAcceptableOrUnknown(
          data['auto_backup_hour_local']!,
          _autoBackupHourLocalMeta,
        ),
      );
    }
    if (data.containsKey('auto_backup_minute_local')) {
      context.handle(
        _autoBackupMinuteLocalMeta,
        autoBackupMinuteLocal.isAcceptableOrUnknown(
          data['auto_backup_minute_local']!,
          _autoBackupMinuteLocalMeta,
        ),
      );
    }
    if (data.containsKey('backup_encryption_enabled')) {
      context.handle(
        _backupEncryptionEnabledMeta,
        backupEncryptionEnabled.isAcceptableOrUnknown(
          data['backup_encryption_enabled']!,
          _backupEncryptionEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_backupEncryptionEnabledMeta);
    }
    if (data.containsKey('help_seen_version')) {
      context.handle(
        _helpSeenVersionMeta,
        helpSeenVersion.isAcceptableOrUnknown(
          data['help_seen_version']!,
          _helpSeenVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_helpSeenVersionMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_rowVersionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  AppSettingsRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppSettingsRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      localeMode: $AppSettingsTableTable.$converterlocaleMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}locale_mode'],
        )!,
      ),
      fontMode: $AppSettingsTableTable.$converterfontMode.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}font_mode'],
        )!,
      ),
      textScalePercent: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}text_scale_percent'],
      )!,
      density: $AppSettingsTableTable.$converterdensity.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}density'],
        )!,
      ),
      defaultSoundEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}default_sound_enabled'],
      )!,
      defaultVibrationEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}default_vibration_enabled'],
      )!,
      defaultSnoozeMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}default_snooze_minutes'],
      )!,
      autoBackupEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}auto_backup_enabled'],
      )!,
      autoBackupHourLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_backup_hour_local'],
      )!,
      autoBackupMinuteLocal: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}auto_backup_minute_local'],
      )!,
      backupEncryptionEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}backup_encryption_enabled'],
      )!,
      helpSeenVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}help_seen_version'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
    );
  }

  @override
  $AppSettingsTableTable createAlias(String alias) {
    return $AppSettingsTableTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<LocaleMode, String, String> $converterlocaleMode =
      const EnumNameConverter<LocaleMode>(LocaleMode.values);
  static JsonTypeConverter2<FontMode, String, String> $converterfontMode =
      const EnumNameConverter<FontMode>(FontMode.values);
  static JsonTypeConverter2<DisplayDensity, String, String> $converterdensity =
      const EnumNameConverter<DisplayDensity>(DisplayDensity.values);
}

class AppSettingsRow extends DataClass implements Insertable<AppSettingsRow> {
  final int id;
  final LocaleMode localeMode;
  final FontMode fontMode;
  final int textScalePercent;
  final DisplayDensity density;
  final bool defaultSoundEnabled;
  final bool defaultVibrationEnabled;
  final int defaultSnoozeMinutes;
  final bool autoBackupEnabled;
  final int autoBackupHourLocal;
  final int autoBackupMinuteLocal;
  final bool backupEncryptionEnabled;
  final int helpSeenVersion;
  final int updatedAtUtc;
  final int rowVersion;
  const AppSettingsRow({
    required this.id,
    required this.localeMode,
    required this.fontMode,
    required this.textScalePercent,
    required this.density,
    required this.defaultSoundEnabled,
    required this.defaultVibrationEnabled,
    required this.defaultSnoozeMinutes,
    required this.autoBackupEnabled,
    required this.autoBackupHourLocal,
    required this.autoBackupMinuteLocal,
    required this.backupEncryptionEnabled,
    required this.helpSeenVersion,
    required this.updatedAtUtc,
    required this.rowVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['locale_mode'] = Variable<String>(
        $AppSettingsTableTable.$converterlocaleMode.toSql(localeMode),
      );
    }
    {
      map['font_mode'] = Variable<String>(
        $AppSettingsTableTable.$converterfontMode.toSql(fontMode),
      );
    }
    map['text_scale_percent'] = Variable<int>(textScalePercent);
    {
      map['density'] = Variable<String>(
        $AppSettingsTableTable.$converterdensity.toSql(density),
      );
    }
    map['default_sound_enabled'] = Variable<bool>(defaultSoundEnabled);
    map['default_vibration_enabled'] = Variable<bool>(defaultVibrationEnabled);
    map['default_snooze_minutes'] = Variable<int>(defaultSnoozeMinutes);
    map['auto_backup_enabled'] = Variable<bool>(autoBackupEnabled);
    map['auto_backup_hour_local'] = Variable<int>(autoBackupHourLocal);
    map['auto_backup_minute_local'] = Variable<int>(autoBackupMinuteLocal);
    map['backup_encryption_enabled'] = Variable<bool>(backupEncryptionEnabled);
    map['help_seen_version'] = Variable<int>(helpSeenVersion);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['row_version'] = Variable<int>(rowVersion);
    return map;
  }

  AppSettingsTableCompanion toCompanion(bool nullToAbsent) {
    return AppSettingsTableCompanion(
      id: Value(id),
      localeMode: Value(localeMode),
      fontMode: Value(fontMode),
      textScalePercent: Value(textScalePercent),
      density: Value(density),
      defaultSoundEnabled: Value(defaultSoundEnabled),
      defaultVibrationEnabled: Value(defaultVibrationEnabled),
      defaultSnoozeMinutes: Value(defaultSnoozeMinutes),
      autoBackupEnabled: Value(autoBackupEnabled),
      autoBackupHourLocal: Value(autoBackupHourLocal),
      autoBackupMinuteLocal: Value(autoBackupMinuteLocal),
      backupEncryptionEnabled: Value(backupEncryptionEnabled),
      helpSeenVersion: Value(helpSeenVersion),
      updatedAtUtc: Value(updatedAtUtc),
      rowVersion: Value(rowVersion),
    );
  }

  factory AppSettingsRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppSettingsRow(
      id: serializer.fromJson<int>(json['id']),
      localeMode: $AppSettingsTableTable.$converterlocaleMode.fromJson(
        serializer.fromJson<String>(json['localeMode']),
      ),
      fontMode: $AppSettingsTableTable.$converterfontMode.fromJson(
        serializer.fromJson<String>(json['fontMode']),
      ),
      textScalePercent: serializer.fromJson<int>(json['textScalePercent']),
      density: $AppSettingsTableTable.$converterdensity.fromJson(
        serializer.fromJson<String>(json['density']),
      ),
      defaultSoundEnabled: serializer.fromJson<bool>(
        json['defaultSoundEnabled'],
      ),
      defaultVibrationEnabled: serializer.fromJson<bool>(
        json['defaultVibrationEnabled'],
      ),
      defaultSnoozeMinutes: serializer.fromJson<int>(
        json['defaultSnoozeMinutes'],
      ),
      autoBackupEnabled: serializer.fromJson<bool>(json['autoBackupEnabled']),
      autoBackupHourLocal: serializer.fromJson<int>(
        json['autoBackupHourLocal'],
      ),
      autoBackupMinuteLocal: serializer.fromJson<int>(
        json['autoBackupMinuteLocal'],
      ),
      backupEncryptionEnabled: serializer.fromJson<bool>(
        json['backupEncryptionEnabled'],
      ),
      helpSeenVersion: serializer.fromJson<int>(json['helpSeenVersion']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'localeMode': serializer.toJson<String>(
        $AppSettingsTableTable.$converterlocaleMode.toJson(localeMode),
      ),
      'fontMode': serializer.toJson<String>(
        $AppSettingsTableTable.$converterfontMode.toJson(fontMode),
      ),
      'textScalePercent': serializer.toJson<int>(textScalePercent),
      'density': serializer.toJson<String>(
        $AppSettingsTableTable.$converterdensity.toJson(density),
      ),
      'defaultSoundEnabled': serializer.toJson<bool>(defaultSoundEnabled),
      'defaultVibrationEnabled': serializer.toJson<bool>(
        defaultVibrationEnabled,
      ),
      'defaultSnoozeMinutes': serializer.toJson<int>(defaultSnoozeMinutes),
      'autoBackupEnabled': serializer.toJson<bool>(autoBackupEnabled),
      'autoBackupHourLocal': serializer.toJson<int>(autoBackupHourLocal),
      'autoBackupMinuteLocal': serializer.toJson<int>(autoBackupMinuteLocal),
      'backupEncryptionEnabled': serializer.toJson<bool>(
        backupEncryptionEnabled,
      ),
      'helpSeenVersion': serializer.toJson<int>(helpSeenVersion),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'rowVersion': serializer.toJson<int>(rowVersion),
    };
  }

  AppSettingsRow copyWith({
    int? id,
    LocaleMode? localeMode,
    FontMode? fontMode,
    int? textScalePercent,
    DisplayDensity? density,
    bool? defaultSoundEnabled,
    bool? defaultVibrationEnabled,
    int? defaultSnoozeMinutes,
    bool? autoBackupEnabled,
    int? autoBackupHourLocal,
    int? autoBackupMinuteLocal,
    bool? backupEncryptionEnabled,
    int? helpSeenVersion,
    int? updatedAtUtc,
    int? rowVersion,
  }) => AppSettingsRow(
    id: id ?? this.id,
    localeMode: localeMode ?? this.localeMode,
    fontMode: fontMode ?? this.fontMode,
    textScalePercent: textScalePercent ?? this.textScalePercent,
    density: density ?? this.density,
    defaultSoundEnabled: defaultSoundEnabled ?? this.defaultSoundEnabled,
    defaultVibrationEnabled:
        defaultVibrationEnabled ?? this.defaultVibrationEnabled,
    defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
    autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
    autoBackupHourLocal: autoBackupHourLocal ?? this.autoBackupHourLocal,
    autoBackupMinuteLocal: autoBackupMinuteLocal ?? this.autoBackupMinuteLocal,
    backupEncryptionEnabled:
        backupEncryptionEnabled ?? this.backupEncryptionEnabled,
    helpSeenVersion: helpSeenVersion ?? this.helpSeenVersion,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    rowVersion: rowVersion ?? this.rowVersion,
  );
  AppSettingsRow copyWithCompanion(AppSettingsTableCompanion data) {
    return AppSettingsRow(
      id: data.id.present ? data.id.value : this.id,
      localeMode: data.localeMode.present
          ? data.localeMode.value
          : this.localeMode,
      fontMode: data.fontMode.present ? data.fontMode.value : this.fontMode,
      textScalePercent: data.textScalePercent.present
          ? data.textScalePercent.value
          : this.textScalePercent,
      density: data.density.present ? data.density.value : this.density,
      defaultSoundEnabled: data.defaultSoundEnabled.present
          ? data.defaultSoundEnabled.value
          : this.defaultSoundEnabled,
      defaultVibrationEnabled: data.defaultVibrationEnabled.present
          ? data.defaultVibrationEnabled.value
          : this.defaultVibrationEnabled,
      defaultSnoozeMinutes: data.defaultSnoozeMinutes.present
          ? data.defaultSnoozeMinutes.value
          : this.defaultSnoozeMinutes,
      autoBackupEnabled: data.autoBackupEnabled.present
          ? data.autoBackupEnabled.value
          : this.autoBackupEnabled,
      autoBackupHourLocal: data.autoBackupHourLocal.present
          ? data.autoBackupHourLocal.value
          : this.autoBackupHourLocal,
      autoBackupMinuteLocal: data.autoBackupMinuteLocal.present
          ? data.autoBackupMinuteLocal.value
          : this.autoBackupMinuteLocal,
      backupEncryptionEnabled: data.backupEncryptionEnabled.present
          ? data.backupEncryptionEnabled.value
          : this.backupEncryptionEnabled,
      helpSeenVersion: data.helpSeenVersion.present
          ? data.helpSeenVersion.value
          : this.helpSeenVersion,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsRow(')
          ..write('id: $id, ')
          ..write('localeMode: $localeMode, ')
          ..write('fontMode: $fontMode, ')
          ..write('textScalePercent: $textScalePercent, ')
          ..write('density: $density, ')
          ..write('defaultSoundEnabled: $defaultSoundEnabled, ')
          ..write('defaultVibrationEnabled: $defaultVibrationEnabled, ')
          ..write('defaultSnoozeMinutes: $defaultSnoozeMinutes, ')
          ..write('autoBackupEnabled: $autoBackupEnabled, ')
          ..write('autoBackupHourLocal: $autoBackupHourLocal, ')
          ..write('autoBackupMinuteLocal: $autoBackupMinuteLocal, ')
          ..write('backupEncryptionEnabled: $backupEncryptionEnabled, ')
          ..write('helpSeenVersion: $helpSeenVersion, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    localeMode,
    fontMode,
    textScalePercent,
    density,
    defaultSoundEnabled,
    defaultVibrationEnabled,
    defaultSnoozeMinutes,
    autoBackupEnabled,
    autoBackupHourLocal,
    autoBackupMinuteLocal,
    backupEncryptionEnabled,
    helpSeenVersion,
    updatedAtUtc,
    rowVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppSettingsRow &&
          other.id == this.id &&
          other.localeMode == this.localeMode &&
          other.fontMode == this.fontMode &&
          other.textScalePercent == this.textScalePercent &&
          other.density == this.density &&
          other.defaultSoundEnabled == this.defaultSoundEnabled &&
          other.defaultVibrationEnabled == this.defaultVibrationEnabled &&
          other.defaultSnoozeMinutes == this.defaultSnoozeMinutes &&
          other.autoBackupEnabled == this.autoBackupEnabled &&
          other.autoBackupHourLocal == this.autoBackupHourLocal &&
          other.autoBackupMinuteLocal == this.autoBackupMinuteLocal &&
          other.backupEncryptionEnabled == this.backupEncryptionEnabled &&
          other.helpSeenVersion == this.helpSeenVersion &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.rowVersion == this.rowVersion);
}

class AppSettingsTableCompanion extends UpdateCompanion<AppSettingsRow> {
  final Value<int> id;
  final Value<LocaleMode> localeMode;
  final Value<FontMode> fontMode;
  final Value<int> textScalePercent;
  final Value<DisplayDensity> density;
  final Value<bool> defaultSoundEnabled;
  final Value<bool> defaultVibrationEnabled;
  final Value<int> defaultSnoozeMinutes;
  final Value<bool> autoBackupEnabled;
  final Value<int> autoBackupHourLocal;
  final Value<int> autoBackupMinuteLocal;
  final Value<bool> backupEncryptionEnabled;
  final Value<int> helpSeenVersion;
  final Value<int> updatedAtUtc;
  final Value<int> rowVersion;
  const AppSettingsTableCompanion({
    this.id = const Value.absent(),
    this.localeMode = const Value.absent(),
    this.fontMode = const Value.absent(),
    this.textScalePercent = const Value.absent(),
    this.density = const Value.absent(),
    this.defaultSoundEnabled = const Value.absent(),
    this.defaultVibrationEnabled = const Value.absent(),
    this.defaultSnoozeMinutes = const Value.absent(),
    this.autoBackupEnabled = const Value.absent(),
    this.autoBackupHourLocal = const Value.absent(),
    this.autoBackupMinuteLocal = const Value.absent(),
    this.backupEncryptionEnabled = const Value.absent(),
    this.helpSeenVersion = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowVersion = const Value.absent(),
  });
  AppSettingsTableCompanion.insert({
    this.id = const Value.absent(),
    required LocaleMode localeMode,
    required FontMode fontMode,
    required int textScalePercent,
    required DisplayDensity density,
    required bool defaultSoundEnabled,
    required bool defaultVibrationEnabled,
    required int defaultSnoozeMinutes,
    required bool autoBackupEnabled,
    this.autoBackupHourLocal = const Value.absent(),
    this.autoBackupMinuteLocal = const Value.absent(),
    required bool backupEncryptionEnabled,
    required int helpSeenVersion,
    required int updatedAtUtc,
    required int rowVersion,
  }) : localeMode = Value(localeMode),
       fontMode = Value(fontMode),
       textScalePercent = Value(textScalePercent),
       density = Value(density),
       defaultSoundEnabled = Value(defaultSoundEnabled),
       defaultVibrationEnabled = Value(defaultVibrationEnabled),
       defaultSnoozeMinutes = Value(defaultSnoozeMinutes),
       autoBackupEnabled = Value(autoBackupEnabled),
       backupEncryptionEnabled = Value(backupEncryptionEnabled),
       helpSeenVersion = Value(helpSeenVersion),
       updatedAtUtc = Value(updatedAtUtc),
       rowVersion = Value(rowVersion);
  static Insertable<AppSettingsRow> custom({
    Expression<int>? id,
    Expression<String>? localeMode,
    Expression<String>? fontMode,
    Expression<int>? textScalePercent,
    Expression<String>? density,
    Expression<bool>? defaultSoundEnabled,
    Expression<bool>? defaultVibrationEnabled,
    Expression<int>? defaultSnoozeMinutes,
    Expression<bool>? autoBackupEnabled,
    Expression<int>? autoBackupHourLocal,
    Expression<int>? autoBackupMinuteLocal,
    Expression<bool>? backupEncryptionEnabled,
    Expression<int>? helpSeenVersion,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowVersion,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (localeMode != null) 'locale_mode': localeMode,
      if (fontMode != null) 'font_mode': fontMode,
      if (textScalePercent != null) 'text_scale_percent': textScalePercent,
      if (density != null) 'density': density,
      if (defaultSoundEnabled != null)
        'default_sound_enabled': defaultSoundEnabled,
      if (defaultVibrationEnabled != null)
        'default_vibration_enabled': defaultVibrationEnabled,
      if (defaultSnoozeMinutes != null)
        'default_snooze_minutes': defaultSnoozeMinutes,
      if (autoBackupEnabled != null) 'auto_backup_enabled': autoBackupEnabled,
      if (autoBackupHourLocal != null)
        'auto_backup_hour_local': autoBackupHourLocal,
      if (autoBackupMinuteLocal != null)
        'auto_backup_minute_local': autoBackupMinuteLocal,
      if (backupEncryptionEnabled != null)
        'backup_encryption_enabled': backupEncryptionEnabled,
      if (helpSeenVersion != null) 'help_seen_version': helpSeenVersion,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowVersion != null) 'row_version': rowVersion,
    });
  }

  AppSettingsTableCompanion copyWith({
    Value<int>? id,
    Value<LocaleMode>? localeMode,
    Value<FontMode>? fontMode,
    Value<int>? textScalePercent,
    Value<DisplayDensity>? density,
    Value<bool>? defaultSoundEnabled,
    Value<bool>? defaultVibrationEnabled,
    Value<int>? defaultSnoozeMinutes,
    Value<bool>? autoBackupEnabled,
    Value<int>? autoBackupHourLocal,
    Value<int>? autoBackupMinuteLocal,
    Value<bool>? backupEncryptionEnabled,
    Value<int>? helpSeenVersion,
    Value<int>? updatedAtUtc,
    Value<int>? rowVersion,
  }) {
    return AppSettingsTableCompanion(
      id: id ?? this.id,
      localeMode: localeMode ?? this.localeMode,
      fontMode: fontMode ?? this.fontMode,
      textScalePercent: textScalePercent ?? this.textScalePercent,
      density: density ?? this.density,
      defaultSoundEnabled: defaultSoundEnabled ?? this.defaultSoundEnabled,
      defaultVibrationEnabled:
          defaultVibrationEnabled ?? this.defaultVibrationEnabled,
      defaultSnoozeMinutes: defaultSnoozeMinutes ?? this.defaultSnoozeMinutes,
      autoBackupEnabled: autoBackupEnabled ?? this.autoBackupEnabled,
      autoBackupHourLocal: autoBackupHourLocal ?? this.autoBackupHourLocal,
      autoBackupMinuteLocal:
          autoBackupMinuteLocal ?? this.autoBackupMinuteLocal,
      backupEncryptionEnabled:
          backupEncryptionEnabled ?? this.backupEncryptionEnabled,
      helpSeenVersion: helpSeenVersion ?? this.helpSeenVersion,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowVersion: rowVersion ?? this.rowVersion,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (localeMode.present) {
      map['locale_mode'] = Variable<String>(
        $AppSettingsTableTable.$converterlocaleMode.toSql(localeMode.value),
      );
    }
    if (fontMode.present) {
      map['font_mode'] = Variable<String>(
        $AppSettingsTableTable.$converterfontMode.toSql(fontMode.value),
      );
    }
    if (textScalePercent.present) {
      map['text_scale_percent'] = Variable<int>(textScalePercent.value);
    }
    if (density.present) {
      map['density'] = Variable<String>(
        $AppSettingsTableTable.$converterdensity.toSql(density.value),
      );
    }
    if (defaultSoundEnabled.present) {
      map['default_sound_enabled'] = Variable<bool>(defaultSoundEnabled.value);
    }
    if (defaultVibrationEnabled.present) {
      map['default_vibration_enabled'] = Variable<bool>(
        defaultVibrationEnabled.value,
      );
    }
    if (defaultSnoozeMinutes.present) {
      map['default_snooze_minutes'] = Variable<int>(defaultSnoozeMinutes.value);
    }
    if (autoBackupEnabled.present) {
      map['auto_backup_enabled'] = Variable<bool>(autoBackupEnabled.value);
    }
    if (autoBackupHourLocal.present) {
      map['auto_backup_hour_local'] = Variable<int>(autoBackupHourLocal.value);
    }
    if (autoBackupMinuteLocal.present) {
      map['auto_backup_minute_local'] = Variable<int>(
        autoBackupMinuteLocal.value,
      );
    }
    if (backupEncryptionEnabled.present) {
      map['backup_encryption_enabled'] = Variable<bool>(
        backupEncryptionEnabled.value,
      );
    }
    if (helpSeenVersion.present) {
      map['help_seen_version'] = Variable<int>(helpSeenVersion.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppSettingsTableCompanion(')
          ..write('id: $id, ')
          ..write('localeMode: $localeMode, ')
          ..write('fontMode: $fontMode, ')
          ..write('textScalePercent: $textScalePercent, ')
          ..write('density: $density, ')
          ..write('defaultSoundEnabled: $defaultSoundEnabled, ')
          ..write('defaultVibrationEnabled: $defaultVibrationEnabled, ')
          ..write('defaultSnoozeMinutes: $defaultSnoozeMinutes, ')
          ..write('autoBackupEnabled: $autoBackupEnabled, ')
          ..write('autoBackupHourLocal: $autoBackupHourLocal, ')
          ..write('autoBackupMinuteLocal: $autoBackupMinuteLocal, ')
          ..write('backupEncryptionEnabled: $backupEncryptionEnabled, ')
          ..write('helpSeenVersion: $helpSeenVersion, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTable extends Documents
    with TableInfo<$DocumentsTable, DocumentRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DocumentKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<DocumentKind>($DocumentsTable.$converterkind);
  static const VerificationMeta _singletonKeyMeta = const VerificationMeta(
    'singletonKey',
  );
  @override
  late final GeneratedColumn<String> singletonKey = GeneratedColumn<String>(
    'singleton_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _formatVersionMeta = const VerificationMeta(
    'formatVersion',
  );
  @override
  late final GeneratedColumn<int> formatVersion = GeneratedColumn<int>(
    'format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _semanticHashMeta = const VerificationMeta(
    'semanticHash',
  );
  @override
  late final GeneratedColumn<String> semanticHash = GeneratedColumn<String>(
    'semantic_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    singletonKey,
    formatVersion,
    revision,
    semanticHash,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('singleton_key')) {
      context.handle(
        _singletonKeyMeta,
        singletonKey.isAcceptableOrUnknown(
          data['singleton_key']!,
          _singletonKeyMeta,
        ),
      );
    }
    if (data.containsKey('format_version')) {
      context.handle(
        _formatVersionMeta,
        formatVersion.isAcceptableOrUnknown(
          data['format_version']!,
          _formatVersionMeta,
        ),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('semantic_hash')) {
      context.handle(
        _semanticHashMeta,
        semanticHash.isAcceptableOrUnknown(
          data['semantic_hash']!,
          _semanticHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticHashMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $DocumentsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      singletonKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}singleton_key'],
      ),
      formatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}format_version'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      semanticHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_hash'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DocumentKind, String, String> $converterkind =
      const EnumNameConverter<DocumentKind>(DocumentKind.values);
}

class DocumentRow extends DataClass implements Insertable<DocumentRow> {
  final String id;
  final DocumentKind kind;
  final String? singletonKey;
  final int formatVersion;
  final int revision;
  final String semanticHash;
  final int createdAtUtc;
  final int updatedAtUtc;
  final int rowVersion;
  const DocumentRow({
    required this.id,
    required this.kind,
    this.singletonKey,
    required this.formatVersion,
    required this.revision,
    required this.semanticHash,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>(
        $DocumentsTable.$converterkind.toSql(kind),
      );
    }
    if (!nullToAbsent || singletonKey != null) {
      map['singleton_key'] = Variable<String>(singletonKey);
    }
    map['format_version'] = Variable<int>(formatVersion);
    map['revision'] = Variable<int>(revision);
    map['semantic_hash'] = Variable<String>(semanticHash);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['row_version'] = Variable<int>(rowVersion);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      id: Value(id),
      kind: Value(kind),
      singletonKey: singletonKey == null && nullToAbsent
          ? const Value.absent()
          : Value(singletonKey),
      formatVersion: Value(formatVersion),
      revision: Value(revision),
      semanticHash: Value(semanticHash),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      rowVersion: Value(rowVersion),
    );
  }

  factory DocumentRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentRow(
      id: serializer.fromJson<String>(json['id']),
      kind: $DocumentsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      singletonKey: serializer.fromJson<String?>(json['singletonKey']),
      formatVersion: serializer.fromJson<int>(json['formatVersion']),
      revision: serializer.fromJson<int>(json['revision']),
      semanticHash: serializer.fromJson<String>(json['semanticHash']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(
        $DocumentsTable.$converterkind.toJson(kind),
      ),
      'singletonKey': serializer.toJson<String?>(singletonKey),
      'formatVersion': serializer.toJson<int>(formatVersion),
      'revision': serializer.toJson<int>(revision),
      'semanticHash': serializer.toJson<String>(semanticHash),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'rowVersion': serializer.toJson<int>(rowVersion),
    };
  }

  DocumentRow copyWith({
    String? id,
    DocumentKind? kind,
    Value<String?> singletonKey = const Value.absent(),
    int? formatVersion,
    int? revision,
    String? semanticHash,
    int? createdAtUtc,
    int? updatedAtUtc,
    int? rowVersion,
  }) => DocumentRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    singletonKey: singletonKey.present ? singletonKey.value : this.singletonKey,
    formatVersion: formatVersion ?? this.formatVersion,
    revision: revision ?? this.revision,
    semanticHash: semanticHash ?? this.semanticHash,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    rowVersion: rowVersion ?? this.rowVersion,
  );
  DocumentRow copyWithCompanion(DocumentsCompanion data) {
    return DocumentRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      singletonKey: data.singletonKey.present
          ? data.singletonKey.value
          : this.singletonKey,
      formatVersion: data.formatVersion.present
          ? data.formatVersion.value
          : this.formatVersion,
      revision: data.revision.present ? data.revision.value : this.revision,
      semanticHash: data.semanticHash.present
          ? data.semanticHash.value
          : this.semanticHash,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('singletonKey: $singletonKey, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('revision: $revision, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    singletonKey,
    formatVersion,
    revision,
    semanticHash,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.singletonKey == this.singletonKey &&
          other.formatVersion == this.formatVersion &&
          other.revision == this.revision &&
          other.semanticHash == this.semanticHash &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.rowVersion == this.rowVersion);
}

class DocumentsCompanion extends UpdateCompanion<DocumentRow> {
  final Value<String> id;
  final Value<DocumentKind> kind;
  final Value<String?> singletonKey;
  final Value<int> formatVersion;
  final Value<int> revision;
  final Value<String> semanticHash;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowVersion;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.singletonKey = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.revision = const Value.absent(),
    this.semanticHash = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String id,
    required DocumentKind kind,
    this.singletonKey = const Value.absent(),
    this.formatVersion = const Value.absent(),
    this.revision = const Value.absent(),
    required String semanticHash,
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       semanticHash = Value(semanticHash),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<DocumentRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? singletonKey,
    Expression<int>? formatVersion,
    Expression<int>? revision,
    Expression<String>? semanticHash,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (singletonKey != null) 'singleton_key': singletonKey,
      if (formatVersion != null) 'format_version': formatVersion,
      if (revision != null) 'revision': revision,
      if (semanticHash != null) 'semantic_hash': semanticHash,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowVersion != null) 'row_version': rowVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? id,
    Value<DocumentKind>? kind,
    Value<String?>? singletonKey,
    Value<int>? formatVersion,
    Value<int>? revision,
    Value<String>? semanticHash,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowVersion,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      singletonKey: singletonKey ?? this.singletonKey,
      formatVersion: formatVersion ?? this.formatVersion,
      revision: revision ?? this.revision,
      semanticHash: semanticHash ?? this.semanticHash,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowVersion: rowVersion ?? this.rowVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $DocumentsTable.$converterkind.toSql(kind.value),
      );
    }
    if (singletonKey.present) {
      map['singleton_key'] = Variable<String>(singletonKey.value);
    }
    if (formatVersion.present) {
      map['format_version'] = Variable<int>(formatVersion.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (semanticHash.present) {
      map['semantic_hash'] = Variable<String>(semanticHash.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('singletonKey: $singletonKey, ')
          ..write('formatVersion: $formatVersion, ')
          ..write('revision: $revision, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentBlocksTable extends DocumentBlocks
    with TableInfo<$DocumentBlocksTable, DocumentBlockRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentBlocksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _parentBlockIdMeta = const VerificationMeta(
    'parentBlockId',
  );
  @override
  late final GeneratedColumn<String> parentBlockId = GeneratedColumn<String>(
    'parent_block_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES document_blocks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _sortRankMeta = const VerificationMeta(
    'sortRank',
  );
  @override
  late final GeneratedColumn<int> sortRank = GeneratedColumn<int>(
    'sort_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<DocumentBlockType, String>
  blockType = GeneratedColumn<String>(
    'block_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<DocumentBlockType>($DocumentBlocksTable.$converterblockType);
  static const VerificationMeta _plainTextMeta = const VerificationMeta(
    'plainText',
  );
  @override
  late final GeneratedColumn<String> plainText = GeneratedColumn<String>(
    'plain_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _attributesJsonMeta = const VerificationMeta(
    'attributesJson',
  );
  @override
  late final GeneratedColumn<String> attributesJson = GeneratedColumn<String>(
    'attributes_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _isCheckedMeta = const VerificationMeta(
    'isChecked',
  );
  @override
  late final GeneratedColumn<bool> isChecked = GeneratedColumn<bool>(
    'is_checked',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_checked" IN (0, 1))',
    ),
  );
  static const VerificationMeta _semanticHashMeta = const VerificationMeta(
    'semanticHash',
  );
  @override
  late final GeneratedColumn<String> semanticHash = GeneratedColumn<String>(
    'semantic_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    parentBlockId,
    sortRank,
    blockType,
    plainText,
    payloadJson,
    attributesJson,
    isChecked,
    semanticHash,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_blocks';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentBlockRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('parent_block_id')) {
      context.handle(
        _parentBlockIdMeta,
        parentBlockId.isAcceptableOrUnknown(
          data['parent_block_id']!,
          _parentBlockIdMeta,
        ),
      );
    }
    if (data.containsKey('sort_rank')) {
      context.handle(
        _sortRankMeta,
        sortRank.isAcceptableOrUnknown(data['sort_rank']!, _sortRankMeta),
      );
    } else if (isInserting) {
      context.missing(_sortRankMeta);
    }
    if (data.containsKey('plain_text')) {
      context.handle(
        _plainTextMeta,
        plainText.isAcceptableOrUnknown(data['plain_text']!, _plainTextMeta),
      );
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    }
    if (data.containsKey('attributes_json')) {
      context.handle(
        _attributesJsonMeta,
        attributesJson.isAcceptableOrUnknown(
          data['attributes_json']!,
          _attributesJsonMeta,
        ),
      );
    }
    if (data.containsKey('is_checked')) {
      context.handle(
        _isCheckedMeta,
        isChecked.isAcceptableOrUnknown(data['is_checked']!, _isCheckedMeta),
      );
    }
    if (data.containsKey('semantic_hash')) {
      context.handle(
        _semanticHashMeta,
        semanticHash.isAcceptableOrUnknown(
          data['semantic_hash']!,
          _semanticHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticHashMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentBlockRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentBlockRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      parentBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}parent_block_id'],
      ),
      sortRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_rank'],
      )!,
      blockType: $DocumentBlocksTable.$converterblockType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}block_type'],
        )!,
      ),
      plainText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plain_text'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      attributesJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}attributes_json'],
      )!,
      isChecked: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_checked'],
      ),
      semanticHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_hash'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
    );
  }

  @override
  $DocumentBlocksTable createAlias(String alias) {
    return $DocumentBlocksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<DocumentBlockType, String, String>
  $converterblockType = const EnumNameConverter<DocumentBlockType>(
    DocumentBlockType.values,
  );
}

class DocumentBlockRow extends DataClass
    implements Insertable<DocumentBlockRow> {
  final String id;
  final String documentId;
  final String? parentBlockId;
  final int sortRank;
  final DocumentBlockType blockType;
  final String plainText;
  final String payloadJson;
  final String attributesJson;
  final bool? isChecked;
  final String semanticHash;
  final int createdAtUtc;
  final int updatedAtUtc;
  final int rowVersion;
  const DocumentBlockRow({
    required this.id,
    required this.documentId,
    this.parentBlockId,
    required this.sortRank,
    required this.blockType,
    required this.plainText,
    required this.payloadJson,
    required this.attributesJson,
    this.isChecked,
    required this.semanticHash,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    if (!nullToAbsent || parentBlockId != null) {
      map['parent_block_id'] = Variable<String>(parentBlockId);
    }
    map['sort_rank'] = Variable<int>(sortRank);
    {
      map['block_type'] = Variable<String>(
        $DocumentBlocksTable.$converterblockType.toSql(blockType),
      );
    }
    map['plain_text'] = Variable<String>(plainText);
    map['payload_json'] = Variable<String>(payloadJson);
    map['attributes_json'] = Variable<String>(attributesJson);
    if (!nullToAbsent || isChecked != null) {
      map['is_checked'] = Variable<bool>(isChecked);
    }
    map['semantic_hash'] = Variable<String>(semanticHash);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['row_version'] = Variable<int>(rowVersion);
    return map;
  }

  DocumentBlocksCompanion toCompanion(bool nullToAbsent) {
    return DocumentBlocksCompanion(
      id: Value(id),
      documentId: Value(documentId),
      parentBlockId: parentBlockId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentBlockId),
      sortRank: Value(sortRank),
      blockType: Value(blockType),
      plainText: Value(plainText),
      payloadJson: Value(payloadJson),
      attributesJson: Value(attributesJson),
      isChecked: isChecked == null && nullToAbsent
          ? const Value.absent()
          : Value(isChecked),
      semanticHash: Value(semanticHash),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      rowVersion: Value(rowVersion),
    );
  }

  factory DocumentBlockRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentBlockRow(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      parentBlockId: serializer.fromJson<String?>(json['parentBlockId']),
      sortRank: serializer.fromJson<int>(json['sortRank']),
      blockType: $DocumentBlocksTable.$converterblockType.fromJson(
        serializer.fromJson<String>(json['blockType']),
      ),
      plainText: serializer.fromJson<String>(json['plainText']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      attributesJson: serializer.fromJson<String>(json['attributesJson']),
      isChecked: serializer.fromJson<bool?>(json['isChecked']),
      semanticHash: serializer.fromJson<String>(json['semanticHash']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'parentBlockId': serializer.toJson<String?>(parentBlockId),
      'sortRank': serializer.toJson<int>(sortRank),
      'blockType': serializer.toJson<String>(
        $DocumentBlocksTable.$converterblockType.toJson(blockType),
      ),
      'plainText': serializer.toJson<String>(plainText),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'attributesJson': serializer.toJson<String>(attributesJson),
      'isChecked': serializer.toJson<bool?>(isChecked),
      'semanticHash': serializer.toJson<String>(semanticHash),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'rowVersion': serializer.toJson<int>(rowVersion),
    };
  }

  DocumentBlockRow copyWith({
    String? id,
    String? documentId,
    Value<String?> parentBlockId = const Value.absent(),
    int? sortRank,
    DocumentBlockType? blockType,
    String? plainText,
    String? payloadJson,
    String? attributesJson,
    Value<bool?> isChecked = const Value.absent(),
    String? semanticHash,
    int? createdAtUtc,
    int? updatedAtUtc,
    int? rowVersion,
  }) => DocumentBlockRow(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    parentBlockId: parentBlockId.present
        ? parentBlockId.value
        : this.parentBlockId,
    sortRank: sortRank ?? this.sortRank,
    blockType: blockType ?? this.blockType,
    plainText: plainText ?? this.plainText,
    payloadJson: payloadJson ?? this.payloadJson,
    attributesJson: attributesJson ?? this.attributesJson,
    isChecked: isChecked.present ? isChecked.value : this.isChecked,
    semanticHash: semanticHash ?? this.semanticHash,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    rowVersion: rowVersion ?? this.rowVersion,
  );
  DocumentBlockRow copyWithCompanion(DocumentBlocksCompanion data) {
    return DocumentBlockRow(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      parentBlockId: data.parentBlockId.present
          ? data.parentBlockId.value
          : this.parentBlockId,
      sortRank: data.sortRank.present ? data.sortRank.value : this.sortRank,
      blockType: data.blockType.present ? data.blockType.value : this.blockType,
      plainText: data.plainText.present ? data.plainText.value : this.plainText,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      attributesJson: data.attributesJson.present
          ? data.attributesJson.value
          : this.attributesJson,
      isChecked: data.isChecked.present ? data.isChecked.value : this.isChecked,
      semanticHash: data.semanticHash.present
          ? data.semanticHash.value
          : this.semanticHash,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentBlockRow(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('parentBlockId: $parentBlockId, ')
          ..write('sortRank: $sortRank, ')
          ..write('blockType: $blockType, ')
          ..write('plainText: $plainText, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attributesJson: $attributesJson, ')
          ..write('isChecked: $isChecked, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    parentBlockId,
    sortRank,
    blockType,
    plainText,
    payloadJson,
    attributesJson,
    isChecked,
    semanticHash,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentBlockRow &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.parentBlockId == this.parentBlockId &&
          other.sortRank == this.sortRank &&
          other.blockType == this.blockType &&
          other.plainText == this.plainText &&
          other.payloadJson == this.payloadJson &&
          other.attributesJson == this.attributesJson &&
          other.isChecked == this.isChecked &&
          other.semanticHash == this.semanticHash &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.rowVersion == this.rowVersion);
}

class DocumentBlocksCompanion extends UpdateCompanion<DocumentBlockRow> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<String?> parentBlockId;
  final Value<int> sortRank;
  final Value<DocumentBlockType> blockType;
  final Value<String> plainText;
  final Value<String> payloadJson;
  final Value<String> attributesJson;
  final Value<bool?> isChecked;
  final Value<String> semanticHash;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowVersion;
  final Value<int> rowid;
  const DocumentBlocksCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.parentBlockId = const Value.absent(),
    this.sortRank = const Value.absent(),
    this.blockType = const Value.absent(),
    this.plainText = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.attributesJson = const Value.absent(),
    this.isChecked = const Value.absent(),
    this.semanticHash = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentBlocksCompanion.insert({
    required String id,
    required String documentId,
    this.parentBlockId = const Value.absent(),
    required int sortRank,
    required DocumentBlockType blockType,
    this.plainText = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.attributesJson = const Value.absent(),
    this.isChecked = const Value.absent(),
    required String semanticHash,
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       sortRank = Value(sortRank),
       blockType = Value(blockType),
       semanticHash = Value(semanticHash),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<DocumentBlockRow> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? parentBlockId,
    Expression<int>? sortRank,
    Expression<String>? blockType,
    Expression<String>? plainText,
    Expression<String>? payloadJson,
    Expression<String>? attributesJson,
    Expression<bool>? isChecked,
    Expression<String>? semanticHash,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (parentBlockId != null) 'parent_block_id': parentBlockId,
      if (sortRank != null) 'sort_rank': sortRank,
      if (blockType != null) 'block_type': blockType,
      if (plainText != null) 'plain_text': plainText,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (attributesJson != null) 'attributes_json': attributesJson,
      if (isChecked != null) 'is_checked': isChecked,
      if (semanticHash != null) 'semantic_hash': semanticHash,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowVersion != null) 'row_version': rowVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentBlocksCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<String?>? parentBlockId,
    Value<int>? sortRank,
    Value<DocumentBlockType>? blockType,
    Value<String>? plainText,
    Value<String>? payloadJson,
    Value<String>? attributesJson,
    Value<bool?>? isChecked,
    Value<String>? semanticHash,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowVersion,
    Value<int>? rowid,
  }) {
    return DocumentBlocksCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      parentBlockId: parentBlockId ?? this.parentBlockId,
      sortRank: sortRank ?? this.sortRank,
      blockType: blockType ?? this.blockType,
      plainText: plainText ?? this.plainText,
      payloadJson: payloadJson ?? this.payloadJson,
      attributesJson: attributesJson ?? this.attributesJson,
      isChecked: isChecked ?? this.isChecked,
      semanticHash: semanticHash ?? this.semanticHash,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowVersion: rowVersion ?? this.rowVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (parentBlockId.present) {
      map['parent_block_id'] = Variable<String>(parentBlockId.value);
    }
    if (sortRank.present) {
      map['sort_rank'] = Variable<int>(sortRank.value);
    }
    if (blockType.present) {
      map['block_type'] = Variable<String>(
        $DocumentBlocksTable.$converterblockType.toSql(blockType.value),
      );
    }
    if (plainText.present) {
      map['plain_text'] = Variable<String>(plainText.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (attributesJson.present) {
      map['attributes_json'] = Variable<String>(attributesJson.value);
    }
    if (isChecked.present) {
      map['is_checked'] = Variable<bool>(isChecked.value);
    }
    if (semanticHash.present) {
      map['semantic_hash'] = Variable<String>(semanticHash.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentBlocksCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('parentBlockId: $parentBlockId, ')
          ..write('sortRank: $sortRank, ')
          ..write('blockType: $blockType, ')
          ..write('plainText: $plainText, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('attributesJson: $attributesJson, ')
          ..write('isChecked: $isChecked, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DocumentRevisionsTable extends DocumentRevisions
    with TableInfo<$DocumentRevisionsTable, DocumentRevisionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentRevisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _codecMeta = const VerificationMeta('codec');
  @override
  late final GeneratedColumn<String> codec = GeneratedColumn<String>(
    'codec',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('json-v1'),
  );
  static const VerificationMeta _snapshotBlobMeta = const VerificationMeta(
    'snapshotBlob',
  );
  @override
  late final GeneratedColumn<Uint8List> snapshotBlob =
      GeneratedColumn<Uint8List>(
        'snapshot_blob',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _snapshotSha256Meta = const VerificationMeta(
    'snapshotSha256',
  );
  @override
  late final GeneratedColumn<String> snapshotSha256 = GeneratedColumn<String>(
    'snapshot_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    revision,
    reason,
    codec,
    snapshotBlob,
    snapshotSha256,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'document_revisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<DocumentRevisionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    } else if (isInserting) {
      context.missing(_revisionMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('codec')) {
      context.handle(
        _codecMeta,
        codec.isAcceptableOrUnknown(data['codec']!, _codecMeta),
      );
    }
    if (data.containsKey('snapshot_blob')) {
      context.handle(
        _snapshotBlobMeta,
        snapshotBlob.isAcceptableOrUnknown(
          data['snapshot_blob']!,
          _snapshotBlobMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotBlobMeta);
    }
    if (data.containsKey('snapshot_sha256')) {
      context.handle(
        _snapshotSha256Meta,
        snapshotSha256.isAcceptableOrUnknown(
          data['snapshot_sha256']!,
          _snapshotSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotSha256Meta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DocumentRevisionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DocumentRevisionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      codec: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}codec'],
      )!,
      snapshotBlob: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}snapshot_blob'],
      )!,
      snapshotSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_sha256'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $DocumentRevisionsTable createAlias(String alias) {
    return $DocumentRevisionsTable(attachedDatabase, alias);
  }
}

class DocumentRevisionRow extends DataClass
    implements Insertable<DocumentRevisionRow> {
  final String id;
  final String documentId;
  final int revision;
  final String reason;
  final String codec;
  final Uint8List snapshotBlob;
  final String snapshotSha256;
  final int createdAtUtc;
  const DocumentRevisionRow({
    required this.id,
    required this.documentId,
    required this.revision,
    required this.reason,
    required this.codec,
    required this.snapshotBlob,
    required this.snapshotSha256,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['revision'] = Variable<int>(revision);
    map['reason'] = Variable<String>(reason);
    map['codec'] = Variable<String>(codec);
    map['snapshot_blob'] = Variable<Uint8List>(snapshotBlob);
    map['snapshot_sha256'] = Variable<String>(snapshotSha256);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    return map;
  }

  DocumentRevisionsCompanion toCompanion(bool nullToAbsent) {
    return DocumentRevisionsCompanion(
      id: Value(id),
      documentId: Value(documentId),
      revision: Value(revision),
      reason: Value(reason),
      codec: Value(codec),
      snapshotBlob: Value(snapshotBlob),
      snapshotSha256: Value(snapshotSha256),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory DocumentRevisionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DocumentRevisionRow(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      revision: serializer.fromJson<int>(json['revision']),
      reason: serializer.fromJson<String>(json['reason']),
      codec: serializer.fromJson<String>(json['codec']),
      snapshotBlob: serializer.fromJson<Uint8List>(json['snapshotBlob']),
      snapshotSha256: serializer.fromJson<String>(json['snapshotSha256']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'revision': serializer.toJson<int>(revision),
      'reason': serializer.toJson<String>(reason),
      'codec': serializer.toJson<String>(codec),
      'snapshotBlob': serializer.toJson<Uint8List>(snapshotBlob),
      'snapshotSha256': serializer.toJson<String>(snapshotSha256),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
    };
  }

  DocumentRevisionRow copyWith({
    String? id,
    String? documentId,
    int? revision,
    String? reason,
    String? codec,
    Uint8List? snapshotBlob,
    String? snapshotSha256,
    int? createdAtUtc,
  }) => DocumentRevisionRow(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    revision: revision ?? this.revision,
    reason: reason ?? this.reason,
    codec: codec ?? this.codec,
    snapshotBlob: snapshotBlob ?? this.snapshotBlob,
    snapshotSha256: snapshotSha256 ?? this.snapshotSha256,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  DocumentRevisionRow copyWithCompanion(DocumentRevisionsCompanion data) {
    return DocumentRevisionRow(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      revision: data.revision.present ? data.revision.value : this.revision,
      reason: data.reason.present ? data.reason.value : this.reason,
      codec: data.codec.present ? data.codec.value : this.codec,
      snapshotBlob: data.snapshotBlob.present
          ? data.snapshotBlob.value
          : this.snapshotBlob,
      snapshotSha256: data.snapshotSha256.present
          ? data.snapshotSha256.value
          : this.snapshotSha256,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRevisionRow(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('revision: $revision, ')
          ..write('reason: $reason, ')
          ..write('codec: $codec, ')
          ..write('snapshotBlob: $snapshotBlob, ')
          ..write('snapshotSha256: $snapshotSha256, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    revision,
    reason,
    codec,
    $driftBlobEquality.hash(snapshotBlob),
    snapshotSha256,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DocumentRevisionRow &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.revision == this.revision &&
          other.reason == this.reason &&
          other.codec == this.codec &&
          $driftBlobEquality.equals(other.snapshotBlob, this.snapshotBlob) &&
          other.snapshotSha256 == this.snapshotSha256 &&
          other.createdAtUtc == this.createdAtUtc);
}

class DocumentRevisionsCompanion extends UpdateCompanion<DocumentRevisionRow> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<int> revision;
  final Value<String> reason;
  final Value<String> codec;
  final Value<Uint8List> snapshotBlob;
  final Value<String> snapshotSha256;
  final Value<int> createdAtUtc;
  final Value<int> rowid;
  const DocumentRevisionsCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.revision = const Value.absent(),
    this.reason = const Value.absent(),
    this.codec = const Value.absent(),
    this.snapshotBlob = const Value.absent(),
    this.snapshotSha256 = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentRevisionsCompanion.insert({
    required String id,
    required String documentId,
    required int revision,
    required String reason,
    this.codec = const Value.absent(),
    required Uint8List snapshotBlob,
    required String snapshotSha256,
    required int createdAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       revision = Value(revision),
       reason = Value(reason),
       snapshotBlob = Value(snapshotBlob),
       snapshotSha256 = Value(snapshotSha256),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<DocumentRevisionRow> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<int>? revision,
    Expression<String>? reason,
    Expression<String>? codec,
    Expression<Uint8List>? snapshotBlob,
    Expression<String>? snapshotSha256,
    Expression<int>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (revision != null) 'revision': revision,
      if (reason != null) 'reason': reason,
      if (codec != null) 'codec': codec,
      if (snapshotBlob != null) 'snapshot_blob': snapshotBlob,
      if (snapshotSha256 != null) 'snapshot_sha256': snapshotSha256,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentRevisionsCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<int>? revision,
    Value<String>? reason,
    Value<String>? codec,
    Value<Uint8List>? snapshotBlob,
    Value<String>? snapshotSha256,
    Value<int>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return DocumentRevisionsCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      revision: revision ?? this.revision,
      reason: reason ?? this.reason,
      codec: codec ?? this.codec,
      snapshotBlob: snapshotBlob ?? this.snapshotBlob,
      snapshotSha256: snapshotSha256 ?? this.snapshotSha256,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (codec.present) {
      map['codec'] = Variable<String>(codec.value);
    }
    if (snapshotBlob.present) {
      map['snapshot_blob'] = Variable<Uint8List>(snapshotBlob.value);
    }
    if (snapshotSha256.present) {
      map['snapshot_sha256'] = Variable<String>(snapshotSha256.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentRevisionsCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('revision: $revision, ')
          ..write('reason: $reason, ')
          ..write('codec: $codec, ')
          ..write('snapshotBlob: $snapshotBlob, ')
          ..write('snapshotSha256: $snapshotSha256, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TasksTable extends Tasks with TableInfo<$TasksTable, TaskRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TasksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES documents (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dueLocalDateMeta = const VerificationMeta(
    'dueLocalDate',
  );
  @override
  late final GeneratedColumn<String> dueLocalDate = GeneratedColumn<String>(
    'due_local_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _planTextMeta = const VerificationMeta(
    'planText',
  );
  @override
  late final GeneratedColumn<String> planText = GeneratedColumn<String>(
    'plan_text',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  late final GeneratedColumnWithTypeConverter<TaskStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<TaskStatus>($TasksTable.$converterstatus);
  static const VerificationMeta _manualRankMeta = const VerificationMeta(
    'manualRank',
  );
  @override
  late final GeneratedColumn<int> manualRank = GeneratedColumn<int>(
    'manual_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _closedAtUtcMeta = const VerificationMeta(
    'closedAtUtc',
  );
  @override
  late final GeneratedColumn<int> closedAtUtc = GeneratedColumn<int>(
    'closed_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closedLocalDateMeta = const VerificationMeta(
    'closedLocalDate',
  );
  @override
  late final GeneratedColumn<String> closedLocalDate = GeneratedColumn<String>(
    'closed_local_date',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closedLocalTimeMeta = const VerificationMeta(
    'closedLocalTime',
  );
  @override
  late final GeneratedColumn<String> closedLocalTime = GeneratedColumn<String>(
    'closed_local_time',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _closedZoneIdMeta = const VerificationMeta(
    'closedZoneId',
  );
  @override
  late final GeneratedColumn<String> closedZoneId = GeneratedColumn<String>(
    'closed_zone_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archivedAtUtcMeta = const VerificationMeta(
    'archivedAtUtc',
  );
  @override
  late final GeneratedColumn<int> archivedAtUtc = GeneratedColumn<int>(
    'archived_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _semanticHashMeta = const VerificationMeta(
    'semanticHash',
  );
  @override
  late final GeneratedColumn<String> semanticHash = GeneratedColumn<String>(
    'semantic_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    title,
    dueLocalDate,
    planText,
    status,
    manualRank,
    closedAtUtc,
    closedLocalDate,
    closedLocalTime,
    closedZoneId,
    archivedAtUtc,
    deletedAtUtc,
    semanticHash,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<TaskRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('due_local_date')) {
      context.handle(
        _dueLocalDateMeta,
        dueLocalDate.isAcceptableOrUnknown(
          data['due_local_date']!,
          _dueLocalDateMeta,
        ),
      );
    }
    if (data.containsKey('plan_text')) {
      context.handle(
        _planTextMeta,
        planText.isAcceptableOrUnknown(data['plan_text']!, _planTextMeta),
      );
    }
    if (data.containsKey('manual_rank')) {
      context.handle(
        _manualRankMeta,
        manualRank.isAcceptableOrUnknown(data['manual_rank']!, _manualRankMeta),
      );
    } else if (isInserting) {
      context.missing(_manualRankMeta);
    }
    if (data.containsKey('closed_at_utc')) {
      context.handle(
        _closedAtUtcMeta,
        closedAtUtc.isAcceptableOrUnknown(
          data['closed_at_utc']!,
          _closedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('closed_local_date')) {
      context.handle(
        _closedLocalDateMeta,
        closedLocalDate.isAcceptableOrUnknown(
          data['closed_local_date']!,
          _closedLocalDateMeta,
        ),
      );
    }
    if (data.containsKey('closed_local_time')) {
      context.handle(
        _closedLocalTimeMeta,
        closedLocalTime.isAcceptableOrUnknown(
          data['closed_local_time']!,
          _closedLocalTimeMeta,
        ),
      );
    }
    if (data.containsKey('closed_zone_id')) {
      context.handle(
        _closedZoneIdMeta,
        closedZoneId.isAcceptableOrUnknown(
          data['closed_zone_id']!,
          _closedZoneIdMeta,
        ),
      );
    }
    if (data.containsKey('archived_at_utc')) {
      context.handle(
        _archivedAtUtcMeta,
        archivedAtUtc.isAcceptableOrUnknown(
          data['archived_at_utc']!,
          _archivedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('semantic_hash')) {
      context.handle(
        _semanticHashMeta,
        semanticHash.isAcceptableOrUnknown(
          data['semantic_hash']!,
          _semanticHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticHashMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TaskRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TaskRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      dueLocalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}due_local_date'],
      ),
      planText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}plan_text'],
      )!,
      status: $TasksTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      manualRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_rank'],
      )!,
      closedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}closed_at_utc'],
      ),
      closedLocalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_local_date'],
      ),
      closedLocalTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_local_time'],
      ),
      closedZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}closed_zone_id'],
      ),
      archivedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}archived_at_utc'],
      ),
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      semanticHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_hash'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
    );
  }

  @override
  $TasksTable createAlias(String alias) {
    return $TasksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TaskStatus, String, String> $converterstatus =
      const EnumNameConverter<TaskStatus>(TaskStatus.values);
}

class TaskRow extends DataClass implements Insertable<TaskRow> {
  final String id;
  final String documentId;
  final String title;
  final String? dueLocalDate;
  final String planText;
  final TaskStatus status;
  final int manualRank;
  final int? closedAtUtc;
  final String? closedLocalDate;
  final String? closedLocalTime;
  final String? closedZoneId;
  final int? archivedAtUtc;
  final int? deletedAtUtc;
  final String semanticHash;
  final int createdAtUtc;
  final int updatedAtUtc;
  final int rowVersion;
  const TaskRow({
    required this.id,
    required this.documentId,
    required this.title,
    this.dueLocalDate,
    required this.planText,
    required this.status,
    required this.manualRank,
    this.closedAtUtc,
    this.closedLocalDate,
    this.closedLocalTime,
    this.closedZoneId,
    this.archivedAtUtc,
    this.deletedAtUtc,
    required this.semanticHash,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || dueLocalDate != null) {
      map['due_local_date'] = Variable<String>(dueLocalDate);
    }
    map['plan_text'] = Variable<String>(planText);
    {
      map['status'] = Variable<String>(
        $TasksTable.$converterstatus.toSql(status),
      );
    }
    map['manual_rank'] = Variable<int>(manualRank);
    if (!nullToAbsent || closedAtUtc != null) {
      map['closed_at_utc'] = Variable<int>(closedAtUtc);
    }
    if (!nullToAbsent || closedLocalDate != null) {
      map['closed_local_date'] = Variable<String>(closedLocalDate);
    }
    if (!nullToAbsent || closedLocalTime != null) {
      map['closed_local_time'] = Variable<String>(closedLocalTime);
    }
    if (!nullToAbsent || closedZoneId != null) {
      map['closed_zone_id'] = Variable<String>(closedZoneId);
    }
    if (!nullToAbsent || archivedAtUtc != null) {
      map['archived_at_utc'] = Variable<int>(archivedAtUtc);
    }
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    map['semantic_hash'] = Variable<String>(semanticHash);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['row_version'] = Variable<int>(rowVersion);
    return map;
  }

  TasksCompanion toCompanion(bool nullToAbsent) {
    return TasksCompanion(
      id: Value(id),
      documentId: Value(documentId),
      title: Value(title),
      dueLocalDate: dueLocalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(dueLocalDate),
      planText: Value(planText),
      status: Value(status),
      manualRank: Value(manualRank),
      closedAtUtc: closedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(closedAtUtc),
      closedLocalDate: closedLocalDate == null && nullToAbsent
          ? const Value.absent()
          : Value(closedLocalDate),
      closedLocalTime: closedLocalTime == null && nullToAbsent
          ? const Value.absent()
          : Value(closedLocalTime),
      closedZoneId: closedZoneId == null && nullToAbsent
          ? const Value.absent()
          : Value(closedZoneId),
      archivedAtUtc: archivedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(archivedAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      semanticHash: Value(semanticHash),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      rowVersion: Value(rowVersion),
    );
  }

  factory TaskRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TaskRow(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      title: serializer.fromJson<String>(json['title']),
      dueLocalDate: serializer.fromJson<String?>(json['dueLocalDate']),
      planText: serializer.fromJson<String>(json['planText']),
      status: $TasksTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      manualRank: serializer.fromJson<int>(json['manualRank']),
      closedAtUtc: serializer.fromJson<int?>(json['closedAtUtc']),
      closedLocalDate: serializer.fromJson<String?>(json['closedLocalDate']),
      closedLocalTime: serializer.fromJson<String?>(json['closedLocalTime']),
      closedZoneId: serializer.fromJson<String?>(json['closedZoneId']),
      archivedAtUtc: serializer.fromJson<int?>(json['archivedAtUtc']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
      semanticHash: serializer.fromJson<String>(json['semanticHash']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'title': serializer.toJson<String>(title),
      'dueLocalDate': serializer.toJson<String?>(dueLocalDate),
      'planText': serializer.toJson<String>(planText),
      'status': serializer.toJson<String>(
        $TasksTable.$converterstatus.toJson(status),
      ),
      'manualRank': serializer.toJson<int>(manualRank),
      'closedAtUtc': serializer.toJson<int?>(closedAtUtc),
      'closedLocalDate': serializer.toJson<String?>(closedLocalDate),
      'closedLocalTime': serializer.toJson<String?>(closedLocalTime),
      'closedZoneId': serializer.toJson<String?>(closedZoneId),
      'archivedAtUtc': serializer.toJson<int?>(archivedAtUtc),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
      'semanticHash': serializer.toJson<String>(semanticHash),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'rowVersion': serializer.toJson<int>(rowVersion),
    };
  }

  TaskRow copyWith({
    String? id,
    String? documentId,
    String? title,
    Value<String?> dueLocalDate = const Value.absent(),
    String? planText,
    TaskStatus? status,
    int? manualRank,
    Value<int?> closedAtUtc = const Value.absent(),
    Value<String?> closedLocalDate = const Value.absent(),
    Value<String?> closedLocalTime = const Value.absent(),
    Value<String?> closedZoneId = const Value.absent(),
    Value<int?> archivedAtUtc = const Value.absent(),
    Value<int?> deletedAtUtc = const Value.absent(),
    String? semanticHash,
    int? createdAtUtc,
    int? updatedAtUtc,
    int? rowVersion,
  }) => TaskRow(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    title: title ?? this.title,
    dueLocalDate: dueLocalDate.present ? dueLocalDate.value : this.dueLocalDate,
    planText: planText ?? this.planText,
    status: status ?? this.status,
    manualRank: manualRank ?? this.manualRank,
    closedAtUtc: closedAtUtc.present ? closedAtUtc.value : this.closedAtUtc,
    closedLocalDate: closedLocalDate.present
        ? closedLocalDate.value
        : this.closedLocalDate,
    closedLocalTime: closedLocalTime.present
        ? closedLocalTime.value
        : this.closedLocalTime,
    closedZoneId: closedZoneId.present ? closedZoneId.value : this.closedZoneId,
    archivedAtUtc: archivedAtUtc.present
        ? archivedAtUtc.value
        : this.archivedAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    semanticHash: semanticHash ?? this.semanticHash,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    rowVersion: rowVersion ?? this.rowVersion,
  );
  TaskRow copyWithCompanion(TasksCompanion data) {
    return TaskRow(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      title: data.title.present ? data.title.value : this.title,
      dueLocalDate: data.dueLocalDate.present
          ? data.dueLocalDate.value
          : this.dueLocalDate,
      planText: data.planText.present ? data.planText.value : this.planText,
      status: data.status.present ? data.status.value : this.status,
      manualRank: data.manualRank.present
          ? data.manualRank.value
          : this.manualRank,
      closedAtUtc: data.closedAtUtc.present
          ? data.closedAtUtc.value
          : this.closedAtUtc,
      closedLocalDate: data.closedLocalDate.present
          ? data.closedLocalDate.value
          : this.closedLocalDate,
      closedLocalTime: data.closedLocalTime.present
          ? data.closedLocalTime.value
          : this.closedLocalTime,
      closedZoneId: data.closedZoneId.present
          ? data.closedZoneId.value
          : this.closedZoneId,
      archivedAtUtc: data.archivedAtUtc.present
          ? data.archivedAtUtc.value
          : this.archivedAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      semanticHash: data.semanticHash.present
          ? data.semanticHash.value
          : this.semanticHash,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TaskRow(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('title: $title, ')
          ..write('dueLocalDate: $dueLocalDate, ')
          ..write('planText: $planText, ')
          ..write('status: $status, ')
          ..write('manualRank: $manualRank, ')
          ..write('closedAtUtc: $closedAtUtc, ')
          ..write('closedLocalDate: $closedLocalDate, ')
          ..write('closedLocalTime: $closedLocalTime, ')
          ..write('closedZoneId: $closedZoneId, ')
          ..write('archivedAtUtc: $archivedAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    title,
    dueLocalDate,
    planText,
    status,
    manualRank,
    closedAtUtc,
    closedLocalDate,
    closedLocalTime,
    closedZoneId,
    archivedAtUtc,
    deletedAtUtc,
    semanticHash,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TaskRow &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.title == this.title &&
          other.dueLocalDate == this.dueLocalDate &&
          other.planText == this.planText &&
          other.status == this.status &&
          other.manualRank == this.manualRank &&
          other.closedAtUtc == this.closedAtUtc &&
          other.closedLocalDate == this.closedLocalDate &&
          other.closedLocalTime == this.closedLocalTime &&
          other.closedZoneId == this.closedZoneId &&
          other.archivedAtUtc == this.archivedAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.semanticHash == this.semanticHash &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.rowVersion == this.rowVersion);
}

class TasksCompanion extends UpdateCompanion<TaskRow> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<String> title;
  final Value<String?> dueLocalDate;
  final Value<String> planText;
  final Value<TaskStatus> status;
  final Value<int> manualRank;
  final Value<int?> closedAtUtc;
  final Value<String?> closedLocalDate;
  final Value<String?> closedLocalTime;
  final Value<String?> closedZoneId;
  final Value<int?> archivedAtUtc;
  final Value<int?> deletedAtUtc;
  final Value<String> semanticHash;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowVersion;
  final Value<int> rowid;
  const TasksCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.title = const Value.absent(),
    this.dueLocalDate = const Value.absent(),
    this.planText = const Value.absent(),
    this.status = const Value.absent(),
    this.manualRank = const Value.absent(),
    this.closedAtUtc = const Value.absent(),
    this.closedLocalDate = const Value.absent(),
    this.closedLocalTime = const Value.absent(),
    this.closedZoneId = const Value.absent(),
    this.archivedAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.semanticHash = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TasksCompanion.insert({
    required String id,
    required String documentId,
    required String title,
    this.dueLocalDate = const Value.absent(),
    this.planText = const Value.absent(),
    required TaskStatus status,
    required int manualRank,
    this.closedAtUtc = const Value.absent(),
    this.closedLocalDate = const Value.absent(),
    this.closedLocalTime = const Value.absent(),
    this.closedZoneId = const Value.absent(),
    this.archivedAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    required String semanticHash,
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       title = Value(title),
       status = Value(status),
       manualRank = Value(manualRank),
       semanticHash = Value(semanticHash),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<TaskRow> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? title,
    Expression<String>? dueLocalDate,
    Expression<String>? planText,
    Expression<String>? status,
    Expression<int>? manualRank,
    Expression<int>? closedAtUtc,
    Expression<String>? closedLocalDate,
    Expression<String>? closedLocalTime,
    Expression<String>? closedZoneId,
    Expression<int>? archivedAtUtc,
    Expression<int>? deletedAtUtc,
    Expression<String>? semanticHash,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (title != null) 'title': title,
      if (dueLocalDate != null) 'due_local_date': dueLocalDate,
      if (planText != null) 'plan_text': planText,
      if (status != null) 'status': status,
      if (manualRank != null) 'manual_rank': manualRank,
      if (closedAtUtc != null) 'closed_at_utc': closedAtUtc,
      if (closedLocalDate != null) 'closed_local_date': closedLocalDate,
      if (closedLocalTime != null) 'closed_local_time': closedLocalTime,
      if (closedZoneId != null) 'closed_zone_id': closedZoneId,
      if (archivedAtUtc != null) 'archived_at_utc': archivedAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (semanticHash != null) 'semantic_hash': semanticHash,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowVersion != null) 'row_version': rowVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TasksCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<String>? title,
    Value<String?>? dueLocalDate,
    Value<String>? planText,
    Value<TaskStatus>? status,
    Value<int>? manualRank,
    Value<int?>? closedAtUtc,
    Value<String?>? closedLocalDate,
    Value<String?>? closedLocalTime,
    Value<String?>? closedZoneId,
    Value<int?>? archivedAtUtc,
    Value<int?>? deletedAtUtc,
    Value<String>? semanticHash,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowVersion,
    Value<int>? rowid,
  }) {
    return TasksCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      title: title ?? this.title,
      dueLocalDate: dueLocalDate ?? this.dueLocalDate,
      planText: planText ?? this.planText,
      status: status ?? this.status,
      manualRank: manualRank ?? this.manualRank,
      closedAtUtc: closedAtUtc ?? this.closedAtUtc,
      closedLocalDate: closedLocalDate ?? this.closedLocalDate,
      closedLocalTime: closedLocalTime ?? this.closedLocalTime,
      closedZoneId: closedZoneId ?? this.closedZoneId,
      archivedAtUtc: archivedAtUtc ?? this.archivedAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      semanticHash: semanticHash ?? this.semanticHash,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowVersion: rowVersion ?? this.rowVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (dueLocalDate.present) {
      map['due_local_date'] = Variable<String>(dueLocalDate.value);
    }
    if (planText.present) {
      map['plan_text'] = Variable<String>(planText.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $TasksTable.$converterstatus.toSql(status.value),
      );
    }
    if (manualRank.present) {
      map['manual_rank'] = Variable<int>(manualRank.value);
    }
    if (closedAtUtc.present) {
      map['closed_at_utc'] = Variable<int>(closedAtUtc.value);
    }
    if (closedLocalDate.present) {
      map['closed_local_date'] = Variable<String>(closedLocalDate.value);
    }
    if (closedLocalTime.present) {
      map['closed_local_time'] = Variable<String>(closedLocalTime.value);
    }
    if (closedZoneId.present) {
      map['closed_zone_id'] = Variable<String>(closedZoneId.value);
    }
    if (archivedAtUtc.present) {
      map['archived_at_utc'] = Variable<int>(archivedAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (semanticHash.present) {
      map['semantic_hash'] = Variable<String>(semanticHash.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TasksCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('title: $title, ')
          ..write('dueLocalDate: $dueLocalDate, ')
          ..write('planText: $planText, ')
          ..write('status: $status, ')
          ..write('manualRank: $manualRank, ')
          ..write('closedAtUtc: $closedAtUtc, ')
          ..write('closedLocalDate: $closedLocalDate, ')
          ..write('closedLocalTime: $closedLocalTime, ')
          ..write('closedZoneId: $closedZoneId, ')
          ..write('archivedAtUtc: $archivedAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RemindersTable extends Reminders
    with TableInfo<$RemindersTable, ReminderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _taskIdMeta = const VerificationMeta('taskId');
  @override
  late final GeneratedColumn<String> taskId = GeneratedColumn<String>(
    'task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES tasks (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _scheduledLocalDateTimeMeta =
      const VerificationMeta('scheduledLocalDateTime');
  @override
  late final GeneratedColumn<String> scheduledLocalDateTime =
      GeneratedColumn<String>(
        'scheduled_local_date_time',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _scheduledZoneIdMeta = const VerificationMeta(
    'scheduledZoneId',
  );
  @override
  late final GeneratedColumn<String> scheduledZoneId = GeneratedColumn<String>(
    'scheduled_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledAtUtcMeta = const VerificationMeta(
    'scheduledAtUtc',
  );
  @override
  late final GeneratedColumn<int> scheduledAtUtc = GeneratedColumn<int>(
    'scheduled_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _snoozedUntilUtcMeta = const VerificationMeta(
    'snoozedUntilUtc',
  );
  @override
  late final GeneratedColumn<int> snoozedUntilUtc = GeneratedColumn<int>(
    'snoozed_until_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _soundEnabledMeta = const VerificationMeta(
    'soundEnabled',
  );
  @override
  late final GeneratedColumn<bool> soundEnabled = GeneratedColumn<bool>(
    'sound_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("sound_enabled" IN (0, 1))',
    ),
  );
  static const VerificationMeta _vibrationEnabledMeta = const VerificationMeta(
    'vibrationEnabled',
  );
  @override
  late final GeneratedColumn<bool> vibrationEnabled = GeneratedColumn<bool>(
    'vibration_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("vibration_enabled" IN (0, 1))',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<ReminderStatus, String> status =
      GeneratedColumn<String>(
        'status',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<ReminderStatus>($RemindersTable.$converterstatus);
  @override
  late final GeneratedColumnWithTypeConverter<ReminderPauseReason?, String>
  pauseReason = GeneratedColumn<String>(
    'pause_reason',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  ).withConverter<ReminderPauseReason?>($RemindersTable.$converterpauseReasonn);
  static const VerificationMeta _snoozeCountMeta = const VerificationMeta(
    'snoozeCount',
  );
  @override
  late final GeneratedColumn<int> snoozeCount = GeneratedColumn<int>(
    'snooze_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _scheduleRevisionMeta = const VerificationMeta(
    'scheduleRevision',
  );
  @override
  late final GeneratedColumn<int> scheduleRevision = GeneratedColumn<int>(
    'schedule_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _lastFiredAtUtcMeta = const VerificationMeta(
    'lastFiredAtUtc',
  );
  @override
  late final GeneratedColumn<int> lastFiredAtUtc = GeneratedColumn<int>(
    'last_fired_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    taskId,
    scheduledLocalDateTime,
    scheduledZoneId,
    scheduledAtUtc,
    snoozedUntilUtc,
    soundEnabled,
    vibrationEnabled,
    status,
    pauseReason,
    snoozeCount,
    scheduleRevision,
    lastFiredAtUtc,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<ReminderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('task_id')) {
      context.handle(
        _taskIdMeta,
        taskId.isAcceptableOrUnknown(data['task_id']!, _taskIdMeta),
      );
    } else if (isInserting) {
      context.missing(_taskIdMeta);
    }
    if (data.containsKey('scheduled_local_date_time')) {
      context.handle(
        _scheduledLocalDateTimeMeta,
        scheduledLocalDateTime.isAcceptableOrUnknown(
          data['scheduled_local_date_time']!,
          _scheduledLocalDateTimeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledLocalDateTimeMeta);
    }
    if (data.containsKey('scheduled_zone_id')) {
      context.handle(
        _scheduledZoneIdMeta,
        scheduledZoneId.isAcceptableOrUnknown(
          data['scheduled_zone_id']!,
          _scheduledZoneIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledZoneIdMeta);
    }
    if (data.containsKey('scheduled_at_utc')) {
      context.handle(
        _scheduledAtUtcMeta,
        scheduledAtUtc.isAcceptableOrUnknown(
          data['scheduled_at_utc']!,
          _scheduledAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledAtUtcMeta);
    }
    if (data.containsKey('snoozed_until_utc')) {
      context.handle(
        _snoozedUntilUtcMeta,
        snoozedUntilUtc.isAcceptableOrUnknown(
          data['snoozed_until_utc']!,
          _snoozedUntilUtcMeta,
        ),
      );
    }
    if (data.containsKey('sound_enabled')) {
      context.handle(
        _soundEnabledMeta,
        soundEnabled.isAcceptableOrUnknown(
          data['sound_enabled']!,
          _soundEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_soundEnabledMeta);
    }
    if (data.containsKey('vibration_enabled')) {
      context.handle(
        _vibrationEnabledMeta,
        vibrationEnabled.isAcceptableOrUnknown(
          data['vibration_enabled']!,
          _vibrationEnabledMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_vibrationEnabledMeta);
    }
    if (data.containsKey('snooze_count')) {
      context.handle(
        _snoozeCountMeta,
        snoozeCount.isAcceptableOrUnknown(
          data['snooze_count']!,
          _snoozeCountMeta,
        ),
      );
    }
    if (data.containsKey('schedule_revision')) {
      context.handle(
        _scheduleRevisionMeta,
        scheduleRevision.isAcceptableOrUnknown(
          data['schedule_revision']!,
          _scheduleRevisionMeta,
        ),
      );
    }
    if (data.containsKey('last_fired_at_utc')) {
      context.handle(
        _lastFiredAtUtcMeta,
        lastFiredAtUtc.isAcceptableOrUnknown(
          data['last_fired_at_utc']!,
          _lastFiredAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReminderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReminderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      taskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}task_id'],
      )!,
      scheduledLocalDateTime: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_local_date_time'],
      )!,
      scheduledZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_zone_id'],
      )!,
      scheduledAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}scheduled_at_utc'],
      )!,
      snoozedUntilUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snoozed_until_utc'],
      ),
      soundEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}sound_enabled'],
      )!,
      vibrationEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}vibration_enabled'],
      )!,
      status: $RemindersTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      pauseReason: $RemindersTable.$converterpauseReasonn.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}pause_reason'],
        ),
      ),
      snoozeCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}snooze_count'],
      )!,
      scheduleRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_revision'],
      )!,
      lastFiredAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_fired_at_utc'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
    );
  }

  @override
  $RemindersTable createAlias(String alias) {
    return $RemindersTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<ReminderStatus, String, String> $converterstatus =
      const EnumNameConverter<ReminderStatus>(ReminderStatus.values);
  static JsonTypeConverter2<ReminderPauseReason, String, String>
  $converterpauseReason = const EnumNameConverter<ReminderPauseReason>(
    ReminderPauseReason.values,
  );
  static JsonTypeConverter2<ReminderPauseReason?, String?, String?>
  $converterpauseReasonn = JsonTypeConverter2.asNullable($converterpauseReason);
}

class ReminderRow extends DataClass implements Insertable<ReminderRow> {
  final String id;
  final String taskId;
  final String scheduledLocalDateTime;
  final String scheduledZoneId;
  final int scheduledAtUtc;
  final int? snoozedUntilUtc;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final ReminderStatus status;
  final ReminderPauseReason? pauseReason;
  final int snoozeCount;
  final int scheduleRevision;
  final int? lastFiredAtUtc;
  final int createdAtUtc;
  final int updatedAtUtc;
  final int rowVersion;
  const ReminderRow({
    required this.id,
    required this.taskId,
    required this.scheduledLocalDateTime,
    required this.scheduledZoneId,
    required this.scheduledAtUtc,
    this.snoozedUntilUtc,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.status,
    this.pauseReason,
    required this.snoozeCount,
    required this.scheduleRevision,
    this.lastFiredAtUtc,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['task_id'] = Variable<String>(taskId);
    map['scheduled_local_date_time'] = Variable<String>(scheduledLocalDateTime);
    map['scheduled_zone_id'] = Variable<String>(scheduledZoneId);
    map['scheduled_at_utc'] = Variable<int>(scheduledAtUtc);
    if (!nullToAbsent || snoozedUntilUtc != null) {
      map['snoozed_until_utc'] = Variable<int>(snoozedUntilUtc);
    }
    map['sound_enabled'] = Variable<bool>(soundEnabled);
    map['vibration_enabled'] = Variable<bool>(vibrationEnabled);
    {
      map['status'] = Variable<String>(
        $RemindersTable.$converterstatus.toSql(status),
      );
    }
    if (!nullToAbsent || pauseReason != null) {
      map['pause_reason'] = Variable<String>(
        $RemindersTable.$converterpauseReasonn.toSql(pauseReason),
      );
    }
    map['snooze_count'] = Variable<int>(snoozeCount);
    map['schedule_revision'] = Variable<int>(scheduleRevision);
    if (!nullToAbsent || lastFiredAtUtc != null) {
      map['last_fired_at_utc'] = Variable<int>(lastFiredAtUtc);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['row_version'] = Variable<int>(rowVersion);
    return map;
  }

  RemindersCompanion toCompanion(bool nullToAbsent) {
    return RemindersCompanion(
      id: Value(id),
      taskId: Value(taskId),
      scheduledLocalDateTime: Value(scheduledLocalDateTime),
      scheduledZoneId: Value(scheduledZoneId),
      scheduledAtUtc: Value(scheduledAtUtc),
      snoozedUntilUtc: snoozedUntilUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntilUtc),
      soundEnabled: Value(soundEnabled),
      vibrationEnabled: Value(vibrationEnabled),
      status: Value(status),
      pauseReason: pauseReason == null && nullToAbsent
          ? const Value.absent()
          : Value(pauseReason),
      snoozeCount: Value(snoozeCount),
      scheduleRevision: Value(scheduleRevision),
      lastFiredAtUtc: lastFiredAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFiredAtUtc),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      rowVersion: Value(rowVersion),
    );
  }

  factory ReminderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReminderRow(
      id: serializer.fromJson<String>(json['id']),
      taskId: serializer.fromJson<String>(json['taskId']),
      scheduledLocalDateTime: serializer.fromJson<String>(
        json['scheduledLocalDateTime'],
      ),
      scheduledZoneId: serializer.fromJson<String>(json['scheduledZoneId']),
      scheduledAtUtc: serializer.fromJson<int>(json['scheduledAtUtc']),
      snoozedUntilUtc: serializer.fromJson<int?>(json['snoozedUntilUtc']),
      soundEnabled: serializer.fromJson<bool>(json['soundEnabled']),
      vibrationEnabled: serializer.fromJson<bool>(json['vibrationEnabled']),
      status: $RemindersTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      pauseReason: $RemindersTable.$converterpauseReasonn.fromJson(
        serializer.fromJson<String?>(json['pauseReason']),
      ),
      snoozeCount: serializer.fromJson<int>(json['snoozeCount']),
      scheduleRevision: serializer.fromJson<int>(json['scheduleRevision']),
      lastFiredAtUtc: serializer.fromJson<int?>(json['lastFiredAtUtc']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'taskId': serializer.toJson<String>(taskId),
      'scheduledLocalDateTime': serializer.toJson<String>(
        scheduledLocalDateTime,
      ),
      'scheduledZoneId': serializer.toJson<String>(scheduledZoneId),
      'scheduledAtUtc': serializer.toJson<int>(scheduledAtUtc),
      'snoozedUntilUtc': serializer.toJson<int?>(snoozedUntilUtc),
      'soundEnabled': serializer.toJson<bool>(soundEnabled),
      'vibrationEnabled': serializer.toJson<bool>(vibrationEnabled),
      'status': serializer.toJson<String>(
        $RemindersTable.$converterstatus.toJson(status),
      ),
      'pauseReason': serializer.toJson<String?>(
        $RemindersTable.$converterpauseReasonn.toJson(pauseReason),
      ),
      'snoozeCount': serializer.toJson<int>(snoozeCount),
      'scheduleRevision': serializer.toJson<int>(scheduleRevision),
      'lastFiredAtUtc': serializer.toJson<int?>(lastFiredAtUtc),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'rowVersion': serializer.toJson<int>(rowVersion),
    };
  }

  ReminderRow copyWith({
    String? id,
    String? taskId,
    String? scheduledLocalDateTime,
    String? scheduledZoneId,
    int? scheduledAtUtc,
    Value<int?> snoozedUntilUtc = const Value.absent(),
    bool? soundEnabled,
    bool? vibrationEnabled,
    ReminderStatus? status,
    Value<ReminderPauseReason?> pauseReason = const Value.absent(),
    int? snoozeCount,
    int? scheduleRevision,
    Value<int?> lastFiredAtUtc = const Value.absent(),
    int? createdAtUtc,
    int? updatedAtUtc,
    int? rowVersion,
  }) => ReminderRow(
    id: id ?? this.id,
    taskId: taskId ?? this.taskId,
    scheduledLocalDateTime:
        scheduledLocalDateTime ?? this.scheduledLocalDateTime,
    scheduledZoneId: scheduledZoneId ?? this.scheduledZoneId,
    scheduledAtUtc: scheduledAtUtc ?? this.scheduledAtUtc,
    snoozedUntilUtc: snoozedUntilUtc.present
        ? snoozedUntilUtc.value
        : this.snoozedUntilUtc,
    soundEnabled: soundEnabled ?? this.soundEnabled,
    vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    status: status ?? this.status,
    pauseReason: pauseReason.present ? pauseReason.value : this.pauseReason,
    snoozeCount: snoozeCount ?? this.snoozeCount,
    scheduleRevision: scheduleRevision ?? this.scheduleRevision,
    lastFiredAtUtc: lastFiredAtUtc.present
        ? lastFiredAtUtc.value
        : this.lastFiredAtUtc,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    rowVersion: rowVersion ?? this.rowVersion,
  );
  ReminderRow copyWithCompanion(RemindersCompanion data) {
    return ReminderRow(
      id: data.id.present ? data.id.value : this.id,
      taskId: data.taskId.present ? data.taskId.value : this.taskId,
      scheduledLocalDateTime: data.scheduledLocalDateTime.present
          ? data.scheduledLocalDateTime.value
          : this.scheduledLocalDateTime,
      scheduledZoneId: data.scheduledZoneId.present
          ? data.scheduledZoneId.value
          : this.scheduledZoneId,
      scheduledAtUtc: data.scheduledAtUtc.present
          ? data.scheduledAtUtc.value
          : this.scheduledAtUtc,
      snoozedUntilUtc: data.snoozedUntilUtc.present
          ? data.snoozedUntilUtc.value
          : this.snoozedUntilUtc,
      soundEnabled: data.soundEnabled.present
          ? data.soundEnabled.value
          : this.soundEnabled,
      vibrationEnabled: data.vibrationEnabled.present
          ? data.vibrationEnabled.value
          : this.vibrationEnabled,
      status: data.status.present ? data.status.value : this.status,
      pauseReason: data.pauseReason.present
          ? data.pauseReason.value
          : this.pauseReason,
      snoozeCount: data.snoozeCount.present
          ? data.snoozeCount.value
          : this.snoozeCount,
      scheduleRevision: data.scheduleRevision.present
          ? data.scheduleRevision.value
          : this.scheduleRevision,
      lastFiredAtUtc: data.lastFiredAtUtc.present
          ? data.lastFiredAtUtc.value
          : this.lastFiredAtUtc,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReminderRow(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('scheduledLocalDateTime: $scheduledLocalDateTime, ')
          ..write('scheduledZoneId: $scheduledZoneId, ')
          ..write('scheduledAtUtc: $scheduledAtUtc, ')
          ..write('snoozedUntilUtc: $snoozedUntilUtc, ')
          ..write('soundEnabled: $soundEnabled, ')
          ..write('vibrationEnabled: $vibrationEnabled, ')
          ..write('status: $status, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('scheduleRevision: $scheduleRevision, ')
          ..write('lastFiredAtUtc: $lastFiredAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    taskId,
    scheduledLocalDateTime,
    scheduledZoneId,
    scheduledAtUtc,
    snoozedUntilUtc,
    soundEnabled,
    vibrationEnabled,
    status,
    pauseReason,
    snoozeCount,
    scheduleRevision,
    lastFiredAtUtc,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReminderRow &&
          other.id == this.id &&
          other.taskId == this.taskId &&
          other.scheduledLocalDateTime == this.scheduledLocalDateTime &&
          other.scheduledZoneId == this.scheduledZoneId &&
          other.scheduledAtUtc == this.scheduledAtUtc &&
          other.snoozedUntilUtc == this.snoozedUntilUtc &&
          other.soundEnabled == this.soundEnabled &&
          other.vibrationEnabled == this.vibrationEnabled &&
          other.status == this.status &&
          other.pauseReason == this.pauseReason &&
          other.snoozeCount == this.snoozeCount &&
          other.scheduleRevision == this.scheduleRevision &&
          other.lastFiredAtUtc == this.lastFiredAtUtc &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.rowVersion == this.rowVersion);
}

class RemindersCompanion extends UpdateCompanion<ReminderRow> {
  final Value<String> id;
  final Value<String> taskId;
  final Value<String> scheduledLocalDateTime;
  final Value<String> scheduledZoneId;
  final Value<int> scheduledAtUtc;
  final Value<int?> snoozedUntilUtc;
  final Value<bool> soundEnabled;
  final Value<bool> vibrationEnabled;
  final Value<ReminderStatus> status;
  final Value<ReminderPauseReason?> pauseReason;
  final Value<int> snoozeCount;
  final Value<int> scheduleRevision;
  final Value<int?> lastFiredAtUtc;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowVersion;
  final Value<int> rowid;
  const RemindersCompanion({
    this.id = const Value.absent(),
    this.taskId = const Value.absent(),
    this.scheduledLocalDateTime = const Value.absent(),
    this.scheduledZoneId = const Value.absent(),
    this.scheduledAtUtc = const Value.absent(),
    this.snoozedUntilUtc = const Value.absent(),
    this.soundEnabled = const Value.absent(),
    this.vibrationEnabled = const Value.absent(),
    this.status = const Value.absent(),
    this.pauseReason = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    this.scheduleRevision = const Value.absent(),
    this.lastFiredAtUtc = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RemindersCompanion.insert({
    required String id,
    required String taskId,
    required String scheduledLocalDateTime,
    required String scheduledZoneId,
    required int scheduledAtUtc,
    this.snoozedUntilUtc = const Value.absent(),
    required bool soundEnabled,
    required bool vibrationEnabled,
    required ReminderStatus status,
    this.pauseReason = const Value.absent(),
    this.snoozeCount = const Value.absent(),
    this.scheduleRevision = const Value.absent(),
    this.lastFiredAtUtc = const Value.absent(),
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       taskId = Value(taskId),
       scheduledLocalDateTime = Value(scheduledLocalDateTime),
       scheduledZoneId = Value(scheduledZoneId),
       scheduledAtUtc = Value(scheduledAtUtc),
       soundEnabled = Value(soundEnabled),
       vibrationEnabled = Value(vibrationEnabled),
       status = Value(status),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<ReminderRow> custom({
    Expression<String>? id,
    Expression<String>? taskId,
    Expression<String>? scheduledLocalDateTime,
    Expression<String>? scheduledZoneId,
    Expression<int>? scheduledAtUtc,
    Expression<int>? snoozedUntilUtc,
    Expression<bool>? soundEnabled,
    Expression<bool>? vibrationEnabled,
    Expression<String>? status,
    Expression<String>? pauseReason,
    Expression<int>? snoozeCount,
    Expression<int>? scheduleRevision,
    Expression<int>? lastFiredAtUtc,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (taskId != null) 'task_id': taskId,
      if (scheduledLocalDateTime != null)
        'scheduled_local_date_time': scheduledLocalDateTime,
      if (scheduledZoneId != null) 'scheduled_zone_id': scheduledZoneId,
      if (scheduledAtUtc != null) 'scheduled_at_utc': scheduledAtUtc,
      if (snoozedUntilUtc != null) 'snoozed_until_utc': snoozedUntilUtc,
      if (soundEnabled != null) 'sound_enabled': soundEnabled,
      if (vibrationEnabled != null) 'vibration_enabled': vibrationEnabled,
      if (status != null) 'status': status,
      if (pauseReason != null) 'pause_reason': pauseReason,
      if (snoozeCount != null) 'snooze_count': snoozeCount,
      if (scheduleRevision != null) 'schedule_revision': scheduleRevision,
      if (lastFiredAtUtc != null) 'last_fired_at_utc': lastFiredAtUtc,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowVersion != null) 'row_version': rowVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RemindersCompanion copyWith({
    Value<String>? id,
    Value<String>? taskId,
    Value<String>? scheduledLocalDateTime,
    Value<String>? scheduledZoneId,
    Value<int>? scheduledAtUtc,
    Value<int?>? snoozedUntilUtc,
    Value<bool>? soundEnabled,
    Value<bool>? vibrationEnabled,
    Value<ReminderStatus>? status,
    Value<ReminderPauseReason?>? pauseReason,
    Value<int>? snoozeCount,
    Value<int>? scheduleRevision,
    Value<int?>? lastFiredAtUtc,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowVersion,
    Value<int>? rowid,
  }) {
    return RemindersCompanion(
      id: id ?? this.id,
      taskId: taskId ?? this.taskId,
      scheduledLocalDateTime:
          scheduledLocalDateTime ?? this.scheduledLocalDateTime,
      scheduledZoneId: scheduledZoneId ?? this.scheduledZoneId,
      scheduledAtUtc: scheduledAtUtc ?? this.scheduledAtUtc,
      snoozedUntilUtc: snoozedUntilUtc ?? this.snoozedUntilUtc,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      status: status ?? this.status,
      pauseReason: pauseReason ?? this.pauseReason,
      snoozeCount: snoozeCount ?? this.snoozeCount,
      scheduleRevision: scheduleRevision ?? this.scheduleRevision,
      lastFiredAtUtc: lastFiredAtUtc ?? this.lastFiredAtUtc,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowVersion: rowVersion ?? this.rowVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (taskId.present) {
      map['task_id'] = Variable<String>(taskId.value);
    }
    if (scheduledLocalDateTime.present) {
      map['scheduled_local_date_time'] = Variable<String>(
        scheduledLocalDateTime.value,
      );
    }
    if (scheduledZoneId.present) {
      map['scheduled_zone_id'] = Variable<String>(scheduledZoneId.value);
    }
    if (scheduledAtUtc.present) {
      map['scheduled_at_utc'] = Variable<int>(scheduledAtUtc.value);
    }
    if (snoozedUntilUtc.present) {
      map['snoozed_until_utc'] = Variable<int>(snoozedUntilUtc.value);
    }
    if (soundEnabled.present) {
      map['sound_enabled'] = Variable<bool>(soundEnabled.value);
    }
    if (vibrationEnabled.present) {
      map['vibration_enabled'] = Variable<bool>(vibrationEnabled.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $RemindersTable.$converterstatus.toSql(status.value),
      );
    }
    if (pauseReason.present) {
      map['pause_reason'] = Variable<String>(
        $RemindersTable.$converterpauseReasonn.toSql(pauseReason.value),
      );
    }
    if (snoozeCount.present) {
      map['snooze_count'] = Variable<int>(snoozeCount.value);
    }
    if (scheduleRevision.present) {
      map['schedule_revision'] = Variable<int>(scheduleRevision.value);
    }
    if (lastFiredAtUtc.present) {
      map['last_fired_at_utc'] = Variable<int>(lastFiredAtUtc.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RemindersCompanion(')
          ..write('id: $id, ')
          ..write('taskId: $taskId, ')
          ..write('scheduledLocalDateTime: $scheduledLocalDateTime, ')
          ..write('scheduledZoneId: $scheduledZoneId, ')
          ..write('scheduledAtUtc: $scheduledAtUtc, ')
          ..write('snoozedUntilUtc: $snoozedUntilUtc, ')
          ..write('soundEnabled: $soundEnabled, ')
          ..write('vibrationEnabled: $vibrationEnabled, ')
          ..write('status: $status, ')
          ..write('pauseReason: $pauseReason, ')
          ..write('snoozeCount: $snoozeCount, ')
          ..write('scheduleRevision: $scheduleRevision, ')
          ..write('lastFiredAtUtc: $lastFiredAtUtc, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationRegistrationsTable extends NotificationRegistrations
    with
        TableInfo<
          $NotificationRegistrationsTable,
          NotificationRegistrationRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationRegistrationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _reminderIdMeta = const VerificationMeta(
    'reminderId',
  );
  @override
  late final GeneratedColumn<String> reminderId = GeneratedColumn<String>(
    'reminder_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES reminders (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformNotificationIdMeta =
      const VerificationMeta('platformNotificationId');
  @override
  late final GeneratedColumn<int> platformNotificationId = GeneratedColumn<int>(
    'platform_notification_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _scheduleRevisionMeta = const VerificationMeta(
    'scheduleRevision',
  );
  @override
  late final GeneratedColumn<int> scheduleRevision = GeneratedColumn<int>(
    'schedule_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledLocaleMeta = const VerificationMeta(
    'scheduledLocale',
  );
  @override
  late final GeneratedColumn<String> scheduledLocale = GeneratedColumn<String>(
    'scheduled_locale',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _registeredAtUtcMeta = const VerificationMeta(
    'registeredAtUtc',
  );
  @override
  late final GeneratedColumn<int> registeredAtUtc = GeneratedColumn<int>(
    'registered_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    reminderId,
    platform,
    platformNotificationId,
    scheduleRevision,
    scheduledLocale,
    registeredAtUtc,
    lastErrorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_registrations';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationRegistrationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('reminder_id')) {
      context.handle(
        _reminderIdMeta,
        reminderId.isAcceptableOrUnknown(data['reminder_id']!, _reminderIdMeta),
      );
    } else if (isInserting) {
      context.missing(_reminderIdMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('platform_notification_id')) {
      context.handle(
        _platformNotificationIdMeta,
        platformNotificationId.isAcceptableOrUnknown(
          data['platform_notification_id']!,
          _platformNotificationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_platformNotificationIdMeta);
    }
    if (data.containsKey('schedule_revision')) {
      context.handle(
        _scheduleRevisionMeta,
        scheduleRevision.isAcceptableOrUnknown(
          data['schedule_revision']!,
          _scheduleRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduleRevisionMeta);
    }
    if (data.containsKey('scheduled_locale')) {
      context.handle(
        _scheduledLocaleMeta,
        scheduledLocale.isAcceptableOrUnknown(
          data['scheduled_locale']!,
          _scheduledLocaleMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledLocaleMeta);
    }
    if (data.containsKey('registered_at_utc')) {
      context.handle(
        _registeredAtUtcMeta,
        registeredAtUtc.isAcceptableOrUnknown(
          data['registered_at_utc']!,
          _registeredAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_registeredAtUtcMeta);
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {reminderId};
  @override
  NotificationRegistrationRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationRegistrationRow(
      reminderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reminder_id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      platformNotificationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}platform_notification_id'],
      )!,
      scheduleRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}schedule_revision'],
      )!,
      scheduledLocale: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}scheduled_locale'],
      )!,
      registeredAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}registered_at_utc'],
      )!,
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
    );
  }

  @override
  $NotificationRegistrationsTable createAlias(String alias) {
    return $NotificationRegistrationsTable(attachedDatabase, alias);
  }
}

class NotificationRegistrationRow extends DataClass
    implements Insertable<NotificationRegistrationRow> {
  final String reminderId;
  final String platform;
  final int platformNotificationId;
  final int scheduleRevision;
  final String scheduledLocale;
  final int registeredAtUtc;
  final String? lastErrorCode;
  const NotificationRegistrationRow({
    required this.reminderId,
    required this.platform,
    required this.platformNotificationId,
    required this.scheduleRevision,
    required this.scheduledLocale,
    required this.registeredAtUtc,
    this.lastErrorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['reminder_id'] = Variable<String>(reminderId);
    map['platform'] = Variable<String>(platform);
    map['platform_notification_id'] = Variable<int>(platformNotificationId);
    map['schedule_revision'] = Variable<int>(scheduleRevision);
    map['scheduled_locale'] = Variable<String>(scheduledLocale);
    map['registered_at_utc'] = Variable<int>(registeredAtUtc);
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    return map;
  }

  NotificationRegistrationsCompanion toCompanion(bool nullToAbsent) {
    return NotificationRegistrationsCompanion(
      reminderId: Value(reminderId),
      platform: Value(platform),
      platformNotificationId: Value(platformNotificationId),
      scheduleRevision: Value(scheduleRevision),
      scheduledLocale: Value(scheduledLocale),
      registeredAtUtc: Value(registeredAtUtc),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
    );
  }

  factory NotificationRegistrationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationRegistrationRow(
      reminderId: serializer.fromJson<String>(json['reminderId']),
      platform: serializer.fromJson<String>(json['platform']),
      platformNotificationId: serializer.fromJson<int>(
        json['platformNotificationId'],
      ),
      scheduleRevision: serializer.fromJson<int>(json['scheduleRevision']),
      scheduledLocale: serializer.fromJson<String>(json['scheduledLocale']),
      registeredAtUtc: serializer.fromJson<int>(json['registeredAtUtc']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'reminderId': serializer.toJson<String>(reminderId),
      'platform': serializer.toJson<String>(platform),
      'platformNotificationId': serializer.toJson<int>(platformNotificationId),
      'scheduleRevision': serializer.toJson<int>(scheduleRevision),
      'scheduledLocale': serializer.toJson<String>(scheduledLocale),
      'registeredAtUtc': serializer.toJson<int>(registeredAtUtc),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
    };
  }

  NotificationRegistrationRow copyWith({
    String? reminderId,
    String? platform,
    int? platformNotificationId,
    int? scheduleRevision,
    String? scheduledLocale,
    int? registeredAtUtc,
    Value<String?> lastErrorCode = const Value.absent(),
  }) => NotificationRegistrationRow(
    reminderId: reminderId ?? this.reminderId,
    platform: platform ?? this.platform,
    platformNotificationId:
        platformNotificationId ?? this.platformNotificationId,
    scheduleRevision: scheduleRevision ?? this.scheduleRevision,
    scheduledLocale: scheduledLocale ?? this.scheduledLocale,
    registeredAtUtc: registeredAtUtc ?? this.registeredAtUtc,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
  );
  NotificationRegistrationRow copyWithCompanion(
    NotificationRegistrationsCompanion data,
  ) {
    return NotificationRegistrationRow(
      reminderId: data.reminderId.present
          ? data.reminderId.value
          : this.reminderId,
      platform: data.platform.present ? data.platform.value : this.platform,
      platformNotificationId: data.platformNotificationId.present
          ? data.platformNotificationId.value
          : this.platformNotificationId,
      scheduleRevision: data.scheduleRevision.present
          ? data.scheduleRevision.value
          : this.scheduleRevision,
      scheduledLocale: data.scheduledLocale.present
          ? data.scheduledLocale.value
          : this.scheduledLocale,
      registeredAtUtc: data.registeredAtUtc.present
          ? data.registeredAtUtc.value
          : this.registeredAtUtc,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationRegistrationRow(')
          ..write('reminderId: $reminderId, ')
          ..write('platform: $platform, ')
          ..write('platformNotificationId: $platformNotificationId, ')
          ..write('scheduleRevision: $scheduleRevision, ')
          ..write('scheduledLocale: $scheduledLocale, ')
          ..write('registeredAtUtc: $registeredAtUtc, ')
          ..write('lastErrorCode: $lastErrorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    reminderId,
    platform,
    platformNotificationId,
    scheduleRevision,
    scheduledLocale,
    registeredAtUtc,
    lastErrorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationRegistrationRow &&
          other.reminderId == this.reminderId &&
          other.platform == this.platform &&
          other.platformNotificationId == this.platformNotificationId &&
          other.scheduleRevision == this.scheduleRevision &&
          other.scheduledLocale == this.scheduledLocale &&
          other.registeredAtUtc == this.registeredAtUtc &&
          other.lastErrorCode == this.lastErrorCode);
}

class NotificationRegistrationsCompanion
    extends UpdateCompanion<NotificationRegistrationRow> {
  final Value<String> reminderId;
  final Value<String> platform;
  final Value<int> platformNotificationId;
  final Value<int> scheduleRevision;
  final Value<String> scheduledLocale;
  final Value<int> registeredAtUtc;
  final Value<String?> lastErrorCode;
  final Value<int> rowid;
  const NotificationRegistrationsCompanion({
    this.reminderId = const Value.absent(),
    this.platform = const Value.absent(),
    this.platformNotificationId = const Value.absent(),
    this.scheduleRevision = const Value.absent(),
    this.scheduledLocale = const Value.absent(),
    this.registeredAtUtc = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationRegistrationsCompanion.insert({
    required String reminderId,
    required String platform,
    required int platformNotificationId,
    required int scheduleRevision,
    required String scheduledLocale,
    required int registeredAtUtc,
    this.lastErrorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : reminderId = Value(reminderId),
       platform = Value(platform),
       platformNotificationId = Value(platformNotificationId),
       scheduleRevision = Value(scheduleRevision),
       scheduledLocale = Value(scheduledLocale),
       registeredAtUtc = Value(registeredAtUtc);
  static Insertable<NotificationRegistrationRow> custom({
    Expression<String>? reminderId,
    Expression<String>? platform,
    Expression<int>? platformNotificationId,
    Expression<int>? scheduleRevision,
    Expression<String>? scheduledLocale,
    Expression<int>? registeredAtUtc,
    Expression<String>? lastErrorCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (reminderId != null) 'reminder_id': reminderId,
      if (platform != null) 'platform': platform,
      if (platformNotificationId != null)
        'platform_notification_id': platformNotificationId,
      if (scheduleRevision != null) 'schedule_revision': scheduleRevision,
      if (scheduledLocale != null) 'scheduled_locale': scheduledLocale,
      if (registeredAtUtc != null) 'registered_at_utc': registeredAtUtc,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationRegistrationsCompanion copyWith({
    Value<String>? reminderId,
    Value<String>? platform,
    Value<int>? platformNotificationId,
    Value<int>? scheduleRevision,
    Value<String>? scheduledLocale,
    Value<int>? registeredAtUtc,
    Value<String?>? lastErrorCode,
    Value<int>? rowid,
  }) {
    return NotificationRegistrationsCompanion(
      reminderId: reminderId ?? this.reminderId,
      platform: platform ?? this.platform,
      platformNotificationId:
          platformNotificationId ?? this.platformNotificationId,
      scheduleRevision: scheduleRevision ?? this.scheduleRevision,
      scheduledLocale: scheduledLocale ?? this.scheduledLocale,
      registeredAtUtc: registeredAtUtc ?? this.registeredAtUtc,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (reminderId.present) {
      map['reminder_id'] = Variable<String>(reminderId.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (platformNotificationId.present) {
      map['platform_notification_id'] = Variable<int>(
        platformNotificationId.value,
      );
    }
    if (scheduleRevision.present) {
      map['schedule_revision'] = Variable<int>(scheduleRevision.value);
    }
    if (scheduledLocale.present) {
      map['scheduled_locale'] = Variable<String>(scheduledLocale.value);
    }
    if (registeredAtUtc.present) {
      map['registered_at_utc'] = Variable<int>(registeredAtUtc.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationRegistrationsCompanion(')
          ..write('reminderId: $reminderId, ')
          ..write('platform: $platform, ')
          ..write('platformNotificationId: $platformNotificationId, ')
          ..write('scheduleRevision: $scheduleRevision, ')
          ..write('scheduledLocale: $scheduledLocale, ')
          ..write('registeredAtUtc: $registeredAtUtc, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PlatformJobsTable extends PlatformJobs
    with TableInfo<$PlatformJobsTable, PlatformJobRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlatformJobsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PlatformJobKind, String> kind =
      GeneratedColumn<String>(
        'kind',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PlatformJobKind>($PlatformJobsTable.$converterkind);
  static const VerificationMeta _aggregateIdMeta = const VerificationMeta(
    'aggregateId',
  );
  @override
  late final GeneratedColumn<String> aggregateId = GeneratedColumn<String>(
    'aggregate_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _aggregateRevisionMeta = const VerificationMeta(
    'aggregateRevision',
  );
  @override
  late final GeneratedColumn<int> aggregateRevision = GeneratedColumn<int>(
    'aggregate_revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dedupeKeyMeta = const VerificationMeta(
    'dedupeKey',
  );
  @override
  late final GeneratedColumn<String> dedupeKey = GeneratedColumn<String>(
    'dedupe_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PlatformJobStatus, String>
  status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<PlatformJobStatus>($PlatformJobsTable.$converterstatus);
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _nextAttemptAtUtcMeta = const VerificationMeta(
    'nextAttemptAtUtc',
  );
  @override
  late final GeneratedColumn<int> nextAttemptAtUtc = GeneratedColumn<int>(
    'next_attempt_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastErrorCodeMeta = const VerificationMeta(
    'lastErrorCode',
  );
  @override
  late final GeneratedColumn<String> lastErrorCode = GeneratedColumn<String>(
    'last_error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kind,
    aggregateId,
    aggregateRevision,
    dedupeKey,
    payloadJson,
    status,
    attempts,
    nextAttemptAtUtc,
    lastErrorCode,
    createdAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'platform_jobs';
  @override
  VerificationContext validateIntegrity(
    Insertable<PlatformJobRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('aggregate_id')) {
      context.handle(
        _aggregateIdMeta,
        aggregateId.isAcceptableOrUnknown(
          data['aggregate_id']!,
          _aggregateIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aggregateIdMeta);
    }
    if (data.containsKey('aggregate_revision')) {
      context.handle(
        _aggregateRevisionMeta,
        aggregateRevision.isAcceptableOrUnknown(
          data['aggregate_revision']!,
          _aggregateRevisionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_aggregateRevisionMeta);
    }
    if (data.containsKey('dedupe_key')) {
      context.handle(
        _dedupeKeyMeta,
        dedupeKey.isAcceptableOrUnknown(data['dedupe_key']!, _dedupeKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dedupeKeyMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('next_attempt_at_utc')) {
      context.handle(
        _nextAttemptAtUtcMeta,
        nextAttemptAtUtc.isAcceptableOrUnknown(
          data['next_attempt_at_utc']!,
          _nextAttemptAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_nextAttemptAtUtcMeta);
    }
    if (data.containsKey('last_error_code')) {
      context.handle(
        _lastErrorCodeMeta,
        lastErrorCode.isAcceptableOrUnknown(
          data['last_error_code']!,
          _lastErrorCodeMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PlatformJobRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PlatformJobRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kind: $PlatformJobsTable.$converterkind.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}kind'],
        )!,
      ),
      aggregateId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}aggregate_id'],
      )!,
      aggregateRevision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}aggregate_revision'],
      )!,
      dedupeKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dedupe_key'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      status: $PlatformJobsTable.$converterstatus.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}status'],
        )!,
      ),
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      nextAttemptAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_attempt_at_utc'],
      )!,
      lastErrorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error_code'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $PlatformJobsTable createAlias(String alias) {
    return $PlatformJobsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PlatformJobKind, String, String> $converterkind =
      const EnumNameConverter<PlatformJobKind>(PlatformJobKind.values);
  static JsonTypeConverter2<PlatformJobStatus, String, String>
  $converterstatus = const EnumNameConverter<PlatformJobStatus>(
    PlatformJobStatus.values,
  );
}

class PlatformJobRow extends DataClass implements Insertable<PlatformJobRow> {
  final String id;
  final PlatformJobKind kind;
  final String aggregateId;
  final int aggregateRevision;
  final String dedupeKey;
  final String payloadJson;
  final PlatformJobStatus status;
  final int attempts;
  final int nextAttemptAtUtc;
  final String? lastErrorCode;
  final int createdAtUtc;
  final int updatedAtUtc;
  const PlatformJobRow({
    required this.id,
    required this.kind,
    required this.aggregateId,
    required this.aggregateRevision,
    required this.dedupeKey,
    required this.payloadJson,
    required this.status,
    required this.attempts,
    required this.nextAttemptAtUtc,
    this.lastErrorCode,
    required this.createdAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['kind'] = Variable<String>(
        $PlatformJobsTable.$converterkind.toSql(kind),
      );
    }
    map['aggregate_id'] = Variable<String>(aggregateId);
    map['aggregate_revision'] = Variable<int>(aggregateRevision);
    map['dedupe_key'] = Variable<String>(dedupeKey);
    map['payload_json'] = Variable<String>(payloadJson);
    {
      map['status'] = Variable<String>(
        $PlatformJobsTable.$converterstatus.toSql(status),
      );
    }
    map['attempts'] = Variable<int>(attempts);
    map['next_attempt_at_utc'] = Variable<int>(nextAttemptAtUtc);
    if (!nullToAbsent || lastErrorCode != null) {
      map['last_error_code'] = Variable<String>(lastErrorCode);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    return map;
  }

  PlatformJobsCompanion toCompanion(bool nullToAbsent) {
    return PlatformJobsCompanion(
      id: Value(id),
      kind: Value(kind),
      aggregateId: Value(aggregateId),
      aggregateRevision: Value(aggregateRevision),
      dedupeKey: Value(dedupeKey),
      payloadJson: Value(payloadJson),
      status: Value(status),
      attempts: Value(attempts),
      nextAttemptAtUtc: Value(nextAttemptAtUtc),
      lastErrorCode: lastErrorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(lastErrorCode),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory PlatformJobRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PlatformJobRow(
      id: serializer.fromJson<String>(json['id']),
      kind: $PlatformJobsTable.$converterkind.fromJson(
        serializer.fromJson<String>(json['kind']),
      ),
      aggregateId: serializer.fromJson<String>(json['aggregateId']),
      aggregateRevision: serializer.fromJson<int>(json['aggregateRevision']),
      dedupeKey: serializer.fromJson<String>(json['dedupeKey']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      status: $PlatformJobsTable.$converterstatus.fromJson(
        serializer.fromJson<String>(json['status']),
      ),
      attempts: serializer.fromJson<int>(json['attempts']),
      nextAttemptAtUtc: serializer.fromJson<int>(json['nextAttemptAtUtc']),
      lastErrorCode: serializer.fromJson<String?>(json['lastErrorCode']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kind': serializer.toJson<String>(
        $PlatformJobsTable.$converterkind.toJson(kind),
      ),
      'aggregateId': serializer.toJson<String>(aggregateId),
      'aggregateRevision': serializer.toJson<int>(aggregateRevision),
      'dedupeKey': serializer.toJson<String>(dedupeKey),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'status': serializer.toJson<String>(
        $PlatformJobsTable.$converterstatus.toJson(status),
      ),
      'attempts': serializer.toJson<int>(attempts),
      'nextAttemptAtUtc': serializer.toJson<int>(nextAttemptAtUtc),
      'lastErrorCode': serializer.toJson<String?>(lastErrorCode),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
    };
  }

  PlatformJobRow copyWith({
    String? id,
    PlatformJobKind? kind,
    String? aggregateId,
    int? aggregateRevision,
    String? dedupeKey,
    String? payloadJson,
    PlatformJobStatus? status,
    int? attempts,
    int? nextAttemptAtUtc,
    Value<String?> lastErrorCode = const Value.absent(),
    int? createdAtUtc,
    int? updatedAtUtc,
  }) => PlatformJobRow(
    id: id ?? this.id,
    kind: kind ?? this.kind,
    aggregateId: aggregateId ?? this.aggregateId,
    aggregateRevision: aggregateRevision ?? this.aggregateRevision,
    dedupeKey: dedupeKey ?? this.dedupeKey,
    payloadJson: payloadJson ?? this.payloadJson,
    status: status ?? this.status,
    attempts: attempts ?? this.attempts,
    nextAttemptAtUtc: nextAttemptAtUtc ?? this.nextAttemptAtUtc,
    lastErrorCode: lastErrorCode.present
        ? lastErrorCode.value
        : this.lastErrorCode,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  PlatformJobRow copyWithCompanion(PlatformJobsCompanion data) {
    return PlatformJobRow(
      id: data.id.present ? data.id.value : this.id,
      kind: data.kind.present ? data.kind.value : this.kind,
      aggregateId: data.aggregateId.present
          ? data.aggregateId.value
          : this.aggregateId,
      aggregateRevision: data.aggregateRevision.present
          ? data.aggregateRevision.value
          : this.aggregateRevision,
      dedupeKey: data.dedupeKey.present ? data.dedupeKey.value : this.dedupeKey,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      status: data.status.present ? data.status.value : this.status,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      nextAttemptAtUtc: data.nextAttemptAtUtc.present
          ? data.nextAttemptAtUtc.value
          : this.nextAttemptAtUtc,
      lastErrorCode: data.lastErrorCode.present
          ? data.lastErrorCode.value
          : this.lastErrorCode,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PlatformJobRow(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('aggregateRevision: $aggregateRevision, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAtUtc: $nextAttemptAtUtc, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kind,
    aggregateId,
    aggregateRevision,
    dedupeKey,
    payloadJson,
    status,
    attempts,
    nextAttemptAtUtc,
    lastErrorCode,
    createdAtUtc,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PlatformJobRow &&
          other.id == this.id &&
          other.kind == this.kind &&
          other.aggregateId == this.aggregateId &&
          other.aggregateRevision == this.aggregateRevision &&
          other.dedupeKey == this.dedupeKey &&
          other.payloadJson == this.payloadJson &&
          other.status == this.status &&
          other.attempts == this.attempts &&
          other.nextAttemptAtUtc == this.nextAttemptAtUtc &&
          other.lastErrorCode == this.lastErrorCode &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class PlatformJobsCompanion extends UpdateCompanion<PlatformJobRow> {
  final Value<String> id;
  final Value<PlatformJobKind> kind;
  final Value<String> aggregateId;
  final Value<int> aggregateRevision;
  final Value<String> dedupeKey;
  final Value<String> payloadJson;
  final Value<PlatformJobStatus> status;
  final Value<int> attempts;
  final Value<int> nextAttemptAtUtc;
  final Value<String?> lastErrorCode;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowid;
  const PlatformJobsCompanion({
    this.id = const Value.absent(),
    this.kind = const Value.absent(),
    this.aggregateId = const Value.absent(),
    this.aggregateRevision = const Value.absent(),
    this.dedupeKey = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.status = const Value.absent(),
    this.attempts = const Value.absent(),
    this.nextAttemptAtUtc = const Value.absent(),
    this.lastErrorCode = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlatformJobsCompanion.insert({
    required String id,
    required PlatformJobKind kind,
    required String aggregateId,
    required int aggregateRevision,
    required String dedupeKey,
    required String payloadJson,
    required PlatformJobStatus status,
    this.attempts = const Value.absent(),
    required int nextAttemptAtUtc,
    this.lastErrorCode = const Value.absent(),
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       aggregateId = Value(aggregateId),
       aggregateRevision = Value(aggregateRevision),
       dedupeKey = Value(dedupeKey),
       payloadJson = Value(payloadJson),
       status = Value(status),
       nextAttemptAtUtc = Value(nextAttemptAtUtc),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<PlatformJobRow> custom({
    Expression<String>? id,
    Expression<String>? kind,
    Expression<String>? aggregateId,
    Expression<int>? aggregateRevision,
    Expression<String>? dedupeKey,
    Expression<String>? payloadJson,
    Expression<String>? status,
    Expression<int>? attempts,
    Expression<int>? nextAttemptAtUtc,
    Expression<String>? lastErrorCode,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kind != null) 'kind': kind,
      if (aggregateId != null) 'aggregate_id': aggregateId,
      if (aggregateRevision != null) 'aggregate_revision': aggregateRevision,
      if (dedupeKey != null) 'dedupe_key': dedupeKey,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (status != null) 'status': status,
      if (attempts != null) 'attempts': attempts,
      if (nextAttemptAtUtc != null) 'next_attempt_at_utc': nextAttemptAtUtc,
      if (lastErrorCode != null) 'last_error_code': lastErrorCode,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlatformJobsCompanion copyWith({
    Value<String>? id,
    Value<PlatformJobKind>? kind,
    Value<String>? aggregateId,
    Value<int>? aggregateRevision,
    Value<String>? dedupeKey,
    Value<String>? payloadJson,
    Value<PlatformJobStatus>? status,
    Value<int>? attempts,
    Value<int>? nextAttemptAtUtc,
    Value<String?>? lastErrorCode,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return PlatformJobsCompanion(
      id: id ?? this.id,
      kind: kind ?? this.kind,
      aggregateId: aggregateId ?? this.aggregateId,
      aggregateRevision: aggregateRevision ?? this.aggregateRevision,
      dedupeKey: dedupeKey ?? this.dedupeKey,
      payloadJson: payloadJson ?? this.payloadJson,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      nextAttemptAtUtc: nextAttemptAtUtc ?? this.nextAttemptAtUtc,
      lastErrorCode: lastErrorCode ?? this.lastErrorCode,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(
        $PlatformJobsTable.$converterkind.toSql(kind.value),
      );
    }
    if (aggregateId.present) {
      map['aggregate_id'] = Variable<String>(aggregateId.value);
    }
    if (aggregateRevision.present) {
      map['aggregate_revision'] = Variable<int>(aggregateRevision.value);
    }
    if (dedupeKey.present) {
      map['dedupe_key'] = Variable<String>(dedupeKey.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(
        $PlatformJobsTable.$converterstatus.toSql(status.value),
      );
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (nextAttemptAtUtc.present) {
      map['next_attempt_at_utc'] = Variable<int>(nextAttemptAtUtc.value);
    }
    if (lastErrorCode.present) {
      map['last_error_code'] = Variable<String>(lastErrorCode.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlatformJobsCompanion(')
          ..write('id: $id, ')
          ..write('kind: $kind, ')
          ..write('aggregateId: $aggregateId, ')
          ..write('aggregateRevision: $aggregateRevision, ')
          ..write('dedupeKey: $dedupeKey, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('status: $status, ')
          ..write('attempts: $attempts, ')
          ..write('nextAttemptAtUtc: $nextAttemptAtUtc, ')
          ..write('lastErrorCode: $lastErrorCode, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FoldersTable extends Folders with TableInfo<$FoldersTable, FolderRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _normalizedNameMeta = const VerificationMeta(
    'normalizedName',
  );
  @override
  late final GeneratedColumn<String> normalizedName = GeneratedColumn<String>(
    'normalized_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _sortRankMeta = const VerificationMeta(
    'sortRank',
  );
  @override
  late final GeneratedColumn<int> sortRank = GeneratedColumn<int>(
    'sort_rank',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    normalizedName,
    sortRank,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<FolderRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('normalized_name')) {
      context.handle(
        _normalizedNameMeta,
        normalizedName.isAcceptableOrUnknown(
          data['normalized_name']!,
          _normalizedNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_normalizedNameMeta);
    }
    if (data.containsKey('sort_rank')) {
      context.handle(
        _sortRankMeta,
        sortRank.isAcceptableOrUnknown(data['sort_rank']!, _sortRankMeta),
      );
    } else if (isInserting) {
      context.missing(_sortRankMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FolderRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FolderRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      normalizedName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}normalized_name'],
      )!,
      sortRank: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_rank'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class FolderRow extends DataClass implements Insertable<FolderRow> {
  final String id;
  final String name;
  final String normalizedName;
  final int sortRank;
  final int createdAtUtc;
  final int updatedAtUtc;
  final int rowVersion;
  const FolderRow({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.sortRank,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['normalized_name'] = Variable<String>(normalizedName);
    map['sort_rank'] = Variable<int>(sortRank);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['row_version'] = Variable<int>(rowVersion);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      name: Value(name),
      normalizedName: Value(normalizedName),
      sortRank: Value(sortRank),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      rowVersion: Value(rowVersion),
    );
  }

  factory FolderRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FolderRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      normalizedName: serializer.fromJson<String>(json['normalizedName']),
      sortRank: serializer.fromJson<int>(json['sortRank']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'normalizedName': serializer.toJson<String>(normalizedName),
      'sortRank': serializer.toJson<int>(sortRank),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'rowVersion': serializer.toJson<int>(rowVersion),
    };
  }

  FolderRow copyWith({
    String? id,
    String? name,
    String? normalizedName,
    int? sortRank,
    int? createdAtUtc,
    int? updatedAtUtc,
    int? rowVersion,
  }) => FolderRow(
    id: id ?? this.id,
    name: name ?? this.name,
    normalizedName: normalizedName ?? this.normalizedName,
    sortRank: sortRank ?? this.sortRank,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    rowVersion: rowVersion ?? this.rowVersion,
  );
  FolderRow copyWithCompanion(FoldersCompanion data) {
    return FolderRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      normalizedName: data.normalizedName.present
          ? data.normalizedName.value
          : this.normalizedName,
      sortRank: data.sortRank.present ? data.sortRank.value : this.sortRank,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FolderRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('sortRank: $sortRank, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    normalizedName,
    sortRank,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FolderRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.normalizedName == this.normalizedName &&
          other.sortRank == this.sortRank &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.rowVersion == this.rowVersion);
}

class FoldersCompanion extends UpdateCompanion<FolderRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> normalizedName;
  final Value<int> sortRank;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowVersion;
  final Value<int> rowid;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.normalizedName = const Value.absent(),
    this.sortRank = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FoldersCompanion.insert({
    required String id,
    required String name,
    required String normalizedName,
    required int sortRank,
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       normalizedName = Value(normalizedName),
       sortRank = Value(sortRank),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<FolderRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? normalizedName,
    Expression<int>? sortRank,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (normalizedName != null) 'normalized_name': normalizedName,
      if (sortRank != null) 'sort_rank': sortRank,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowVersion != null) 'row_version': rowVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FoldersCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? normalizedName,
    Value<int>? sortRank,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowVersion,
    Value<int>? rowid,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      normalizedName: normalizedName ?? this.normalizedName,
      sortRank: sortRank ?? this.sortRank,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowVersion: rowVersion ?? this.rowVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (normalizedName.present) {
      map['normalized_name'] = Variable<String>(normalizedName.value);
    }
    if (sortRank.present) {
      map['sort_rank'] = Variable<int>(sortRank.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('normalizedName: $normalizedName, ')
          ..write('sortRank: $sortRank, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotesTable extends Notes with TableInfo<$NotesTable, NoteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES documents (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<String> folderId = GeneratedColumn<String>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES folders (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _pinnedAtUtcMeta = const VerificationMeta(
    'pinnedAtUtc',
  );
  @override
  late final GeneratedColumn<int> pinnedAtUtc = GeneratedColumn<int>(
    'pinned_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _semanticHashMeta = const VerificationMeta(
    'semanticHash',
  );
  @override
  late final GeneratedColumn<String> semanticHash = GeneratedColumn<String>(
    'semantic_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    folderId,
    title,
    pinnedAtUtc,
    deletedAtUtc,
    semanticHash,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('pinned_at_utc')) {
      context.handle(
        _pinnedAtUtcMeta,
        pinnedAtUtc.isAcceptableOrUnknown(
          data['pinned_at_utc']!,
          _pinnedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('semantic_hash')) {
      context.handle(
        _semanticHashMeta,
        semanticHash.isAcceptableOrUnknown(
          data['semantic_hash']!,
          _semanticHashMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_semanticHashMeta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}folder_id'],
      ),
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      pinnedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pinned_at_utc'],
      ),
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      ),
      semanticHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}semantic_hash'],
      )!,
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
    );
  }

  @override
  $NotesTable createAlias(String alias) {
    return $NotesTable(attachedDatabase, alias);
  }
}

class NoteRow extends DataClass implements Insertable<NoteRow> {
  final String id;
  final String documentId;
  final String? folderId;
  final String title;
  final int? pinnedAtUtc;
  final int? deletedAtUtc;
  final String semanticHash;
  final int createdAtUtc;
  final int updatedAtUtc;
  final int rowVersion;
  const NoteRow({
    required this.id,
    required this.documentId,
    this.folderId,
    required this.title,
    this.pinnedAtUtc,
    this.deletedAtUtc,
    required this.semanticHash,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<String>(folderId);
    }
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || pinnedAtUtc != null) {
      map['pinned_at_utc'] = Variable<int>(pinnedAtUtc);
    }
    if (!nullToAbsent || deletedAtUtc != null) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    }
    map['semantic_hash'] = Variable<String>(semanticHash);
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['row_version'] = Variable<int>(rowVersion);
    return map;
  }

  NotesCompanion toCompanion(bool nullToAbsent) {
    return NotesCompanion(
      id: Value(id),
      documentId: Value(documentId),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      title: Value(title),
      pinnedAtUtc: pinnedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(pinnedAtUtc),
      deletedAtUtc: deletedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAtUtc),
      semanticHash: Value(semanticHash),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      rowVersion: Value(rowVersion),
    );
  }

  factory NoteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteRow(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      folderId: serializer.fromJson<String?>(json['folderId']),
      title: serializer.fromJson<String>(json['title']),
      pinnedAtUtc: serializer.fromJson<int?>(json['pinnedAtUtc']),
      deletedAtUtc: serializer.fromJson<int?>(json['deletedAtUtc']),
      semanticHash: serializer.fromJson<String>(json['semanticHash']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'folderId': serializer.toJson<String?>(folderId),
      'title': serializer.toJson<String>(title),
      'pinnedAtUtc': serializer.toJson<int?>(pinnedAtUtc),
      'deletedAtUtc': serializer.toJson<int?>(deletedAtUtc),
      'semanticHash': serializer.toJson<String>(semanticHash),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'rowVersion': serializer.toJson<int>(rowVersion),
    };
  }

  NoteRow copyWith({
    String? id,
    String? documentId,
    Value<String?> folderId = const Value.absent(),
    String? title,
    Value<int?> pinnedAtUtc = const Value.absent(),
    Value<int?> deletedAtUtc = const Value.absent(),
    String? semanticHash,
    int? createdAtUtc,
    int? updatedAtUtc,
    int? rowVersion,
  }) => NoteRow(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    folderId: folderId.present ? folderId.value : this.folderId,
    title: title ?? this.title,
    pinnedAtUtc: pinnedAtUtc.present ? pinnedAtUtc.value : this.pinnedAtUtc,
    deletedAtUtc: deletedAtUtc.present ? deletedAtUtc.value : this.deletedAtUtc,
    semanticHash: semanticHash ?? this.semanticHash,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    rowVersion: rowVersion ?? this.rowVersion,
  );
  NoteRow copyWithCompanion(NotesCompanion data) {
    return NoteRow(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      title: data.title.present ? data.title.value : this.title,
      pinnedAtUtc: data.pinnedAtUtc.present
          ? data.pinnedAtUtc.value
          : this.pinnedAtUtc,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      semanticHash: data.semanticHash.present
          ? data.semanticHash.value
          : this.semanticHash,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteRow(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title, ')
          ..write('pinnedAtUtc: $pinnedAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    folderId,
    title,
    pinnedAtUtc,
    deletedAtUtc,
    semanticHash,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteRow &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.folderId == this.folderId &&
          other.title == this.title &&
          other.pinnedAtUtc == this.pinnedAtUtc &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.semanticHash == this.semanticHash &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.rowVersion == this.rowVersion);
}

class NotesCompanion extends UpdateCompanion<NoteRow> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<String?> folderId;
  final Value<String> title;
  final Value<int?> pinnedAtUtc;
  final Value<int?> deletedAtUtc;
  final Value<String> semanticHash;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowVersion;
  final Value<int> rowid;
  const NotesCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.folderId = const Value.absent(),
    this.title = const Value.absent(),
    this.pinnedAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.semanticHash = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotesCompanion.insert({
    required String id,
    required String documentId,
    this.folderId = const Value.absent(),
    this.title = const Value.absent(),
    this.pinnedAtUtc = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    required String semanticHash,
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       semanticHash = Value(semanticHash),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<NoteRow> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? folderId,
    Expression<String>? title,
    Expression<int>? pinnedAtUtc,
    Expression<int>? deletedAtUtc,
    Expression<String>? semanticHash,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (folderId != null) 'folder_id': folderId,
      if (title != null) 'title': title,
      if (pinnedAtUtc != null) 'pinned_at_utc': pinnedAtUtc,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (semanticHash != null) 'semantic_hash': semanticHash,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowVersion != null) 'row_version': rowVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotesCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<String?>? folderId,
    Value<String>? title,
    Value<int?>? pinnedAtUtc,
    Value<int?>? deletedAtUtc,
    Value<String>? semanticHash,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowVersion,
    Value<int>? rowid,
  }) {
    return NotesCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      folderId: folderId ?? this.folderId,
      title: title ?? this.title,
      pinnedAtUtc: pinnedAtUtc ?? this.pinnedAtUtc,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      semanticHash: semanticHash ?? this.semanticHash,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowVersion: rowVersion ?? this.rowVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<String>(folderId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (pinnedAtUtc.present) {
      map['pinned_at_utc'] = Variable<int>(pinnedAtUtc.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (semanticHash.present) {
      map['semantic_hash'] = Variable<String>(semanticHash.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotesCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('folderId: $folderId, ')
          ..write('title: $title, ')
          ..write('pinnedAtUtc: $pinnedAtUtc, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('semanticHash: $semanticHash, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $TrashEntriesTable extends TrashEntries
    with TableInfo<$TrashEntriesTable, TrashEntryRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrashEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<TrashEntityType, String>
  entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<TrashEntityType>($TrashEntriesTable.$converterentityType);
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deletedAtUtcMeta = const VerificationMeta(
    'deletedAtUtc',
  );
  @override
  late final GeneratedColumn<int> deletedAtUtc = GeneratedColumn<int>(
    'deleted_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _purgeAfterUtcMeta = const VerificationMeta(
    'purgeAfterUtc',
  );
  @override
  late final GeneratedColumn<int> purgeAfterUtc = GeneratedColumn<int>(
    'purge_after_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restoreContextJsonMeta =
      const VerificationMeta('restoreContextJson');
  @override
  late final GeneratedColumn<String> restoreContextJson =
      GeneratedColumn<String>(
        'restore_context_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _snapshotSha256Meta = const VerificationMeta(
    'snapshotSha256',
  );
  @override
  late final GeneratedColumn<String> snapshotSha256 = GeneratedColumn<String>(
    'snapshot_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    entityType,
    entityId,
    deletedAtUtc,
    purgeAfterUtc,
    restoreContextJson,
    snapshotSha256,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'trash_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<TrashEntryRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('deleted_at_utc')) {
      context.handle(
        _deletedAtUtcMeta,
        deletedAtUtc.isAcceptableOrUnknown(
          data['deleted_at_utc']!,
          _deletedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deletedAtUtcMeta);
    }
    if (data.containsKey('purge_after_utc')) {
      context.handle(
        _purgeAfterUtcMeta,
        purgeAfterUtc.isAcceptableOrUnknown(
          data['purge_after_utc']!,
          _purgeAfterUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_purgeAfterUtcMeta);
    }
    if (data.containsKey('restore_context_json')) {
      context.handle(
        _restoreContextJsonMeta,
        restoreContextJson.isAcceptableOrUnknown(
          data['restore_context_json']!,
          _restoreContextJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_restoreContextJsonMeta);
    }
    if (data.containsKey('snapshot_sha256')) {
      context.handle(
        _snapshotSha256Meta,
        snapshotSha256.isAcceptableOrUnknown(
          data['snapshot_sha256']!,
          _snapshotSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_snapshotSha256Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TrashEntryRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrashEntryRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      entityType: $TrashEntriesTable.$converterentityType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}entity_type'],
        )!,
      ),
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      deletedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}deleted_at_utc'],
      )!,
      purgeAfterUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}purge_after_utc'],
      )!,
      restoreContextJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restore_context_json'],
      )!,
      snapshotSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}snapshot_sha256'],
      )!,
    );
  }

  @override
  $TrashEntriesTable createAlias(String alias) {
    return $TrashEntriesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<TrashEntityType, String, String>
  $converterentityType = const EnumNameConverter<TrashEntityType>(
    TrashEntityType.values,
  );
}

class TrashEntryRow extends DataClass implements Insertable<TrashEntryRow> {
  final String id;
  final TrashEntityType entityType;
  final String entityId;
  final int deletedAtUtc;
  final int purgeAfterUtc;
  final String restoreContextJson;
  final String snapshotSha256;
  const TrashEntryRow({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.deletedAtUtc,
    required this.purgeAfterUtc,
    required this.restoreContextJson,
    required this.snapshotSha256,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    {
      map['entity_type'] = Variable<String>(
        $TrashEntriesTable.$converterentityType.toSql(entityType),
      );
    }
    map['entity_id'] = Variable<String>(entityId);
    map['deleted_at_utc'] = Variable<int>(deletedAtUtc);
    map['purge_after_utc'] = Variable<int>(purgeAfterUtc);
    map['restore_context_json'] = Variable<String>(restoreContextJson);
    map['snapshot_sha256'] = Variable<String>(snapshotSha256);
    return map;
  }

  TrashEntriesCompanion toCompanion(bool nullToAbsent) {
    return TrashEntriesCompanion(
      id: Value(id),
      entityType: Value(entityType),
      entityId: Value(entityId),
      deletedAtUtc: Value(deletedAtUtc),
      purgeAfterUtc: Value(purgeAfterUtc),
      restoreContextJson: Value(restoreContextJson),
      snapshotSha256: Value(snapshotSha256),
    );
  }

  factory TrashEntryRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrashEntryRow(
      id: serializer.fromJson<String>(json['id']),
      entityType: $TrashEntriesTable.$converterentityType.fromJson(
        serializer.fromJson<String>(json['entityType']),
      ),
      entityId: serializer.fromJson<String>(json['entityId']),
      deletedAtUtc: serializer.fromJson<int>(json['deletedAtUtc']),
      purgeAfterUtc: serializer.fromJson<int>(json['purgeAfterUtc']),
      restoreContextJson: serializer.fromJson<String>(
        json['restoreContextJson'],
      ),
      snapshotSha256: serializer.fromJson<String>(json['snapshotSha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'entityType': serializer.toJson<String>(
        $TrashEntriesTable.$converterentityType.toJson(entityType),
      ),
      'entityId': serializer.toJson<String>(entityId),
      'deletedAtUtc': serializer.toJson<int>(deletedAtUtc),
      'purgeAfterUtc': serializer.toJson<int>(purgeAfterUtc),
      'restoreContextJson': serializer.toJson<String>(restoreContextJson),
      'snapshotSha256': serializer.toJson<String>(snapshotSha256),
    };
  }

  TrashEntryRow copyWith({
    String? id,
    TrashEntityType? entityType,
    String? entityId,
    int? deletedAtUtc,
    int? purgeAfterUtc,
    String? restoreContextJson,
    String? snapshotSha256,
  }) => TrashEntryRow(
    id: id ?? this.id,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
    purgeAfterUtc: purgeAfterUtc ?? this.purgeAfterUtc,
    restoreContextJson: restoreContextJson ?? this.restoreContextJson,
    snapshotSha256: snapshotSha256 ?? this.snapshotSha256,
  );
  TrashEntryRow copyWithCompanion(TrashEntriesCompanion data) {
    return TrashEntryRow(
      id: data.id.present ? data.id.value : this.id,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      deletedAtUtc: data.deletedAtUtc.present
          ? data.deletedAtUtc.value
          : this.deletedAtUtc,
      purgeAfterUtc: data.purgeAfterUtc.present
          ? data.purgeAfterUtc.value
          : this.purgeAfterUtc,
      restoreContextJson: data.restoreContextJson.present
          ? data.restoreContextJson.value
          : this.restoreContextJson,
      snapshotSha256: data.snapshotSha256.present
          ? data.snapshotSha256.value
          : this.snapshotSha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrashEntryRow(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('purgeAfterUtc: $purgeAfterUtc, ')
          ..write('restoreContextJson: $restoreContextJson, ')
          ..write('snapshotSha256: $snapshotSha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    entityType,
    entityId,
    deletedAtUtc,
    purgeAfterUtc,
    restoreContextJson,
    snapshotSha256,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrashEntryRow &&
          other.id == this.id &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.deletedAtUtc == this.deletedAtUtc &&
          other.purgeAfterUtc == this.purgeAfterUtc &&
          other.restoreContextJson == this.restoreContextJson &&
          other.snapshotSha256 == this.snapshotSha256);
}

class TrashEntriesCompanion extends UpdateCompanion<TrashEntryRow> {
  final Value<String> id;
  final Value<TrashEntityType> entityType;
  final Value<String> entityId;
  final Value<int> deletedAtUtc;
  final Value<int> purgeAfterUtc;
  final Value<String> restoreContextJson;
  final Value<String> snapshotSha256;
  final Value<int> rowid;
  const TrashEntriesCompanion({
    this.id = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.deletedAtUtc = const Value.absent(),
    this.purgeAfterUtc = const Value.absent(),
    this.restoreContextJson = const Value.absent(),
    this.snapshotSha256 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrashEntriesCompanion.insert({
    required String id,
    required TrashEntityType entityType,
    required String entityId,
    required int deletedAtUtc,
    required int purgeAfterUtc,
    required String restoreContextJson,
    required String snapshotSha256,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       entityType = Value(entityType),
       entityId = Value(entityId),
       deletedAtUtc = Value(deletedAtUtc),
       purgeAfterUtc = Value(purgeAfterUtc),
       restoreContextJson = Value(restoreContextJson),
       snapshotSha256 = Value(snapshotSha256);
  static Insertable<TrashEntryRow> custom({
    Expression<String>? id,
    Expression<String>? entityType,
    Expression<String>? entityId,
    Expression<int>? deletedAtUtc,
    Expression<int>? purgeAfterUtc,
    Expression<String>? restoreContextJson,
    Expression<String>? snapshotSha256,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (deletedAtUtc != null) 'deleted_at_utc': deletedAtUtc,
      if (purgeAfterUtc != null) 'purge_after_utc': purgeAfterUtc,
      if (restoreContextJson != null)
        'restore_context_json': restoreContextJson,
      if (snapshotSha256 != null) 'snapshot_sha256': snapshotSha256,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrashEntriesCompanion copyWith({
    Value<String>? id,
    Value<TrashEntityType>? entityType,
    Value<String>? entityId,
    Value<int>? deletedAtUtc,
    Value<int>? purgeAfterUtc,
    Value<String>? restoreContextJson,
    Value<String>? snapshotSha256,
    Value<int>? rowid,
  }) {
    return TrashEntriesCompanion(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      deletedAtUtc: deletedAtUtc ?? this.deletedAtUtc,
      purgeAfterUtc: purgeAfterUtc ?? this.purgeAfterUtc,
      restoreContextJson: restoreContextJson ?? this.restoreContextJson,
      snapshotSha256: snapshotSha256 ?? this.snapshotSha256,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(
        $TrashEntriesTable.$converterentityType.toSql(entityType.value),
      );
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (deletedAtUtc.present) {
      map['deleted_at_utc'] = Variable<int>(deletedAtUtc.value);
    }
    if (purgeAfterUtc.present) {
      map['purge_after_utc'] = Variable<int>(purgeAfterUtc.value);
    }
    if (restoreContextJson.present) {
      map['restore_context_json'] = Variable<String>(restoreContextJson.value);
    }
    if (snapshotSha256.present) {
      map['snapshot_sha256'] = Variable<String>(snapshotSha256.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrashEntriesCompanion(')
          ..write('id: $id, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('deletedAtUtc: $deletedAtUtc, ')
          ..write('purgeAfterUtc: $purgeAfterUtc, ')
          ..write('restoreContextJson: $restoreContextJson, ')
          ..write('snapshotSha256: $snapshotSha256, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PastEventsTable extends PastEvents
    with TableInfo<$PastEventsTable, PastEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PastEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES documents (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _sourceTaskIdMeta = const VerificationMeta(
    'sourceTaskId',
  );
  @override
  late final GeneratedColumn<String> sourceTaskId = GeneratedColumn<String>(
    'source_task_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _appendSequenceMeta = const VerificationMeta(
    'appendSequence',
  );
  @override
  late final GeneratedColumn<int> appendSequence = GeneratedColumn<int>(
    'append_sequence',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _completedAtUtcMeta = const VerificationMeta(
    'completedAtUtc',
  );
  @override
  late final GeneratedColumn<int> completedAtUtc = GeneratedColumn<int>(
    'completed_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completionLocalDateMeta =
      const VerificationMeta('completionLocalDate');
  @override
  late final GeneratedColumn<String> completionLocalDate =
      GeneratedColumn<String>(
        'completion_local_date',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _completionZoneIdMeta = const VerificationMeta(
    'completionZoneId',
  );
  @override
  late final GeneratedColumn<String> completionZoneId = GeneratedColumn<String>(
    'completion_zone_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceSnapshotVersionMeta =
      const VerificationMeta('sourceSnapshotVersion');
  @override
  late final GeneratedColumn<int> sourceSnapshotVersion = GeneratedColumn<int>(
    'source_snapshot_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _sourceSnapshotJsonMeta =
      const VerificationMeta('sourceSnapshotJson');
  @override
  late final GeneratedColumn<String> sourceSnapshotJson =
      GeneratedColumn<String>(
        'source_snapshot_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _sourceSha256Meta = const VerificationMeta(
    'sourceSha256',
  );
  @override
  late final GeneratedColumn<String> sourceSha256 = GeneratedColumn<String>(
    'source_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<PastAnchorState, String>
  anchorState = GeneratedColumn<String>(
    'anchor_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<PastAnchorState>($PastEventsTable.$converteranchorState);
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rowVersionMeta = const VerificationMeta(
    'rowVersion',
  );
  @override
  late final GeneratedColumn<int> rowVersion = GeneratedColumn<int>(
    'row_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    documentId,
    sourceTaskId,
    appendSequence,
    completedAtUtc,
    completionLocalDate,
    completionZoneId,
    sourceSnapshotVersion,
    sourceSnapshotJson,
    sourceSha256,
    anchorState,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'past_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<PastEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    } else if (isInserting) {
      context.missing(_documentIdMeta);
    }
    if (data.containsKey('source_task_id')) {
      context.handle(
        _sourceTaskIdMeta,
        sourceTaskId.isAcceptableOrUnknown(
          data['source_task_id']!,
          _sourceTaskIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceTaskIdMeta);
    }
    if (data.containsKey('append_sequence')) {
      context.handle(
        _appendSequenceMeta,
        appendSequence.isAcceptableOrUnknown(
          data['append_sequence']!,
          _appendSequenceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_appendSequenceMeta);
    }
    if (data.containsKey('completed_at_utc')) {
      context.handle(
        _completedAtUtcMeta,
        completedAtUtc.isAcceptableOrUnknown(
          data['completed_at_utc']!,
          _completedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completedAtUtcMeta);
    }
    if (data.containsKey('completion_local_date')) {
      context.handle(
        _completionLocalDateMeta,
        completionLocalDate.isAcceptableOrUnknown(
          data['completion_local_date']!,
          _completionLocalDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completionLocalDateMeta);
    }
    if (data.containsKey('completion_zone_id')) {
      context.handle(
        _completionZoneIdMeta,
        completionZoneId.isAcceptableOrUnknown(
          data['completion_zone_id']!,
          _completionZoneIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_completionZoneIdMeta);
    }
    if (data.containsKey('source_snapshot_version')) {
      context.handle(
        _sourceSnapshotVersionMeta,
        sourceSnapshotVersion.isAcceptableOrUnknown(
          data['source_snapshot_version']!,
          _sourceSnapshotVersionMeta,
        ),
      );
    }
    if (data.containsKey('source_snapshot_json')) {
      context.handle(
        _sourceSnapshotJsonMeta,
        sourceSnapshotJson.isAcceptableOrUnknown(
          data['source_snapshot_json']!,
          _sourceSnapshotJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceSnapshotJsonMeta);
    }
    if (data.containsKey('source_sha256')) {
      context.handle(
        _sourceSha256Meta,
        sourceSha256.isAcceptableOrUnknown(
          data['source_sha256']!,
          _sourceSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceSha256Meta);
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    if (data.containsKey('row_version')) {
      context.handle(
        _rowVersionMeta,
        rowVersion.isAcceptableOrUnknown(data['row_version']!, _rowVersionMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PastEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PastEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      )!,
      sourceTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_task_id'],
      )!,
      appendSequence: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}append_sequence'],
      )!,
      completedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_utc'],
      )!,
      completionLocalDate: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completion_local_date'],
      )!,
      completionZoneId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}completion_zone_id'],
      )!,
      sourceSnapshotVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_snapshot_version'],
      )!,
      sourceSnapshotJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_snapshot_json'],
      )!,
      sourceSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_sha256'],
      )!,
      anchorState: $PastEventsTable.$converteranchorState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}anchor_state'],
        )!,
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
      rowVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_version'],
      )!,
    );
  }

  @override
  $PastEventsTable createAlias(String alias) {
    return $PastEventsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PastAnchorState, String, String>
  $converteranchorState = const EnumNameConverter<PastAnchorState>(
    PastAnchorState.values,
  );
}

class PastEventRow extends DataClass implements Insertable<PastEventRow> {
  final String id;
  final String documentId;
  final String sourceTaskId;
  final int appendSequence;
  final int completedAtUtc;
  final String completionLocalDate;
  final String completionZoneId;
  final int sourceSnapshotVersion;
  final String sourceSnapshotJson;
  final String sourceSha256;
  final PastAnchorState anchorState;
  final int createdAtUtc;
  final int updatedAtUtc;
  final int rowVersion;
  const PastEventRow({
    required this.id,
    required this.documentId,
    required this.sourceTaskId,
    required this.appendSequence,
    required this.completedAtUtc,
    required this.completionLocalDate,
    required this.completionZoneId,
    required this.sourceSnapshotVersion,
    required this.sourceSnapshotJson,
    required this.sourceSha256,
    required this.anchorState,
    required this.createdAtUtc,
    required this.updatedAtUtc,
    required this.rowVersion,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['document_id'] = Variable<String>(documentId);
    map['source_task_id'] = Variable<String>(sourceTaskId);
    map['append_sequence'] = Variable<int>(appendSequence);
    map['completed_at_utc'] = Variable<int>(completedAtUtc);
    map['completion_local_date'] = Variable<String>(completionLocalDate);
    map['completion_zone_id'] = Variable<String>(completionZoneId);
    map['source_snapshot_version'] = Variable<int>(sourceSnapshotVersion);
    map['source_snapshot_json'] = Variable<String>(sourceSnapshotJson);
    map['source_sha256'] = Variable<String>(sourceSha256);
    {
      map['anchor_state'] = Variable<String>(
        $PastEventsTable.$converteranchorState.toSql(anchorState),
      );
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    map['row_version'] = Variable<int>(rowVersion);
    return map;
  }

  PastEventsCompanion toCompanion(bool nullToAbsent) {
    return PastEventsCompanion(
      id: Value(id),
      documentId: Value(documentId),
      sourceTaskId: Value(sourceTaskId),
      appendSequence: Value(appendSequence),
      completedAtUtc: Value(completedAtUtc),
      completionLocalDate: Value(completionLocalDate),
      completionZoneId: Value(completionZoneId),
      sourceSnapshotVersion: Value(sourceSnapshotVersion),
      sourceSnapshotJson: Value(sourceSnapshotJson),
      sourceSha256: Value(sourceSha256),
      anchorState: Value(anchorState),
      createdAtUtc: Value(createdAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
      rowVersion: Value(rowVersion),
    );
  }

  factory PastEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PastEventRow(
      id: serializer.fromJson<String>(json['id']),
      documentId: serializer.fromJson<String>(json['documentId']),
      sourceTaskId: serializer.fromJson<String>(json['sourceTaskId']),
      appendSequence: serializer.fromJson<int>(json['appendSequence']),
      completedAtUtc: serializer.fromJson<int>(json['completedAtUtc']),
      completionLocalDate: serializer.fromJson<String>(
        json['completionLocalDate'],
      ),
      completionZoneId: serializer.fromJson<String>(json['completionZoneId']),
      sourceSnapshotVersion: serializer.fromJson<int>(
        json['sourceSnapshotVersion'],
      ),
      sourceSnapshotJson: serializer.fromJson<String>(
        json['sourceSnapshotJson'],
      ),
      sourceSha256: serializer.fromJson<String>(json['sourceSha256']),
      anchorState: $PastEventsTable.$converteranchorState.fromJson(
        serializer.fromJson<String>(json['anchorState']),
      ),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
      rowVersion: serializer.fromJson<int>(json['rowVersion']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'documentId': serializer.toJson<String>(documentId),
      'sourceTaskId': serializer.toJson<String>(sourceTaskId),
      'appendSequence': serializer.toJson<int>(appendSequence),
      'completedAtUtc': serializer.toJson<int>(completedAtUtc),
      'completionLocalDate': serializer.toJson<String>(completionLocalDate),
      'completionZoneId': serializer.toJson<String>(completionZoneId),
      'sourceSnapshotVersion': serializer.toJson<int>(sourceSnapshotVersion),
      'sourceSnapshotJson': serializer.toJson<String>(sourceSnapshotJson),
      'sourceSha256': serializer.toJson<String>(sourceSha256),
      'anchorState': serializer.toJson<String>(
        $PastEventsTable.$converteranchorState.toJson(anchorState),
      ),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
      'rowVersion': serializer.toJson<int>(rowVersion),
    };
  }

  PastEventRow copyWith({
    String? id,
    String? documentId,
    String? sourceTaskId,
    int? appendSequence,
    int? completedAtUtc,
    String? completionLocalDate,
    String? completionZoneId,
    int? sourceSnapshotVersion,
    String? sourceSnapshotJson,
    String? sourceSha256,
    PastAnchorState? anchorState,
    int? createdAtUtc,
    int? updatedAtUtc,
    int? rowVersion,
  }) => PastEventRow(
    id: id ?? this.id,
    documentId: documentId ?? this.documentId,
    sourceTaskId: sourceTaskId ?? this.sourceTaskId,
    appendSequence: appendSequence ?? this.appendSequence,
    completedAtUtc: completedAtUtc ?? this.completedAtUtc,
    completionLocalDate: completionLocalDate ?? this.completionLocalDate,
    completionZoneId: completionZoneId ?? this.completionZoneId,
    sourceSnapshotVersion: sourceSnapshotVersion ?? this.sourceSnapshotVersion,
    sourceSnapshotJson: sourceSnapshotJson ?? this.sourceSnapshotJson,
    sourceSha256: sourceSha256 ?? this.sourceSha256,
    anchorState: anchorState ?? this.anchorState,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    rowVersion: rowVersion ?? this.rowVersion,
  );
  PastEventRow copyWithCompanion(PastEventsCompanion data) {
    return PastEventRow(
      id: data.id.present ? data.id.value : this.id,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      sourceTaskId: data.sourceTaskId.present
          ? data.sourceTaskId.value
          : this.sourceTaskId,
      appendSequence: data.appendSequence.present
          ? data.appendSequence.value
          : this.appendSequence,
      completedAtUtc: data.completedAtUtc.present
          ? data.completedAtUtc.value
          : this.completedAtUtc,
      completionLocalDate: data.completionLocalDate.present
          ? data.completionLocalDate.value
          : this.completionLocalDate,
      completionZoneId: data.completionZoneId.present
          ? data.completionZoneId.value
          : this.completionZoneId,
      sourceSnapshotVersion: data.sourceSnapshotVersion.present
          ? data.sourceSnapshotVersion.value
          : this.sourceSnapshotVersion,
      sourceSnapshotJson: data.sourceSnapshotJson.present
          ? data.sourceSnapshotJson.value
          : this.sourceSnapshotJson,
      sourceSha256: data.sourceSha256.present
          ? data.sourceSha256.value
          : this.sourceSha256,
      anchorState: data.anchorState.present
          ? data.anchorState.value
          : this.anchorState,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
      rowVersion: data.rowVersion.present
          ? data.rowVersion.value
          : this.rowVersion,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PastEventRow(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('sourceTaskId: $sourceTaskId, ')
          ..write('appendSequence: $appendSequence, ')
          ..write('completedAtUtc: $completedAtUtc, ')
          ..write('completionLocalDate: $completionLocalDate, ')
          ..write('completionZoneId: $completionZoneId, ')
          ..write('sourceSnapshotVersion: $sourceSnapshotVersion, ')
          ..write('sourceSnapshotJson: $sourceSnapshotJson, ')
          ..write('sourceSha256: $sourceSha256, ')
          ..write('anchorState: $anchorState, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    documentId,
    sourceTaskId,
    appendSequence,
    completedAtUtc,
    completionLocalDate,
    completionZoneId,
    sourceSnapshotVersion,
    sourceSnapshotJson,
    sourceSha256,
    anchorState,
    createdAtUtc,
    updatedAtUtc,
    rowVersion,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PastEventRow &&
          other.id == this.id &&
          other.documentId == this.documentId &&
          other.sourceTaskId == this.sourceTaskId &&
          other.appendSequence == this.appendSequence &&
          other.completedAtUtc == this.completedAtUtc &&
          other.completionLocalDate == this.completionLocalDate &&
          other.completionZoneId == this.completionZoneId &&
          other.sourceSnapshotVersion == this.sourceSnapshotVersion &&
          other.sourceSnapshotJson == this.sourceSnapshotJson &&
          other.sourceSha256 == this.sourceSha256 &&
          other.anchorState == this.anchorState &&
          other.createdAtUtc == this.createdAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc &&
          other.rowVersion == this.rowVersion);
}

class PastEventsCompanion extends UpdateCompanion<PastEventRow> {
  final Value<String> id;
  final Value<String> documentId;
  final Value<String> sourceTaskId;
  final Value<int> appendSequence;
  final Value<int> completedAtUtc;
  final Value<String> completionLocalDate;
  final Value<String> completionZoneId;
  final Value<int> sourceSnapshotVersion;
  final Value<String> sourceSnapshotJson;
  final Value<String> sourceSha256;
  final Value<PastAnchorState> anchorState;
  final Value<int> createdAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowVersion;
  final Value<int> rowid;
  const PastEventsCompanion({
    this.id = const Value.absent(),
    this.documentId = const Value.absent(),
    this.sourceTaskId = const Value.absent(),
    this.appendSequence = const Value.absent(),
    this.completedAtUtc = const Value.absent(),
    this.completionLocalDate = const Value.absent(),
    this.completionZoneId = const Value.absent(),
    this.sourceSnapshotVersion = const Value.absent(),
    this.sourceSnapshotJson = const Value.absent(),
    this.sourceSha256 = const Value.absent(),
    this.anchorState = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PastEventsCompanion.insert({
    required String id,
    required String documentId,
    required String sourceTaskId,
    required int appendSequence,
    required int completedAtUtc,
    required String completionLocalDate,
    required String completionZoneId,
    this.sourceSnapshotVersion = const Value.absent(),
    required String sourceSnapshotJson,
    required String sourceSha256,
    required PastAnchorState anchorState,
    required int createdAtUtc,
    required int updatedAtUtc,
    this.rowVersion = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       documentId = Value(documentId),
       sourceTaskId = Value(sourceTaskId),
       appendSequence = Value(appendSequence),
       completedAtUtc = Value(completedAtUtc),
       completionLocalDate = Value(completionLocalDate),
       completionZoneId = Value(completionZoneId),
       sourceSnapshotJson = Value(sourceSnapshotJson),
       sourceSha256 = Value(sourceSha256),
       anchorState = Value(anchorState),
       createdAtUtc = Value(createdAtUtc),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<PastEventRow> custom({
    Expression<String>? id,
    Expression<String>? documentId,
    Expression<String>? sourceTaskId,
    Expression<int>? appendSequence,
    Expression<int>? completedAtUtc,
    Expression<String>? completionLocalDate,
    Expression<String>? completionZoneId,
    Expression<int>? sourceSnapshotVersion,
    Expression<String>? sourceSnapshotJson,
    Expression<String>? sourceSha256,
    Expression<String>? anchorState,
    Expression<int>? createdAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowVersion,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (documentId != null) 'document_id': documentId,
      if (sourceTaskId != null) 'source_task_id': sourceTaskId,
      if (appendSequence != null) 'append_sequence': appendSequence,
      if (completedAtUtc != null) 'completed_at_utc': completedAtUtc,
      if (completionLocalDate != null)
        'completion_local_date': completionLocalDate,
      if (completionZoneId != null) 'completion_zone_id': completionZoneId,
      if (sourceSnapshotVersion != null)
        'source_snapshot_version': sourceSnapshotVersion,
      if (sourceSnapshotJson != null)
        'source_snapshot_json': sourceSnapshotJson,
      if (sourceSha256 != null) 'source_sha256': sourceSha256,
      if (anchorState != null) 'anchor_state': anchorState,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowVersion != null) 'row_version': rowVersion,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PastEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? documentId,
    Value<String>? sourceTaskId,
    Value<int>? appendSequence,
    Value<int>? completedAtUtc,
    Value<String>? completionLocalDate,
    Value<String>? completionZoneId,
    Value<int>? sourceSnapshotVersion,
    Value<String>? sourceSnapshotJson,
    Value<String>? sourceSha256,
    Value<PastAnchorState>? anchorState,
    Value<int>? createdAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowVersion,
    Value<int>? rowid,
  }) {
    return PastEventsCompanion(
      id: id ?? this.id,
      documentId: documentId ?? this.documentId,
      sourceTaskId: sourceTaskId ?? this.sourceTaskId,
      appendSequence: appendSequence ?? this.appendSequence,
      completedAtUtc: completedAtUtc ?? this.completedAtUtc,
      completionLocalDate: completionLocalDate ?? this.completionLocalDate,
      completionZoneId: completionZoneId ?? this.completionZoneId,
      sourceSnapshotVersion:
          sourceSnapshotVersion ?? this.sourceSnapshotVersion,
      sourceSnapshotJson: sourceSnapshotJson ?? this.sourceSnapshotJson,
      sourceSha256: sourceSha256 ?? this.sourceSha256,
      anchorState: anchorState ?? this.anchorState,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowVersion: rowVersion ?? this.rowVersion,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (sourceTaskId.present) {
      map['source_task_id'] = Variable<String>(sourceTaskId.value);
    }
    if (appendSequence.present) {
      map['append_sequence'] = Variable<int>(appendSequence.value);
    }
    if (completedAtUtc.present) {
      map['completed_at_utc'] = Variable<int>(completedAtUtc.value);
    }
    if (completionLocalDate.present) {
      map['completion_local_date'] = Variable<String>(
        completionLocalDate.value,
      );
    }
    if (completionZoneId.present) {
      map['completion_zone_id'] = Variable<String>(completionZoneId.value);
    }
    if (sourceSnapshotVersion.present) {
      map['source_snapshot_version'] = Variable<int>(
        sourceSnapshotVersion.value,
      );
    }
    if (sourceSnapshotJson.present) {
      map['source_snapshot_json'] = Variable<String>(sourceSnapshotJson.value);
    }
    if (sourceSha256.present) {
      map['source_sha256'] = Variable<String>(sourceSha256.value);
    }
    if (anchorState.present) {
      map['anchor_state'] = Variable<String>(
        $PastEventsTable.$converteranchorState.toSql(anchorState.value),
      );
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowVersion.present) {
      map['row_version'] = Variable<int>(rowVersion.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PastEventsCompanion(')
          ..write('id: $id, ')
          ..write('documentId: $documentId, ')
          ..write('sourceTaskId: $sourceTaskId, ')
          ..write('appendSequence: $appendSequence, ')
          ..write('completedAtUtc: $completedAtUtc, ')
          ..write('completionLocalDate: $completionLocalDate, ')
          ..write('completionZoneId: $completionZoneId, ')
          ..write('sourceSnapshotVersion: $sourceSnapshotVersion, ')
          ..write('sourceSnapshotJson: $sourceSnapshotJson, ')
          ..write('sourceSha256: $sourceSha256, ')
          ..write('anchorState: $anchorState, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowVersion: $rowVersion, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PastEventPartsTable extends PastEventParts
    with TableInfo<$PastEventPartsTable, PastEventPartRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PastEventPartsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _eventIdMeta = const VerificationMeta(
    'eventId',
  );
  @override
  late final GeneratedColumn<String> eventId = GeneratedColumn<String>(
    'event_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES past_events (id) ON DELETE CASCADE',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<PastPartRole, String> role =
      GeneratedColumn<String>(
        'role',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<PastPartRole>($PastEventPartsTable.$converterrole);
  static const VerificationMeta _sourceOrderMeta = const VerificationMeta(
    'sourceOrder',
  );
  @override
  late final GeneratedColumn<int> sourceOrder = GeneratedColumn<int>(
    'source_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originalPayloadJsonMeta =
      const VerificationMeta('originalPayloadJson');
  @override
  late final GeneratedColumn<String> originalPayloadJson =
      GeneratedColumn<String>(
        'original_payload_json',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _originalPlainTextMeta = const VerificationMeta(
    'originalPlainText',
  );
  @override
  late final GeneratedColumn<String> originalPlainText =
      GeneratedColumn<String>(
        'original_plain_text',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _originalSha256Meta = const VerificationMeta(
    'originalSha256',
  );
  @override
  late final GeneratedColumn<String> originalSha256 = GeneratedColumn<String>(
    'original_sha256',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    eventId,
    role,
    sourceOrder,
    originalPayloadJson,
    originalPlainText,
    originalSha256,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'past_event_parts';
  @override
  VerificationContext validateIntegrity(
    Insertable<PastEventPartRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('event_id')) {
      context.handle(
        _eventIdMeta,
        eventId.isAcceptableOrUnknown(data['event_id']!, _eventIdMeta),
      );
    } else if (isInserting) {
      context.missing(_eventIdMeta);
    }
    if (data.containsKey('source_order')) {
      context.handle(
        _sourceOrderMeta,
        sourceOrder.isAcceptableOrUnknown(
          data['source_order']!,
          _sourceOrderMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sourceOrderMeta);
    }
    if (data.containsKey('original_payload_json')) {
      context.handle(
        _originalPayloadJsonMeta,
        originalPayloadJson.isAcceptableOrUnknown(
          data['original_payload_json']!,
          _originalPayloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalPayloadJsonMeta);
    }
    if (data.containsKey('original_plain_text')) {
      context.handle(
        _originalPlainTextMeta,
        originalPlainText.isAcceptableOrUnknown(
          data['original_plain_text']!,
          _originalPlainTextMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalPlainTextMeta);
    }
    if (data.containsKey('original_sha256')) {
      context.handle(
        _originalSha256Meta,
        originalSha256.isAcceptableOrUnknown(
          data['original_sha256']!,
          _originalSha256Meta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originalSha256Meta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PastEventPartRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PastEventPartRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      eventId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}event_id'],
      )!,
      role: $PastEventPartsTable.$converterrole.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}role'],
        )!,
      ),
      sourceOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_order'],
      )!,
      originalPayloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_payload_json'],
      )!,
      originalPlainText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_plain_text'],
      )!,
      originalSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}original_sha256'],
      )!,
    );
  }

  @override
  $PastEventPartsTable createAlias(String alias) {
    return $PastEventPartsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<PastPartRole, String, String> $converterrole =
      const EnumNameConverter<PastPartRole>(PastPartRole.values);
}

class PastEventPartRow extends DataClass
    implements Insertable<PastEventPartRow> {
  final String id;
  final String eventId;
  final PastPartRole role;
  final int sourceOrder;
  final String originalPayloadJson;
  final String originalPlainText;
  final String originalSha256;
  const PastEventPartRow({
    required this.id,
    required this.eventId,
    required this.role,
    required this.sourceOrder,
    required this.originalPayloadJson,
    required this.originalPlainText,
    required this.originalSha256,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['event_id'] = Variable<String>(eventId);
    {
      map['role'] = Variable<String>(
        $PastEventPartsTable.$converterrole.toSql(role),
      );
    }
    map['source_order'] = Variable<int>(sourceOrder);
    map['original_payload_json'] = Variable<String>(originalPayloadJson);
    map['original_plain_text'] = Variable<String>(originalPlainText);
    map['original_sha256'] = Variable<String>(originalSha256);
    return map;
  }

  PastEventPartsCompanion toCompanion(bool nullToAbsent) {
    return PastEventPartsCompanion(
      id: Value(id),
      eventId: Value(eventId),
      role: Value(role),
      sourceOrder: Value(sourceOrder),
      originalPayloadJson: Value(originalPayloadJson),
      originalPlainText: Value(originalPlainText),
      originalSha256: Value(originalSha256),
    );
  }

  factory PastEventPartRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PastEventPartRow(
      id: serializer.fromJson<String>(json['id']),
      eventId: serializer.fromJson<String>(json['eventId']),
      role: $PastEventPartsTable.$converterrole.fromJson(
        serializer.fromJson<String>(json['role']),
      ),
      sourceOrder: serializer.fromJson<int>(json['sourceOrder']),
      originalPayloadJson: serializer.fromJson<String>(
        json['originalPayloadJson'],
      ),
      originalPlainText: serializer.fromJson<String>(json['originalPlainText']),
      originalSha256: serializer.fromJson<String>(json['originalSha256']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'eventId': serializer.toJson<String>(eventId),
      'role': serializer.toJson<String>(
        $PastEventPartsTable.$converterrole.toJson(role),
      ),
      'sourceOrder': serializer.toJson<int>(sourceOrder),
      'originalPayloadJson': serializer.toJson<String>(originalPayloadJson),
      'originalPlainText': serializer.toJson<String>(originalPlainText),
      'originalSha256': serializer.toJson<String>(originalSha256),
    };
  }

  PastEventPartRow copyWith({
    String? id,
    String? eventId,
    PastPartRole? role,
    int? sourceOrder,
    String? originalPayloadJson,
    String? originalPlainText,
    String? originalSha256,
  }) => PastEventPartRow(
    id: id ?? this.id,
    eventId: eventId ?? this.eventId,
    role: role ?? this.role,
    sourceOrder: sourceOrder ?? this.sourceOrder,
    originalPayloadJson: originalPayloadJson ?? this.originalPayloadJson,
    originalPlainText: originalPlainText ?? this.originalPlainText,
    originalSha256: originalSha256 ?? this.originalSha256,
  );
  PastEventPartRow copyWithCompanion(PastEventPartsCompanion data) {
    return PastEventPartRow(
      id: data.id.present ? data.id.value : this.id,
      eventId: data.eventId.present ? data.eventId.value : this.eventId,
      role: data.role.present ? data.role.value : this.role,
      sourceOrder: data.sourceOrder.present
          ? data.sourceOrder.value
          : this.sourceOrder,
      originalPayloadJson: data.originalPayloadJson.present
          ? data.originalPayloadJson.value
          : this.originalPayloadJson,
      originalPlainText: data.originalPlainText.present
          ? data.originalPlainText.value
          : this.originalPlainText,
      originalSha256: data.originalSha256.present
          ? data.originalSha256.value
          : this.originalSha256,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PastEventPartRow(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('role: $role, ')
          ..write('sourceOrder: $sourceOrder, ')
          ..write('originalPayloadJson: $originalPayloadJson, ')
          ..write('originalPlainText: $originalPlainText, ')
          ..write('originalSha256: $originalSha256')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    eventId,
    role,
    sourceOrder,
    originalPayloadJson,
    originalPlainText,
    originalSha256,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PastEventPartRow &&
          other.id == this.id &&
          other.eventId == this.eventId &&
          other.role == this.role &&
          other.sourceOrder == this.sourceOrder &&
          other.originalPayloadJson == this.originalPayloadJson &&
          other.originalPlainText == this.originalPlainText &&
          other.originalSha256 == this.originalSha256);
}

class PastEventPartsCompanion extends UpdateCompanion<PastEventPartRow> {
  final Value<String> id;
  final Value<String> eventId;
  final Value<PastPartRole> role;
  final Value<int> sourceOrder;
  final Value<String> originalPayloadJson;
  final Value<String> originalPlainText;
  final Value<String> originalSha256;
  final Value<int> rowid;
  const PastEventPartsCompanion({
    this.id = const Value.absent(),
    this.eventId = const Value.absent(),
    this.role = const Value.absent(),
    this.sourceOrder = const Value.absent(),
    this.originalPayloadJson = const Value.absent(),
    this.originalPlainText = const Value.absent(),
    this.originalSha256 = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PastEventPartsCompanion.insert({
    required String id,
    required String eventId,
    required PastPartRole role,
    required int sourceOrder,
    required String originalPayloadJson,
    required String originalPlainText,
    required String originalSha256,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       eventId = Value(eventId),
       role = Value(role),
       sourceOrder = Value(sourceOrder),
       originalPayloadJson = Value(originalPayloadJson),
       originalPlainText = Value(originalPlainText),
       originalSha256 = Value(originalSha256);
  static Insertable<PastEventPartRow> custom({
    Expression<String>? id,
    Expression<String>? eventId,
    Expression<String>? role,
    Expression<int>? sourceOrder,
    Expression<String>? originalPayloadJson,
    Expression<String>? originalPlainText,
    Expression<String>? originalSha256,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (eventId != null) 'event_id': eventId,
      if (role != null) 'role': role,
      if (sourceOrder != null) 'source_order': sourceOrder,
      if (originalPayloadJson != null)
        'original_payload_json': originalPayloadJson,
      if (originalPlainText != null) 'original_plain_text': originalPlainText,
      if (originalSha256 != null) 'original_sha256': originalSha256,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PastEventPartsCompanion copyWith({
    Value<String>? id,
    Value<String>? eventId,
    Value<PastPartRole>? role,
    Value<int>? sourceOrder,
    Value<String>? originalPayloadJson,
    Value<String>? originalPlainText,
    Value<String>? originalSha256,
    Value<int>? rowid,
  }) {
    return PastEventPartsCompanion(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      role: role ?? this.role,
      sourceOrder: sourceOrder ?? this.sourceOrder,
      originalPayloadJson: originalPayloadJson ?? this.originalPayloadJson,
      originalPlainText: originalPlainText ?? this.originalPlainText,
      originalSha256: originalSha256 ?? this.originalSha256,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (eventId.present) {
      map['event_id'] = Variable<String>(eventId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(
        $PastEventPartsTable.$converterrole.toSql(role.value),
      );
    }
    if (sourceOrder.present) {
      map['source_order'] = Variable<int>(sourceOrder.value);
    }
    if (originalPayloadJson.present) {
      map['original_payload_json'] = Variable<String>(
        originalPayloadJson.value,
      );
    }
    if (originalPlainText.present) {
      map['original_plain_text'] = Variable<String>(originalPlainText.value);
    }
    if (originalSha256.present) {
      map['original_sha256'] = Variable<String>(originalSha256.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PastEventPartsCompanion(')
          ..write('id: $id, ')
          ..write('eventId: $eventId, ')
          ..write('role: $role, ')
          ..write('sourceOrder: $sourceOrder, ')
          ..write('originalPayloadJson: $originalPayloadJson, ')
          ..write('originalPlainText: $originalPlainText, ')
          ..write('originalSha256: $originalSha256, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $PastAnchorLinksTable extends PastAnchorLinks
    with TableInfo<$PastAnchorLinksTable, PastAnchorLinkRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PastAnchorLinksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _partIdMeta = const VerificationMeta('partId');
  @override
  late final GeneratedColumn<String> partId = GeneratedColumn<String>(
    'part_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES past_event_parts (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _currentBlockIdMeta = const VerificationMeta(
    'currentBlockId',
  );
  @override
  late final GeneratedColumn<String> currentBlockId = GeneratedColumn<String>(
    'current_block_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES document_blocks (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _lastKnownBlockIdMeta = const VerificationMeta(
    'lastKnownBlockId',
  );
  @override
  late final GeneratedColumn<String> lastKnownBlockId = GeneratedColumn<String>(
    'last_known_block_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<AnchorRelation, String> relation =
      GeneratedColumn<String>(
        'relation',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<AnchorRelation>($PastAnchorLinksTable.$converterrelation);
  @override
  late final GeneratedColumnWithTypeConverter<AnchorLinkState, String>
  linkState = GeneratedColumn<String>(
    'link_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<AnchorLinkState>($PastAnchorLinksTable.$converterlinkState);
  static const VerificationMeta _currentSha256Meta = const VerificationMeta(
    'currentSha256',
  );
  @override
  late final GeneratedColumn<String> currentSha256 = GeneratedColumn<String>(
    'current_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    partId,
    currentBlockId,
    lastKnownBlockId,
    relation,
    linkState,
    currentSha256,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'past_anchor_links';
  @override
  VerificationContext validateIntegrity(
    Insertable<PastAnchorLinkRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('part_id')) {
      context.handle(
        _partIdMeta,
        partId.isAcceptableOrUnknown(data['part_id']!, _partIdMeta),
      );
    } else if (isInserting) {
      context.missing(_partIdMeta);
    }
    if (data.containsKey('current_block_id')) {
      context.handle(
        _currentBlockIdMeta,
        currentBlockId.isAcceptableOrUnknown(
          data['current_block_id']!,
          _currentBlockIdMeta,
        ),
      );
    }
    if (data.containsKey('last_known_block_id')) {
      context.handle(
        _lastKnownBlockIdMeta,
        lastKnownBlockId.isAcceptableOrUnknown(
          data['last_known_block_id']!,
          _lastKnownBlockIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastKnownBlockIdMeta);
    }
    if (data.containsKey('current_sha256')) {
      context.handle(
        _currentSha256Meta,
        currentSha256.isAcceptableOrUnknown(
          data['current_sha256']!,
          _currentSha256Meta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PastAnchorLinkRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PastAnchorLinkRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      partId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}part_id'],
      )!,
      currentBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_block_id'],
      ),
      lastKnownBlockId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_known_block_id'],
      )!,
      relation: $PastAnchorLinksTable.$converterrelation.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}relation'],
        )!,
      ),
      linkState: $PastAnchorLinksTable.$converterlinkState.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}link_state'],
        )!,
      ),
      currentSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_sha256'],
      ),
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $PastAnchorLinksTable createAlias(String alias) {
    return $PastAnchorLinksTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<AnchorRelation, String, String> $converterrelation =
      const EnumNameConverter<AnchorRelation>(AnchorRelation.values);
  static JsonTypeConverter2<AnchorLinkState, String, String>
  $converterlinkState = const EnumNameConverter<AnchorLinkState>(
    AnchorLinkState.values,
  );
}

class PastAnchorLinkRow extends DataClass
    implements Insertable<PastAnchorLinkRow> {
  final String id;
  final String partId;
  final String? currentBlockId;
  final String lastKnownBlockId;
  final AnchorRelation relation;
  final AnchorLinkState linkState;
  final String? currentSha256;
  final int updatedAtUtc;
  const PastAnchorLinkRow({
    required this.id,
    required this.partId,
    this.currentBlockId,
    required this.lastKnownBlockId,
    required this.relation,
    required this.linkState,
    this.currentSha256,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['part_id'] = Variable<String>(partId);
    if (!nullToAbsent || currentBlockId != null) {
      map['current_block_id'] = Variable<String>(currentBlockId);
    }
    map['last_known_block_id'] = Variable<String>(lastKnownBlockId);
    {
      map['relation'] = Variable<String>(
        $PastAnchorLinksTable.$converterrelation.toSql(relation),
      );
    }
    {
      map['link_state'] = Variable<String>(
        $PastAnchorLinksTable.$converterlinkState.toSql(linkState),
      );
    }
    if (!nullToAbsent || currentSha256 != null) {
      map['current_sha256'] = Variable<String>(currentSha256);
    }
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    return map;
  }

  PastAnchorLinksCompanion toCompanion(bool nullToAbsent) {
    return PastAnchorLinksCompanion(
      id: Value(id),
      partId: Value(partId),
      currentBlockId: currentBlockId == null && nullToAbsent
          ? const Value.absent()
          : Value(currentBlockId),
      lastKnownBlockId: Value(lastKnownBlockId),
      relation: Value(relation),
      linkState: Value(linkState),
      currentSha256: currentSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(currentSha256),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory PastAnchorLinkRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PastAnchorLinkRow(
      id: serializer.fromJson<String>(json['id']),
      partId: serializer.fromJson<String>(json['partId']),
      currentBlockId: serializer.fromJson<String?>(json['currentBlockId']),
      lastKnownBlockId: serializer.fromJson<String>(json['lastKnownBlockId']),
      relation: $PastAnchorLinksTable.$converterrelation.fromJson(
        serializer.fromJson<String>(json['relation']),
      ),
      linkState: $PastAnchorLinksTable.$converterlinkState.fromJson(
        serializer.fromJson<String>(json['linkState']),
      ),
      currentSha256: serializer.fromJson<String?>(json['currentSha256']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'partId': serializer.toJson<String>(partId),
      'currentBlockId': serializer.toJson<String?>(currentBlockId),
      'lastKnownBlockId': serializer.toJson<String>(lastKnownBlockId),
      'relation': serializer.toJson<String>(
        $PastAnchorLinksTable.$converterrelation.toJson(relation),
      ),
      'linkState': serializer.toJson<String>(
        $PastAnchorLinksTable.$converterlinkState.toJson(linkState),
      ),
      'currentSha256': serializer.toJson<String?>(currentSha256),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
    };
  }

  PastAnchorLinkRow copyWith({
    String? id,
    String? partId,
    Value<String?> currentBlockId = const Value.absent(),
    String? lastKnownBlockId,
    AnchorRelation? relation,
    AnchorLinkState? linkState,
    Value<String?> currentSha256 = const Value.absent(),
    int? updatedAtUtc,
  }) => PastAnchorLinkRow(
    id: id ?? this.id,
    partId: partId ?? this.partId,
    currentBlockId: currentBlockId.present
        ? currentBlockId.value
        : this.currentBlockId,
    lastKnownBlockId: lastKnownBlockId ?? this.lastKnownBlockId,
    relation: relation ?? this.relation,
    linkState: linkState ?? this.linkState,
    currentSha256: currentSha256.present
        ? currentSha256.value
        : this.currentSha256,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  PastAnchorLinkRow copyWithCompanion(PastAnchorLinksCompanion data) {
    return PastAnchorLinkRow(
      id: data.id.present ? data.id.value : this.id,
      partId: data.partId.present ? data.partId.value : this.partId,
      currentBlockId: data.currentBlockId.present
          ? data.currentBlockId.value
          : this.currentBlockId,
      lastKnownBlockId: data.lastKnownBlockId.present
          ? data.lastKnownBlockId.value
          : this.lastKnownBlockId,
      relation: data.relation.present ? data.relation.value : this.relation,
      linkState: data.linkState.present ? data.linkState.value : this.linkState,
      currentSha256: data.currentSha256.present
          ? data.currentSha256.value
          : this.currentSha256,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PastAnchorLinkRow(')
          ..write('id: $id, ')
          ..write('partId: $partId, ')
          ..write('currentBlockId: $currentBlockId, ')
          ..write('lastKnownBlockId: $lastKnownBlockId, ')
          ..write('relation: $relation, ')
          ..write('linkState: $linkState, ')
          ..write('currentSha256: $currentSha256, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    partId,
    currentBlockId,
    lastKnownBlockId,
    relation,
    linkState,
    currentSha256,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PastAnchorLinkRow &&
          other.id == this.id &&
          other.partId == this.partId &&
          other.currentBlockId == this.currentBlockId &&
          other.lastKnownBlockId == this.lastKnownBlockId &&
          other.relation == this.relation &&
          other.linkState == this.linkState &&
          other.currentSha256 == this.currentSha256 &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class PastAnchorLinksCompanion extends UpdateCompanion<PastAnchorLinkRow> {
  final Value<String> id;
  final Value<String> partId;
  final Value<String?> currentBlockId;
  final Value<String> lastKnownBlockId;
  final Value<AnchorRelation> relation;
  final Value<AnchorLinkState> linkState;
  final Value<String?> currentSha256;
  final Value<int> updatedAtUtc;
  final Value<int> rowid;
  const PastAnchorLinksCompanion({
    this.id = const Value.absent(),
    this.partId = const Value.absent(),
    this.currentBlockId = const Value.absent(),
    this.lastKnownBlockId = const Value.absent(),
    this.relation = const Value.absent(),
    this.linkState = const Value.absent(),
    this.currentSha256 = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PastAnchorLinksCompanion.insert({
    required String id,
    required String partId,
    this.currentBlockId = const Value.absent(),
    required String lastKnownBlockId,
    required AnchorRelation relation,
    required AnchorLinkState linkState,
    this.currentSha256 = const Value.absent(),
    required int updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       partId = Value(partId),
       lastKnownBlockId = Value(lastKnownBlockId),
       relation = Value(relation),
       linkState = Value(linkState),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<PastAnchorLinkRow> custom({
    Expression<String>? id,
    Expression<String>? partId,
    Expression<String>? currentBlockId,
    Expression<String>? lastKnownBlockId,
    Expression<String>? relation,
    Expression<String>? linkState,
    Expression<String>? currentSha256,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (partId != null) 'part_id': partId,
      if (currentBlockId != null) 'current_block_id': currentBlockId,
      if (lastKnownBlockId != null) 'last_known_block_id': lastKnownBlockId,
      if (relation != null) 'relation': relation,
      if (linkState != null) 'link_state': linkState,
      if (currentSha256 != null) 'current_sha256': currentSha256,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PastAnchorLinksCompanion copyWith({
    Value<String>? id,
    Value<String>? partId,
    Value<String?>? currentBlockId,
    Value<String>? lastKnownBlockId,
    Value<AnchorRelation>? relation,
    Value<AnchorLinkState>? linkState,
    Value<String?>? currentSha256,
    Value<int>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return PastAnchorLinksCompanion(
      id: id ?? this.id,
      partId: partId ?? this.partId,
      currentBlockId: currentBlockId ?? this.currentBlockId,
      lastKnownBlockId: lastKnownBlockId ?? this.lastKnownBlockId,
      relation: relation ?? this.relation,
      linkState: linkState ?? this.linkState,
      currentSha256: currentSha256 ?? this.currentSha256,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (partId.present) {
      map['part_id'] = Variable<String>(partId.value);
    }
    if (currentBlockId.present) {
      map['current_block_id'] = Variable<String>(currentBlockId.value);
    }
    if (lastKnownBlockId.present) {
      map['last_known_block_id'] = Variable<String>(lastKnownBlockId.value);
    }
    if (relation.present) {
      map['relation'] = Variable<String>(
        $PastAnchorLinksTable.$converterrelation.toSql(relation.value),
      );
    }
    if (linkState.present) {
      map['link_state'] = Variable<String>(
        $PastAnchorLinksTable.$converterlinkState.toSql(linkState.value),
      );
    }
    if (currentSha256.present) {
      map['current_sha256'] = Variable<String>(currentSha256.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PastAnchorLinksCompanion(')
          ..write('id: $id, ')
          ..write('partId: $partId, ')
          ..write('currentBlockId: $currentBlockId, ')
          ..write('lastKnownBlockId: $lastKnownBlockId, ')
          ..write('relation: $relation, ')
          ..write('linkState: $linkState, ')
          ..write('currentSha256: $currentSha256, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SearchRecordsTable extends SearchRecords
    with TableInfo<$SearchRecordsTable, SearchRecordRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SearchRecordsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _rowIdMeta = const VerificationMeta('rowId');
  @override
  late final GeneratedColumn<int> rowId = GeneratedColumn<int>(
    'row_id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  @override
  late final GeneratedColumnWithTypeConverter<SearchScope, String> scope =
      GeneratedColumn<String>(
        'scope',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<SearchScope>($SearchRecordsTable.$converterscope);
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _documentIdMeta = const VerificationMeta(
    'documentId',
  );
  @override
  late final GeneratedColumn<String> documentId = GeneratedColumn<String>(
    'document_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleNormMeta = const VerificationMeta(
    'titleNorm',
  );
  @override
  late final GeneratedColumn<String> titleNorm = GeneratedColumn<String>(
    'title_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _bodyNormMeta = const VerificationMeta(
    'bodyNorm',
  );
  @override
  late final GeneratedColumn<String> bodyNorm = GeneratedColumn<String>(
    'body_norm',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _dateKeyMeta = const VerificationMeta(
    'dateKey',
  );
  @override
  late final GeneratedColumn<String> dateKey = GeneratedColumn<String>(
    'date_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    rowId,
    scope,
    entityId,
    documentId,
    titleNorm,
    bodyNorm,
    dateKey,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'search_records';
  @override
  VerificationContext validateIntegrity(
    Insertable<SearchRecordRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('row_id')) {
      context.handle(
        _rowIdMeta,
        rowId.isAcceptableOrUnknown(data['row_id']!, _rowIdMeta),
      );
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('document_id')) {
      context.handle(
        _documentIdMeta,
        documentId.isAcceptableOrUnknown(data['document_id']!, _documentIdMeta),
      );
    }
    if (data.containsKey('title_norm')) {
      context.handle(
        _titleNormMeta,
        titleNorm.isAcceptableOrUnknown(data['title_norm']!, _titleNormMeta),
      );
    }
    if (data.containsKey('body_norm')) {
      context.handle(
        _bodyNormMeta,
        bodyNorm.isAcceptableOrUnknown(data['body_norm']!, _bodyNormMeta),
      );
    }
    if (data.containsKey('date_key')) {
      context.handle(
        _dateKeyMeta,
        dateKey.isAcceptableOrUnknown(data['date_key']!, _dateKeyMeta),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {rowId};
  @override
  SearchRecordRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SearchRecordRow(
      rowId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}row_id'],
      )!,
      scope: $SearchRecordsTable.$converterscope.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}scope'],
        )!,
      ),
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_id'],
      )!,
      documentId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}document_id'],
      ),
      titleNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title_norm'],
      )!,
      bodyNorm: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}body_norm'],
      )!,
      dateKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}date_key'],
      )!,
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $SearchRecordsTable createAlias(String alias) {
    return $SearchRecordsTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<SearchScope, String, String> $converterscope =
      const EnumNameConverter<SearchScope>(SearchScope.values);
}

class SearchRecordRow extends DataClass implements Insertable<SearchRecordRow> {
  final int rowId;
  final SearchScope scope;
  final String entityId;
  final String? documentId;
  final String titleNorm;
  final String bodyNorm;
  final String dateKey;
  final int updatedAtUtc;
  const SearchRecordRow({
    required this.rowId,
    required this.scope,
    required this.entityId,
    this.documentId,
    required this.titleNorm,
    required this.bodyNorm,
    required this.dateKey,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['row_id'] = Variable<int>(rowId);
    {
      map['scope'] = Variable<String>(
        $SearchRecordsTable.$converterscope.toSql(scope),
      );
    }
    map['entity_id'] = Variable<String>(entityId);
    if (!nullToAbsent || documentId != null) {
      map['document_id'] = Variable<String>(documentId);
    }
    map['title_norm'] = Variable<String>(titleNorm);
    map['body_norm'] = Variable<String>(bodyNorm);
    map['date_key'] = Variable<String>(dateKey);
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    return map;
  }

  SearchRecordsCompanion toCompanion(bool nullToAbsent) {
    return SearchRecordsCompanion(
      rowId: Value(rowId),
      scope: Value(scope),
      entityId: Value(entityId),
      documentId: documentId == null && nullToAbsent
          ? const Value.absent()
          : Value(documentId),
      titleNorm: Value(titleNorm),
      bodyNorm: Value(bodyNorm),
      dateKey: Value(dateKey),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory SearchRecordRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SearchRecordRow(
      rowId: serializer.fromJson<int>(json['rowId']),
      scope: $SearchRecordsTable.$converterscope.fromJson(
        serializer.fromJson<String>(json['scope']),
      ),
      entityId: serializer.fromJson<String>(json['entityId']),
      documentId: serializer.fromJson<String?>(json['documentId']),
      titleNorm: serializer.fromJson<String>(json['titleNorm']),
      bodyNorm: serializer.fromJson<String>(json['bodyNorm']),
      dateKey: serializer.fromJson<String>(json['dateKey']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'rowId': serializer.toJson<int>(rowId),
      'scope': serializer.toJson<String>(
        $SearchRecordsTable.$converterscope.toJson(scope),
      ),
      'entityId': serializer.toJson<String>(entityId),
      'documentId': serializer.toJson<String?>(documentId),
      'titleNorm': serializer.toJson<String>(titleNorm),
      'bodyNorm': serializer.toJson<String>(bodyNorm),
      'dateKey': serializer.toJson<String>(dateKey),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
    };
  }

  SearchRecordRow copyWith({
    int? rowId,
    SearchScope? scope,
    String? entityId,
    Value<String?> documentId = const Value.absent(),
    String? titleNorm,
    String? bodyNorm,
    String? dateKey,
    int? updatedAtUtc,
  }) => SearchRecordRow(
    rowId: rowId ?? this.rowId,
    scope: scope ?? this.scope,
    entityId: entityId ?? this.entityId,
    documentId: documentId.present ? documentId.value : this.documentId,
    titleNorm: titleNorm ?? this.titleNorm,
    bodyNorm: bodyNorm ?? this.bodyNorm,
    dateKey: dateKey ?? this.dateKey,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  SearchRecordRow copyWithCompanion(SearchRecordsCompanion data) {
    return SearchRecordRow(
      rowId: data.rowId.present ? data.rowId.value : this.rowId,
      scope: data.scope.present ? data.scope.value : this.scope,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      documentId: data.documentId.present
          ? data.documentId.value
          : this.documentId,
      titleNorm: data.titleNorm.present ? data.titleNorm.value : this.titleNorm,
      bodyNorm: data.bodyNorm.present ? data.bodyNorm.value : this.bodyNorm,
      dateKey: data.dateKey.present ? data.dateKey.value : this.dateKey,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SearchRecordRow(')
          ..write('rowId: $rowId, ')
          ..write('scope: $scope, ')
          ..write('entityId: $entityId, ')
          ..write('documentId: $documentId, ')
          ..write('titleNorm: $titleNorm, ')
          ..write('bodyNorm: $bodyNorm, ')
          ..write('dateKey: $dateKey, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    rowId,
    scope,
    entityId,
    documentId,
    titleNorm,
    bodyNorm,
    dateKey,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SearchRecordRow &&
          other.rowId == this.rowId &&
          other.scope == this.scope &&
          other.entityId == this.entityId &&
          other.documentId == this.documentId &&
          other.titleNorm == this.titleNorm &&
          other.bodyNorm == this.bodyNorm &&
          other.dateKey == this.dateKey &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class SearchRecordsCompanion extends UpdateCompanion<SearchRecordRow> {
  final Value<int> rowId;
  final Value<SearchScope> scope;
  final Value<String> entityId;
  final Value<String?> documentId;
  final Value<String> titleNorm;
  final Value<String> bodyNorm;
  final Value<String> dateKey;
  final Value<int> updatedAtUtc;
  const SearchRecordsCompanion({
    this.rowId = const Value.absent(),
    this.scope = const Value.absent(),
    this.entityId = const Value.absent(),
    this.documentId = const Value.absent(),
    this.titleNorm = const Value.absent(),
    this.bodyNorm = const Value.absent(),
    this.dateKey = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
  });
  SearchRecordsCompanion.insert({
    this.rowId = const Value.absent(),
    required SearchScope scope,
    required String entityId,
    this.documentId = const Value.absent(),
    this.titleNorm = const Value.absent(),
    this.bodyNorm = const Value.absent(),
    this.dateKey = const Value.absent(),
    required int updatedAtUtc,
  }) : scope = Value(scope),
       entityId = Value(entityId),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<SearchRecordRow> custom({
    Expression<int>? rowId,
    Expression<String>? scope,
    Expression<String>? entityId,
    Expression<String>? documentId,
    Expression<String>? titleNorm,
    Expression<String>? bodyNorm,
    Expression<String>? dateKey,
    Expression<int>? updatedAtUtc,
  }) {
    return RawValuesInsertable({
      if (rowId != null) 'row_id': rowId,
      if (scope != null) 'scope': scope,
      if (entityId != null) 'entity_id': entityId,
      if (documentId != null) 'document_id': documentId,
      if (titleNorm != null) 'title_norm': titleNorm,
      if (bodyNorm != null) 'body_norm': bodyNorm,
      if (dateKey != null) 'date_key': dateKey,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
    });
  }

  SearchRecordsCompanion copyWith({
    Value<int>? rowId,
    Value<SearchScope>? scope,
    Value<String>? entityId,
    Value<String?>? documentId,
    Value<String>? titleNorm,
    Value<String>? bodyNorm,
    Value<String>? dateKey,
    Value<int>? updatedAtUtc,
  }) {
    return SearchRecordsCompanion(
      rowId: rowId ?? this.rowId,
      scope: scope ?? this.scope,
      entityId: entityId ?? this.entityId,
      documentId: documentId ?? this.documentId,
      titleNorm: titleNorm ?? this.titleNorm,
      bodyNorm: bodyNorm ?? this.bodyNorm,
      dateKey: dateKey ?? this.dateKey,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (rowId.present) {
      map['row_id'] = Variable<int>(rowId.value);
    }
    if (scope.present) {
      map['scope'] = Variable<String>(
        $SearchRecordsTable.$converterscope.toSql(scope.value),
      );
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (documentId.present) {
      map['document_id'] = Variable<String>(documentId.value);
    }
    if (titleNorm.present) {
      map['title_norm'] = Variable<String>(titleNorm.value);
    }
    if (bodyNorm.present) {
      map['body_norm'] = Variable<String>(bodyNorm.value);
    }
    if (dateKey.present) {
      map['date_key'] = Variable<String>(dateKey.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SearchRecordsCompanion(')
          ..write('rowId: $rowId, ')
          ..write('scope: $scope, ')
          ..write('entityId: $entityId, ')
          ..write('documentId: $documentId, ')
          ..write('titleNorm: $titleNorm, ')
          ..write('bodyNorm: $bodyNorm, ')
          ..write('dateKey: $dateKey, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }
}

class $BackupTargetsTable extends BackupTargets
    with TableInfo<$BackupTargetsTable, BackupTargetRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupTargetsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _platformMeta = const VerificationMeta(
    'platform',
  );
  @override
  late final GeneratedColumn<String> platform = GeneratedColumn<String>(
    'platform',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _displayNameMeta = const VerificationMeta(
    'displayName',
  );
  @override
  late final GeneratedColumn<String> displayName = GeneratedColumn<String>(
    'display_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _locatorTextMeta = const VerificationMeta(
    'locatorText',
  );
  @override
  late final GeneratedColumn<String> locatorText = GeneratedColumn<String>(
    'locator_text',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locatorBlobMeta = const VerificationMeta(
    'locatorBlob',
  );
  @override
  late final GeneratedColumn<Uint8List> locatorBlob =
      GeneratedColumn<Uint8List>(
        'locator_blob',
        aliasedName,
        true,
        type: DriftSqlType.blob,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _permissionStateMeta = const VerificationMeta(
    'permissionState',
  );
  @override
  late final GeneratedColumn<String> permissionState = GeneratedColumn<String>(
    'permission_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isDefaultMeta = const VerificationMeta(
    'isDefault',
  );
  @override
  late final GeneratedColumn<bool> isDefault = GeneratedColumn<bool>(
    'is_default',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_default" IN (0, 1))',
    ),
  );
  static const VerificationMeta _grantedAtUtcMeta = const VerificationMeta(
    'grantedAtUtc',
  );
  @override
  late final GeneratedColumn<int> grantedAtUtc = GeneratedColumn<int>(
    'granted_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastVerifiedAtUtcMeta = const VerificationMeta(
    'lastVerifiedAtUtc',
  );
  @override
  late final GeneratedColumn<int> lastVerifiedAtUtc = GeneratedColumn<int>(
    'last_verified_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtUtcMeta = const VerificationMeta(
    'updatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> updatedAtUtc = GeneratedColumn<int>(
    'updated_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    platform,
    displayName,
    locatorText,
    locatorBlob,
    permissionState,
    isDefault,
    grantedAtUtc,
    lastVerifiedAtUtc,
    updatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_targets';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupTargetRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('platform')) {
      context.handle(
        _platformMeta,
        platform.isAcceptableOrUnknown(data['platform']!, _platformMeta),
      );
    } else if (isInserting) {
      context.missing(_platformMeta);
    }
    if (data.containsKey('display_name')) {
      context.handle(
        _displayNameMeta,
        displayName.isAcceptableOrUnknown(
          data['display_name']!,
          _displayNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_displayNameMeta);
    }
    if (data.containsKey('locator_text')) {
      context.handle(
        _locatorTextMeta,
        locatorText.isAcceptableOrUnknown(
          data['locator_text']!,
          _locatorTextMeta,
        ),
      );
    }
    if (data.containsKey('locator_blob')) {
      context.handle(
        _locatorBlobMeta,
        locatorBlob.isAcceptableOrUnknown(
          data['locator_blob']!,
          _locatorBlobMeta,
        ),
      );
    }
    if (data.containsKey('permission_state')) {
      context.handle(
        _permissionStateMeta,
        permissionState.isAcceptableOrUnknown(
          data['permission_state']!,
          _permissionStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_permissionStateMeta);
    }
    if (data.containsKey('is_default')) {
      context.handle(
        _isDefaultMeta,
        isDefault.isAcceptableOrUnknown(data['is_default']!, _isDefaultMeta),
      );
    } else if (isInserting) {
      context.missing(_isDefaultMeta);
    }
    if (data.containsKey('granted_at_utc')) {
      context.handle(
        _grantedAtUtcMeta,
        grantedAtUtc.isAcceptableOrUnknown(
          data['granted_at_utc']!,
          _grantedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('last_verified_at_utc')) {
      context.handle(
        _lastVerifiedAtUtcMeta,
        lastVerifiedAtUtc.isAcceptableOrUnknown(
          data['last_verified_at_utc']!,
          _lastVerifiedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_utc')) {
      context.handle(
        _updatedAtUtcMeta,
        updatedAtUtc.isAcceptableOrUnknown(
          data['updated_at_utc']!,
          _updatedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupTargetRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupTargetRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      platform: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform'],
      )!,
      displayName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}display_name'],
      )!,
      locatorText: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}locator_text'],
      ),
      locatorBlob: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}locator_blob'],
      ),
      permissionState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}permission_state'],
      )!,
      isDefault: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_default'],
      )!,
      grantedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}granted_at_utc'],
      ),
      lastVerifiedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_verified_at_utc'],
      ),
      updatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_utc'],
      )!,
    );
  }

  @override
  $BackupTargetsTable createAlias(String alias) {
    return $BackupTargetsTable(attachedDatabase, alias);
  }
}

class BackupTargetRow extends DataClass implements Insertable<BackupTargetRow> {
  final String id;
  final String platform;
  final String displayName;
  final String? locatorText;
  final Uint8List? locatorBlob;
  final String permissionState;
  final bool isDefault;
  final int? grantedAtUtc;
  final int? lastVerifiedAtUtc;
  final int updatedAtUtc;
  const BackupTargetRow({
    required this.id,
    required this.platform,
    required this.displayName,
    this.locatorText,
    this.locatorBlob,
    required this.permissionState,
    required this.isDefault,
    this.grantedAtUtc,
    this.lastVerifiedAtUtc,
    required this.updatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['platform'] = Variable<String>(platform);
    map['display_name'] = Variable<String>(displayName);
    if (!nullToAbsent || locatorText != null) {
      map['locator_text'] = Variable<String>(locatorText);
    }
    if (!nullToAbsent || locatorBlob != null) {
      map['locator_blob'] = Variable<Uint8List>(locatorBlob);
    }
    map['permission_state'] = Variable<String>(permissionState);
    map['is_default'] = Variable<bool>(isDefault);
    if (!nullToAbsent || grantedAtUtc != null) {
      map['granted_at_utc'] = Variable<int>(grantedAtUtc);
    }
    if (!nullToAbsent || lastVerifiedAtUtc != null) {
      map['last_verified_at_utc'] = Variable<int>(lastVerifiedAtUtc);
    }
    map['updated_at_utc'] = Variable<int>(updatedAtUtc);
    return map;
  }

  BackupTargetsCompanion toCompanion(bool nullToAbsent) {
    return BackupTargetsCompanion(
      id: Value(id),
      platform: Value(platform),
      displayName: Value(displayName),
      locatorText: locatorText == null && nullToAbsent
          ? const Value.absent()
          : Value(locatorText),
      locatorBlob: locatorBlob == null && nullToAbsent
          ? const Value.absent()
          : Value(locatorBlob),
      permissionState: Value(permissionState),
      isDefault: Value(isDefault),
      grantedAtUtc: grantedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(grantedAtUtc),
      lastVerifiedAtUtc: lastVerifiedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(lastVerifiedAtUtc),
      updatedAtUtc: Value(updatedAtUtc),
    );
  }

  factory BackupTargetRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupTargetRow(
      id: serializer.fromJson<String>(json['id']),
      platform: serializer.fromJson<String>(json['platform']),
      displayName: serializer.fromJson<String>(json['displayName']),
      locatorText: serializer.fromJson<String?>(json['locatorText']),
      locatorBlob: serializer.fromJson<Uint8List?>(json['locatorBlob']),
      permissionState: serializer.fromJson<String>(json['permissionState']),
      isDefault: serializer.fromJson<bool>(json['isDefault']),
      grantedAtUtc: serializer.fromJson<int?>(json['grantedAtUtc']),
      lastVerifiedAtUtc: serializer.fromJson<int?>(json['lastVerifiedAtUtc']),
      updatedAtUtc: serializer.fromJson<int>(json['updatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'platform': serializer.toJson<String>(platform),
      'displayName': serializer.toJson<String>(displayName),
      'locatorText': serializer.toJson<String?>(locatorText),
      'locatorBlob': serializer.toJson<Uint8List?>(locatorBlob),
      'permissionState': serializer.toJson<String>(permissionState),
      'isDefault': serializer.toJson<bool>(isDefault),
      'grantedAtUtc': serializer.toJson<int?>(grantedAtUtc),
      'lastVerifiedAtUtc': serializer.toJson<int?>(lastVerifiedAtUtc),
      'updatedAtUtc': serializer.toJson<int>(updatedAtUtc),
    };
  }

  BackupTargetRow copyWith({
    String? id,
    String? platform,
    String? displayName,
    Value<String?> locatorText = const Value.absent(),
    Value<Uint8List?> locatorBlob = const Value.absent(),
    String? permissionState,
    bool? isDefault,
    Value<int?> grantedAtUtc = const Value.absent(),
    Value<int?> lastVerifiedAtUtc = const Value.absent(),
    int? updatedAtUtc,
  }) => BackupTargetRow(
    id: id ?? this.id,
    platform: platform ?? this.platform,
    displayName: displayName ?? this.displayName,
    locatorText: locatorText.present ? locatorText.value : this.locatorText,
    locatorBlob: locatorBlob.present ? locatorBlob.value : this.locatorBlob,
    permissionState: permissionState ?? this.permissionState,
    isDefault: isDefault ?? this.isDefault,
    grantedAtUtc: grantedAtUtc.present ? grantedAtUtc.value : this.grantedAtUtc,
    lastVerifiedAtUtc: lastVerifiedAtUtc.present
        ? lastVerifiedAtUtc.value
        : this.lastVerifiedAtUtc,
    updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
  );
  BackupTargetRow copyWithCompanion(BackupTargetsCompanion data) {
    return BackupTargetRow(
      id: data.id.present ? data.id.value : this.id,
      platform: data.platform.present ? data.platform.value : this.platform,
      displayName: data.displayName.present
          ? data.displayName.value
          : this.displayName,
      locatorText: data.locatorText.present
          ? data.locatorText.value
          : this.locatorText,
      locatorBlob: data.locatorBlob.present
          ? data.locatorBlob.value
          : this.locatorBlob,
      permissionState: data.permissionState.present
          ? data.permissionState.value
          : this.permissionState,
      isDefault: data.isDefault.present ? data.isDefault.value : this.isDefault,
      grantedAtUtc: data.grantedAtUtc.present
          ? data.grantedAtUtc.value
          : this.grantedAtUtc,
      lastVerifiedAtUtc: data.lastVerifiedAtUtc.present
          ? data.lastVerifiedAtUtc.value
          : this.lastVerifiedAtUtc,
      updatedAtUtc: data.updatedAtUtc.present
          ? data.updatedAtUtc.value
          : this.updatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupTargetRow(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('displayName: $displayName, ')
          ..write('locatorText: $locatorText, ')
          ..write('locatorBlob: $locatorBlob, ')
          ..write('permissionState: $permissionState, ')
          ..write('isDefault: $isDefault, ')
          ..write('grantedAtUtc: $grantedAtUtc, ')
          ..write('lastVerifiedAtUtc: $lastVerifiedAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    platform,
    displayName,
    locatorText,
    $driftBlobEquality.hash(locatorBlob),
    permissionState,
    isDefault,
    grantedAtUtc,
    lastVerifiedAtUtc,
    updatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupTargetRow &&
          other.id == this.id &&
          other.platform == this.platform &&
          other.displayName == this.displayName &&
          other.locatorText == this.locatorText &&
          $driftBlobEquality.equals(other.locatorBlob, this.locatorBlob) &&
          other.permissionState == this.permissionState &&
          other.isDefault == this.isDefault &&
          other.grantedAtUtc == this.grantedAtUtc &&
          other.lastVerifiedAtUtc == this.lastVerifiedAtUtc &&
          other.updatedAtUtc == this.updatedAtUtc);
}

class BackupTargetsCompanion extends UpdateCompanion<BackupTargetRow> {
  final Value<String> id;
  final Value<String> platform;
  final Value<String> displayName;
  final Value<String?> locatorText;
  final Value<Uint8List?> locatorBlob;
  final Value<String> permissionState;
  final Value<bool> isDefault;
  final Value<int?> grantedAtUtc;
  final Value<int?> lastVerifiedAtUtc;
  final Value<int> updatedAtUtc;
  final Value<int> rowid;
  const BackupTargetsCompanion({
    this.id = const Value.absent(),
    this.platform = const Value.absent(),
    this.displayName = const Value.absent(),
    this.locatorText = const Value.absent(),
    this.locatorBlob = const Value.absent(),
    this.permissionState = const Value.absent(),
    this.isDefault = const Value.absent(),
    this.grantedAtUtc = const Value.absent(),
    this.lastVerifiedAtUtc = const Value.absent(),
    this.updatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BackupTargetsCompanion.insert({
    required String id,
    required String platform,
    required String displayName,
    this.locatorText = const Value.absent(),
    this.locatorBlob = const Value.absent(),
    required String permissionState,
    required bool isDefault,
    this.grantedAtUtc = const Value.absent(),
    this.lastVerifiedAtUtc = const Value.absent(),
    required int updatedAtUtc,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       platform = Value(platform),
       displayName = Value(displayName),
       permissionState = Value(permissionState),
       isDefault = Value(isDefault),
       updatedAtUtc = Value(updatedAtUtc);
  static Insertable<BackupTargetRow> custom({
    Expression<String>? id,
    Expression<String>? platform,
    Expression<String>? displayName,
    Expression<String>? locatorText,
    Expression<Uint8List>? locatorBlob,
    Expression<String>? permissionState,
    Expression<bool>? isDefault,
    Expression<int>? grantedAtUtc,
    Expression<int>? lastVerifiedAtUtc,
    Expression<int>? updatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (platform != null) 'platform': platform,
      if (displayName != null) 'display_name': displayName,
      if (locatorText != null) 'locator_text': locatorText,
      if (locatorBlob != null) 'locator_blob': locatorBlob,
      if (permissionState != null) 'permission_state': permissionState,
      if (isDefault != null) 'is_default': isDefault,
      if (grantedAtUtc != null) 'granted_at_utc': grantedAtUtc,
      if (lastVerifiedAtUtc != null) 'last_verified_at_utc': lastVerifiedAtUtc,
      if (updatedAtUtc != null) 'updated_at_utc': updatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BackupTargetsCompanion copyWith({
    Value<String>? id,
    Value<String>? platform,
    Value<String>? displayName,
    Value<String?>? locatorText,
    Value<Uint8List?>? locatorBlob,
    Value<String>? permissionState,
    Value<bool>? isDefault,
    Value<int?>? grantedAtUtc,
    Value<int?>? lastVerifiedAtUtc,
    Value<int>? updatedAtUtc,
    Value<int>? rowid,
  }) {
    return BackupTargetsCompanion(
      id: id ?? this.id,
      platform: platform ?? this.platform,
      displayName: displayName ?? this.displayName,
      locatorText: locatorText ?? this.locatorText,
      locatorBlob: locatorBlob ?? this.locatorBlob,
      permissionState: permissionState ?? this.permissionState,
      isDefault: isDefault ?? this.isDefault,
      grantedAtUtc: grantedAtUtc ?? this.grantedAtUtc,
      lastVerifiedAtUtc: lastVerifiedAtUtc ?? this.lastVerifiedAtUtc,
      updatedAtUtc: updatedAtUtc ?? this.updatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (platform.present) {
      map['platform'] = Variable<String>(platform.value);
    }
    if (displayName.present) {
      map['display_name'] = Variable<String>(displayName.value);
    }
    if (locatorText.present) {
      map['locator_text'] = Variable<String>(locatorText.value);
    }
    if (locatorBlob.present) {
      map['locator_blob'] = Variable<Uint8List>(locatorBlob.value);
    }
    if (permissionState.present) {
      map['permission_state'] = Variable<String>(permissionState.value);
    }
    if (isDefault.present) {
      map['is_default'] = Variable<bool>(isDefault.value);
    }
    if (grantedAtUtc.present) {
      map['granted_at_utc'] = Variable<int>(grantedAtUtc.value);
    }
    if (lastVerifiedAtUtc.present) {
      map['last_verified_at_utc'] = Variable<int>(lastVerifiedAtUtc.value);
    }
    if (updatedAtUtc.present) {
      map['updated_at_utc'] = Variable<int>(updatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupTargetsCompanion(')
          ..write('id: $id, ')
          ..write('platform: $platform, ')
          ..write('displayName: $displayName, ')
          ..write('locatorText: $locatorText, ')
          ..write('locatorBlob: $locatorBlob, ')
          ..write('permissionState: $permissionState, ')
          ..write('isDefault: $isDefault, ')
          ..write('grantedAtUtc: $grantedAtUtc, ')
          ..write('lastVerifiedAtUtc: $lastVerifiedAtUtc, ')
          ..write('updatedAtUtc: $updatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BackupEncryptionProfilesTable extends BackupEncryptionProfiles
    with TableInfo<$BackupEncryptionProfilesTable, BackupEncryptionProfileRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupEncryptionProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kdfMeta = const VerificationMeta('kdf');
  @override
  late final GeneratedColumn<String> kdf = GeneratedColumn<String>(
    'kdf',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('argon2id-v1'),
  );
  static const VerificationMeta _kdfMemoryKibMeta = const VerificationMeta(
    'kdfMemoryKib',
  );
  @override
  late final GeneratedColumn<int> kdfMemoryKib = GeneratedColumn<int>(
    'kdf_memory_kib',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(65536),
  );
  static const VerificationMeta _kdfIterationsMeta = const VerificationMeta(
    'kdfIterations',
  );
  @override
  late final GeneratedColumn<int> kdfIterations = GeneratedColumn<int>(
    'kdf_iterations',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(3),
  );
  static const VerificationMeta _kdfParallelismMeta = const VerificationMeta(
    'kdfParallelism',
  );
  @override
  late final GeneratedColumn<int> kdfParallelism = GeneratedColumn<int>(
    'kdf_parallelism',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _kdfSaltMeta = const VerificationMeta(
    'kdfSalt',
  );
  @override
  late final GeneratedColumn<Uint8List> kdfSalt = GeneratedColumn<Uint8List>(
    'kdf_salt',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _passwordEnvelopeNonceMeta =
      const VerificationMeta('passwordEnvelopeNonce');
  @override
  late final GeneratedColumn<Uint8List> passwordEnvelopeNonce =
      GeneratedColumn<Uint8List>(
        'password_envelope_nonce',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _wrappedMasterKeyMeta = const VerificationMeta(
    'wrappedMasterKey',
  );
  @override
  late final GeneratedColumn<Uint8List> wrappedMasterKey =
      GeneratedColumn<Uint8List>(
        'wrapped_master_key',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _wrappedMasterKeyMacMeta =
      const VerificationMeta('wrappedMasterKeyMac');
  @override
  late final GeneratedColumn<Uint8List> wrappedMasterKeyMac =
      GeneratedColumn<Uint8List>(
        'wrapped_master_key_mac',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _platformKeyAliasMeta = const VerificationMeta(
    'platformKeyAlias',
  );
  @override
  late final GeneratedColumn<String> platformKeyAlias = GeneratedColumn<String>(
    'platform_key_alias',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _rotatedAtUtcMeta = const VerificationMeta(
    'rotatedAtUtc',
  );
  @override
  late final GeneratedColumn<int> rotatedAtUtc = GeneratedColumn<int>(
    'rotated_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    kdf,
    kdfMemoryKib,
    kdfIterations,
    kdfParallelism,
    kdfSalt,
    passwordEnvelopeNonce,
    wrappedMasterKey,
    wrappedMasterKeyMac,
    platformKeyAlias,
    createdAtUtc,
    rotatedAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_encryption_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupEncryptionProfileRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('kdf')) {
      context.handle(
        _kdfMeta,
        kdf.isAcceptableOrUnknown(data['kdf']!, _kdfMeta),
      );
    }
    if (data.containsKey('kdf_memory_kib')) {
      context.handle(
        _kdfMemoryKibMeta,
        kdfMemoryKib.isAcceptableOrUnknown(
          data['kdf_memory_kib']!,
          _kdfMemoryKibMeta,
        ),
      );
    }
    if (data.containsKey('kdf_iterations')) {
      context.handle(
        _kdfIterationsMeta,
        kdfIterations.isAcceptableOrUnknown(
          data['kdf_iterations']!,
          _kdfIterationsMeta,
        ),
      );
    }
    if (data.containsKey('kdf_parallelism')) {
      context.handle(
        _kdfParallelismMeta,
        kdfParallelism.isAcceptableOrUnknown(
          data['kdf_parallelism']!,
          _kdfParallelismMeta,
        ),
      );
    }
    if (data.containsKey('kdf_salt')) {
      context.handle(
        _kdfSaltMeta,
        kdfSalt.isAcceptableOrUnknown(data['kdf_salt']!, _kdfSaltMeta),
      );
    } else if (isInserting) {
      context.missing(_kdfSaltMeta);
    }
    if (data.containsKey('password_envelope_nonce')) {
      context.handle(
        _passwordEnvelopeNonceMeta,
        passwordEnvelopeNonce.isAcceptableOrUnknown(
          data['password_envelope_nonce']!,
          _passwordEnvelopeNonceMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_passwordEnvelopeNonceMeta);
    }
    if (data.containsKey('wrapped_master_key')) {
      context.handle(
        _wrappedMasterKeyMeta,
        wrappedMasterKey.isAcceptableOrUnknown(
          data['wrapped_master_key']!,
          _wrappedMasterKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wrappedMasterKeyMeta);
    }
    if (data.containsKey('wrapped_master_key_mac')) {
      context.handle(
        _wrappedMasterKeyMacMeta,
        wrappedMasterKeyMac.isAcceptableOrUnknown(
          data['wrapped_master_key_mac']!,
          _wrappedMasterKeyMacMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_wrappedMasterKeyMacMeta);
    }
    if (data.containsKey('platform_key_alias')) {
      context.handle(
        _platformKeyAliasMeta,
        platformKeyAlias.isAcceptableOrUnknown(
          data['platform_key_alias']!,
          _platformKeyAliasMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    if (data.containsKey('rotated_at_utc')) {
      context.handle(
        _rotatedAtUtcMeta,
        rotatedAtUtc.isAcceptableOrUnknown(
          data['rotated_at_utc']!,
          _rotatedAtUtcMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupEncryptionProfileRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupEncryptionProfileRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      kdf: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kdf'],
      )!,
      kdfMemoryKib: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kdf_memory_kib'],
      )!,
      kdfIterations: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kdf_iterations'],
      )!,
      kdfParallelism: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}kdf_parallelism'],
      )!,
      kdfSalt: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}kdf_salt'],
      )!,
      passwordEnvelopeNonce: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}password_envelope_nonce'],
      )!,
      wrappedMasterKey: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}wrapped_master_key'],
      )!,
      wrappedMasterKeyMac: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}wrapped_master_key_mac'],
      )!,
      platformKeyAlias: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}platform_key_alias'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
      rotatedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}rotated_at_utc'],
      ),
    );
  }

  @override
  $BackupEncryptionProfilesTable createAlias(String alias) {
    return $BackupEncryptionProfilesTable(attachedDatabase, alias);
  }
}

class BackupEncryptionProfileRow extends DataClass
    implements Insertable<BackupEncryptionProfileRow> {
  final String id;
  final String kdf;
  final int kdfMemoryKib;
  final int kdfIterations;
  final int kdfParallelism;
  final Uint8List kdfSalt;
  final Uint8List passwordEnvelopeNonce;
  final Uint8List wrappedMasterKey;
  final Uint8List wrappedMasterKeyMac;
  final String? platformKeyAlias;
  final int createdAtUtc;
  final int? rotatedAtUtc;
  const BackupEncryptionProfileRow({
    required this.id,
    required this.kdf,
    required this.kdfMemoryKib,
    required this.kdfIterations,
    required this.kdfParallelism,
    required this.kdfSalt,
    required this.passwordEnvelopeNonce,
    required this.wrappedMasterKey,
    required this.wrappedMasterKeyMac,
    this.platformKeyAlias,
    required this.createdAtUtc,
    this.rotatedAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['kdf'] = Variable<String>(kdf);
    map['kdf_memory_kib'] = Variable<int>(kdfMemoryKib);
    map['kdf_iterations'] = Variable<int>(kdfIterations);
    map['kdf_parallelism'] = Variable<int>(kdfParallelism);
    map['kdf_salt'] = Variable<Uint8List>(kdfSalt);
    map['password_envelope_nonce'] = Variable<Uint8List>(passwordEnvelopeNonce);
    map['wrapped_master_key'] = Variable<Uint8List>(wrappedMasterKey);
    map['wrapped_master_key_mac'] = Variable<Uint8List>(wrappedMasterKeyMac);
    if (!nullToAbsent || platformKeyAlias != null) {
      map['platform_key_alias'] = Variable<String>(platformKeyAlias);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    if (!nullToAbsent || rotatedAtUtc != null) {
      map['rotated_at_utc'] = Variable<int>(rotatedAtUtc);
    }
    return map;
  }

  BackupEncryptionProfilesCompanion toCompanion(bool nullToAbsent) {
    return BackupEncryptionProfilesCompanion(
      id: Value(id),
      kdf: Value(kdf),
      kdfMemoryKib: Value(kdfMemoryKib),
      kdfIterations: Value(kdfIterations),
      kdfParallelism: Value(kdfParallelism),
      kdfSalt: Value(kdfSalt),
      passwordEnvelopeNonce: Value(passwordEnvelopeNonce),
      wrappedMasterKey: Value(wrappedMasterKey),
      wrappedMasterKeyMac: Value(wrappedMasterKeyMac),
      platformKeyAlias: platformKeyAlias == null && nullToAbsent
          ? const Value.absent()
          : Value(platformKeyAlias),
      createdAtUtc: Value(createdAtUtc),
      rotatedAtUtc: rotatedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(rotatedAtUtc),
    );
  }

  factory BackupEncryptionProfileRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupEncryptionProfileRow(
      id: serializer.fromJson<String>(json['id']),
      kdf: serializer.fromJson<String>(json['kdf']),
      kdfMemoryKib: serializer.fromJson<int>(json['kdfMemoryKib']),
      kdfIterations: serializer.fromJson<int>(json['kdfIterations']),
      kdfParallelism: serializer.fromJson<int>(json['kdfParallelism']),
      kdfSalt: serializer.fromJson<Uint8List>(json['kdfSalt']),
      passwordEnvelopeNonce: serializer.fromJson<Uint8List>(
        json['passwordEnvelopeNonce'],
      ),
      wrappedMasterKey: serializer.fromJson<Uint8List>(
        json['wrappedMasterKey'],
      ),
      wrappedMasterKeyMac: serializer.fromJson<Uint8List>(
        json['wrappedMasterKeyMac'],
      ),
      platformKeyAlias: serializer.fromJson<String?>(json['platformKeyAlias']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
      rotatedAtUtc: serializer.fromJson<int?>(json['rotatedAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'kdf': serializer.toJson<String>(kdf),
      'kdfMemoryKib': serializer.toJson<int>(kdfMemoryKib),
      'kdfIterations': serializer.toJson<int>(kdfIterations),
      'kdfParallelism': serializer.toJson<int>(kdfParallelism),
      'kdfSalt': serializer.toJson<Uint8List>(kdfSalt),
      'passwordEnvelopeNonce': serializer.toJson<Uint8List>(
        passwordEnvelopeNonce,
      ),
      'wrappedMasterKey': serializer.toJson<Uint8List>(wrappedMasterKey),
      'wrappedMasterKeyMac': serializer.toJson<Uint8List>(wrappedMasterKeyMac),
      'platformKeyAlias': serializer.toJson<String?>(platformKeyAlias),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
      'rotatedAtUtc': serializer.toJson<int?>(rotatedAtUtc),
    };
  }

  BackupEncryptionProfileRow copyWith({
    String? id,
    String? kdf,
    int? kdfMemoryKib,
    int? kdfIterations,
    int? kdfParallelism,
    Uint8List? kdfSalt,
    Uint8List? passwordEnvelopeNonce,
    Uint8List? wrappedMasterKey,
    Uint8List? wrappedMasterKeyMac,
    Value<String?> platformKeyAlias = const Value.absent(),
    int? createdAtUtc,
    Value<int?> rotatedAtUtc = const Value.absent(),
  }) => BackupEncryptionProfileRow(
    id: id ?? this.id,
    kdf: kdf ?? this.kdf,
    kdfMemoryKib: kdfMemoryKib ?? this.kdfMemoryKib,
    kdfIterations: kdfIterations ?? this.kdfIterations,
    kdfParallelism: kdfParallelism ?? this.kdfParallelism,
    kdfSalt: kdfSalt ?? this.kdfSalt,
    passwordEnvelopeNonce: passwordEnvelopeNonce ?? this.passwordEnvelopeNonce,
    wrappedMasterKey: wrappedMasterKey ?? this.wrappedMasterKey,
    wrappedMasterKeyMac: wrappedMasterKeyMac ?? this.wrappedMasterKeyMac,
    platformKeyAlias: platformKeyAlias.present
        ? platformKeyAlias.value
        : this.platformKeyAlias,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
    rotatedAtUtc: rotatedAtUtc.present ? rotatedAtUtc.value : this.rotatedAtUtc,
  );
  BackupEncryptionProfileRow copyWithCompanion(
    BackupEncryptionProfilesCompanion data,
  ) {
    return BackupEncryptionProfileRow(
      id: data.id.present ? data.id.value : this.id,
      kdf: data.kdf.present ? data.kdf.value : this.kdf,
      kdfMemoryKib: data.kdfMemoryKib.present
          ? data.kdfMemoryKib.value
          : this.kdfMemoryKib,
      kdfIterations: data.kdfIterations.present
          ? data.kdfIterations.value
          : this.kdfIterations,
      kdfParallelism: data.kdfParallelism.present
          ? data.kdfParallelism.value
          : this.kdfParallelism,
      kdfSalt: data.kdfSalt.present ? data.kdfSalt.value : this.kdfSalt,
      passwordEnvelopeNonce: data.passwordEnvelopeNonce.present
          ? data.passwordEnvelopeNonce.value
          : this.passwordEnvelopeNonce,
      wrappedMasterKey: data.wrappedMasterKey.present
          ? data.wrappedMasterKey.value
          : this.wrappedMasterKey,
      wrappedMasterKeyMac: data.wrappedMasterKeyMac.present
          ? data.wrappedMasterKeyMac.value
          : this.wrappedMasterKeyMac,
      platformKeyAlias: data.platformKeyAlias.present
          ? data.platformKeyAlias.value
          : this.platformKeyAlias,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
      rotatedAtUtc: data.rotatedAtUtc.present
          ? data.rotatedAtUtc.value
          : this.rotatedAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupEncryptionProfileRow(')
          ..write('id: $id, ')
          ..write('kdf: $kdf, ')
          ..write('kdfMemoryKib: $kdfMemoryKib, ')
          ..write('kdfIterations: $kdfIterations, ')
          ..write('kdfParallelism: $kdfParallelism, ')
          ..write('kdfSalt: $kdfSalt, ')
          ..write('passwordEnvelopeNonce: $passwordEnvelopeNonce, ')
          ..write('wrappedMasterKey: $wrappedMasterKey, ')
          ..write('wrappedMasterKeyMac: $wrappedMasterKeyMac, ')
          ..write('platformKeyAlias: $platformKeyAlias, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rotatedAtUtc: $rotatedAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    kdf,
    kdfMemoryKib,
    kdfIterations,
    kdfParallelism,
    $driftBlobEquality.hash(kdfSalt),
    $driftBlobEquality.hash(passwordEnvelopeNonce),
    $driftBlobEquality.hash(wrappedMasterKey),
    $driftBlobEquality.hash(wrappedMasterKeyMac),
    platformKeyAlias,
    createdAtUtc,
    rotatedAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupEncryptionProfileRow &&
          other.id == this.id &&
          other.kdf == this.kdf &&
          other.kdfMemoryKib == this.kdfMemoryKib &&
          other.kdfIterations == this.kdfIterations &&
          other.kdfParallelism == this.kdfParallelism &&
          $driftBlobEquality.equals(other.kdfSalt, this.kdfSalt) &&
          $driftBlobEquality.equals(
            other.passwordEnvelopeNonce,
            this.passwordEnvelopeNonce,
          ) &&
          $driftBlobEquality.equals(
            other.wrappedMasterKey,
            this.wrappedMasterKey,
          ) &&
          $driftBlobEquality.equals(
            other.wrappedMasterKeyMac,
            this.wrappedMasterKeyMac,
          ) &&
          other.platformKeyAlias == this.platformKeyAlias &&
          other.createdAtUtc == this.createdAtUtc &&
          other.rotatedAtUtc == this.rotatedAtUtc);
}

class BackupEncryptionProfilesCompanion
    extends UpdateCompanion<BackupEncryptionProfileRow> {
  final Value<String> id;
  final Value<String> kdf;
  final Value<int> kdfMemoryKib;
  final Value<int> kdfIterations;
  final Value<int> kdfParallelism;
  final Value<Uint8List> kdfSalt;
  final Value<Uint8List> passwordEnvelopeNonce;
  final Value<Uint8List> wrappedMasterKey;
  final Value<Uint8List> wrappedMasterKeyMac;
  final Value<String?> platformKeyAlias;
  final Value<int> createdAtUtc;
  final Value<int?> rotatedAtUtc;
  final Value<int> rowid;
  const BackupEncryptionProfilesCompanion({
    this.id = const Value.absent(),
    this.kdf = const Value.absent(),
    this.kdfMemoryKib = const Value.absent(),
    this.kdfIterations = const Value.absent(),
    this.kdfParallelism = const Value.absent(),
    this.kdfSalt = const Value.absent(),
    this.passwordEnvelopeNonce = const Value.absent(),
    this.wrappedMasterKey = const Value.absent(),
    this.wrappedMasterKeyMac = const Value.absent(),
    this.platformKeyAlias = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rotatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BackupEncryptionProfilesCompanion.insert({
    required String id,
    this.kdf = const Value.absent(),
    this.kdfMemoryKib = const Value.absent(),
    this.kdfIterations = const Value.absent(),
    this.kdfParallelism = const Value.absent(),
    required Uint8List kdfSalt,
    required Uint8List passwordEnvelopeNonce,
    required Uint8List wrappedMasterKey,
    required Uint8List wrappedMasterKeyMac,
    this.platformKeyAlias = const Value.absent(),
    required int createdAtUtc,
    this.rotatedAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kdfSalt = Value(kdfSalt),
       passwordEnvelopeNonce = Value(passwordEnvelopeNonce),
       wrappedMasterKey = Value(wrappedMasterKey),
       wrappedMasterKeyMac = Value(wrappedMasterKeyMac),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<BackupEncryptionProfileRow> custom({
    Expression<String>? id,
    Expression<String>? kdf,
    Expression<int>? kdfMemoryKib,
    Expression<int>? kdfIterations,
    Expression<int>? kdfParallelism,
    Expression<Uint8List>? kdfSalt,
    Expression<Uint8List>? passwordEnvelopeNonce,
    Expression<Uint8List>? wrappedMasterKey,
    Expression<Uint8List>? wrappedMasterKeyMac,
    Expression<String>? platformKeyAlias,
    Expression<int>? createdAtUtc,
    Expression<int>? rotatedAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (kdf != null) 'kdf': kdf,
      if (kdfMemoryKib != null) 'kdf_memory_kib': kdfMemoryKib,
      if (kdfIterations != null) 'kdf_iterations': kdfIterations,
      if (kdfParallelism != null) 'kdf_parallelism': kdfParallelism,
      if (kdfSalt != null) 'kdf_salt': kdfSalt,
      if (passwordEnvelopeNonce != null)
        'password_envelope_nonce': passwordEnvelopeNonce,
      if (wrappedMasterKey != null) 'wrapped_master_key': wrappedMasterKey,
      if (wrappedMasterKeyMac != null)
        'wrapped_master_key_mac': wrappedMasterKeyMac,
      if (platformKeyAlias != null) 'platform_key_alias': platformKeyAlias,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rotatedAtUtc != null) 'rotated_at_utc': rotatedAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BackupEncryptionProfilesCompanion copyWith({
    Value<String>? id,
    Value<String>? kdf,
    Value<int>? kdfMemoryKib,
    Value<int>? kdfIterations,
    Value<int>? kdfParallelism,
    Value<Uint8List>? kdfSalt,
    Value<Uint8List>? passwordEnvelopeNonce,
    Value<Uint8List>? wrappedMasterKey,
    Value<Uint8List>? wrappedMasterKeyMac,
    Value<String?>? platformKeyAlias,
    Value<int>? createdAtUtc,
    Value<int?>? rotatedAtUtc,
    Value<int>? rowid,
  }) {
    return BackupEncryptionProfilesCompanion(
      id: id ?? this.id,
      kdf: kdf ?? this.kdf,
      kdfMemoryKib: kdfMemoryKib ?? this.kdfMemoryKib,
      kdfIterations: kdfIterations ?? this.kdfIterations,
      kdfParallelism: kdfParallelism ?? this.kdfParallelism,
      kdfSalt: kdfSalt ?? this.kdfSalt,
      passwordEnvelopeNonce:
          passwordEnvelopeNonce ?? this.passwordEnvelopeNonce,
      wrappedMasterKey: wrappedMasterKey ?? this.wrappedMasterKey,
      wrappedMasterKeyMac: wrappedMasterKeyMac ?? this.wrappedMasterKeyMac,
      platformKeyAlias: platformKeyAlias ?? this.platformKeyAlias,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rotatedAtUtc: rotatedAtUtc ?? this.rotatedAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (kdf.present) {
      map['kdf'] = Variable<String>(kdf.value);
    }
    if (kdfMemoryKib.present) {
      map['kdf_memory_kib'] = Variable<int>(kdfMemoryKib.value);
    }
    if (kdfIterations.present) {
      map['kdf_iterations'] = Variable<int>(kdfIterations.value);
    }
    if (kdfParallelism.present) {
      map['kdf_parallelism'] = Variable<int>(kdfParallelism.value);
    }
    if (kdfSalt.present) {
      map['kdf_salt'] = Variable<Uint8List>(kdfSalt.value);
    }
    if (passwordEnvelopeNonce.present) {
      map['password_envelope_nonce'] = Variable<Uint8List>(
        passwordEnvelopeNonce.value,
      );
    }
    if (wrappedMasterKey.present) {
      map['wrapped_master_key'] = Variable<Uint8List>(wrappedMasterKey.value);
    }
    if (wrappedMasterKeyMac.present) {
      map['wrapped_master_key_mac'] = Variable<Uint8List>(
        wrappedMasterKeyMac.value,
      );
    }
    if (platformKeyAlias.present) {
      map['platform_key_alias'] = Variable<String>(platformKeyAlias.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (rotatedAtUtc.present) {
      map['rotated_at_utc'] = Variable<int>(rotatedAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupEncryptionProfilesCompanion(')
          ..write('id: $id, ')
          ..write('kdf: $kdf, ')
          ..write('kdfMemoryKib: $kdfMemoryKib, ')
          ..write('kdfIterations: $kdfIterations, ')
          ..write('kdfParallelism: $kdfParallelism, ')
          ..write('kdfSalt: $kdfSalt, ')
          ..write('passwordEnvelopeNonce: $passwordEnvelopeNonce, ')
          ..write('wrappedMasterKey: $wrappedMasterKey, ')
          ..write('wrappedMasterKeyMac: $wrappedMasterKeyMac, ')
          ..write('platformKeyAlias: $platformKeyAlias, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rotatedAtUtc: $rotatedAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BackupRunsTable extends BackupRuns
    with TableInfo<$BackupRunsTable, BackupRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BackupRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetIdMeta = const VerificationMeta(
    'targetId',
  );
  @override
  late final GeneratedColumn<String> targetId = GeneratedColumn<String>(
    'target_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES backup_targets (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _encryptionProfileIdMeta =
      const VerificationMeta('encryptionProfileId');
  @override
  late final GeneratedColumn<String> encryptionProfileId =
      GeneratedColumn<String>(
        'encryption_profile_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES backup_encryption_profiles (id) ON DELETE SET NULL',
        ),
      );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _archiveNameMeta = const VerificationMeta(
    'archiveName',
  );
  @override
  late final GeneratedColumn<String> archiveName = GeneratedColumn<String>(
    'archive_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _appVersionMeta = const VerificationMeta(
    'appVersion',
  );
  @override
  late final GeneratedColumn<String> appVersion = GeneratedColumn<String>(
    'app_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _databaseSchemaVersionMeta =
      const VerificationMeta('databaseSchemaVersion');
  @override
  late final GeneratedColumn<int> databaseSchemaVersion = GeneratedColumn<int>(
    'database_schema_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _manifestVersionMeta = const VerificationMeta(
    'manifestVersion',
  );
  @override
  late final GeneratedColumn<int> manifestVersion = GeneratedColumn<int>(
    'manifest_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordCountsJsonMeta = const VerificationMeta(
    'recordCountsJson',
  );
  @override
  late final GeneratedColumn<String> recordCountsJson = GeneratedColumn<String>(
    'record_counts_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _byteLengthMeta = const VerificationMeta(
    'byteLength',
  );
  @override
  late final GeneratedColumn<int> byteLength = GeneratedColumn<int>(
    'byte_length',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _archiveSha256Meta = const VerificationMeta(
    'archiveSha256',
  );
  @override
  late final GeneratedColumn<String> archiveSha256 = GeneratedColumn<String>(
    'archive_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  @override
  late final GeneratedColumn<int> startedAtUtc = GeneratedColumn<int>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtUtcMeta = const VerificationMeta(
    'completedAtUtc',
  );
  @override
  late final GeneratedColumn<int> completedAtUtc = GeneratedColumn<int>(
    'completed_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    targetId,
    encryptionProfileId,
    kind,
    status,
    archiveName,
    appVersion,
    databaseSchemaVersion,
    manifestVersion,
    recordCountsJson,
    byteLength,
    archiveSha256,
    startedAtUtc,
    completedAtUtc,
    errorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'backup_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<BackupRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('target_id')) {
      context.handle(
        _targetIdMeta,
        targetId.isAcceptableOrUnknown(data['target_id']!, _targetIdMeta),
      );
    }
    if (data.containsKey('encryption_profile_id')) {
      context.handle(
        _encryptionProfileIdMeta,
        encryptionProfileId.isAcceptableOrUnknown(
          data['encryption_profile_id']!,
          _encryptionProfileIdMeta,
        ),
      );
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('archive_name')) {
      context.handle(
        _archiveNameMeta,
        archiveName.isAcceptableOrUnknown(
          data['archive_name']!,
          _archiveNameMeta,
        ),
      );
    }
    if (data.containsKey('app_version')) {
      context.handle(
        _appVersionMeta,
        appVersion.isAcceptableOrUnknown(data['app_version']!, _appVersionMeta),
      );
    } else if (isInserting) {
      context.missing(_appVersionMeta);
    }
    if (data.containsKey('database_schema_version')) {
      context.handle(
        _databaseSchemaVersionMeta,
        databaseSchemaVersion.isAcceptableOrUnknown(
          data['database_schema_version']!,
          _databaseSchemaVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_databaseSchemaVersionMeta);
    }
    if (data.containsKey('manifest_version')) {
      context.handle(
        _manifestVersionMeta,
        manifestVersion.isAcceptableOrUnknown(
          data['manifest_version']!,
          _manifestVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_manifestVersionMeta);
    }
    if (data.containsKey('record_counts_json')) {
      context.handle(
        _recordCountsJsonMeta,
        recordCountsJson.isAcceptableOrUnknown(
          data['record_counts_json']!,
          _recordCountsJsonMeta,
        ),
      );
    }
    if (data.containsKey('byte_length')) {
      context.handle(
        _byteLengthMeta,
        byteLength.isAcceptableOrUnknown(data['byte_length']!, _byteLengthMeta),
      );
    }
    if (data.containsKey('archive_sha256')) {
      context.handle(
        _archiveSha256Meta,
        archiveSha256.isAcceptableOrUnknown(
          data['archive_sha256']!,
          _archiveSha256Meta,
        ),
      );
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMeta);
    }
    if (data.containsKey('completed_at_utc')) {
      context.handle(
        _completedAtUtcMeta,
        completedAtUtc.isAcceptableOrUnknown(
          data['completed_at_utc']!,
          _completedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  BackupRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BackupRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      targetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_id'],
      ),
      encryptionProfileId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encryption_profile_id'],
      ),
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      archiveName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archive_name'],
      ),
      appVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}app_version'],
      )!,
      databaseSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}database_schema_version'],
      )!,
      manifestVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manifest_version'],
      )!,
      recordCountsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}record_counts_json'],
      ),
      byteLength: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}byte_length'],
      ),
      archiveSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}archive_sha256'],
      ),
      startedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_utc'],
      )!,
      completedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_utc'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
    );
  }

  @override
  $BackupRunsTable createAlias(String alias) {
    return $BackupRunsTable(attachedDatabase, alias);
  }
}

class BackupRunRow extends DataClass implements Insertable<BackupRunRow> {
  final String id;
  final String? targetId;
  final String? encryptionProfileId;
  final String kind;
  final String status;
  final String? archiveName;
  final String appVersion;
  final int databaseSchemaVersion;
  final int manifestVersion;
  final String? recordCountsJson;
  final int? byteLength;
  final String? archiveSha256;
  final int startedAtUtc;
  final int? completedAtUtc;
  final String? errorCode;
  const BackupRunRow({
    required this.id,
    this.targetId,
    this.encryptionProfileId,
    required this.kind,
    required this.status,
    this.archiveName,
    required this.appVersion,
    required this.databaseSchemaVersion,
    required this.manifestVersion,
    this.recordCountsJson,
    this.byteLength,
    this.archiveSha256,
    required this.startedAtUtc,
    this.completedAtUtc,
    this.errorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    if (!nullToAbsent || targetId != null) {
      map['target_id'] = Variable<String>(targetId);
    }
    if (!nullToAbsent || encryptionProfileId != null) {
      map['encryption_profile_id'] = Variable<String>(encryptionProfileId);
    }
    map['kind'] = Variable<String>(kind);
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || archiveName != null) {
      map['archive_name'] = Variable<String>(archiveName);
    }
    map['app_version'] = Variable<String>(appVersion);
    map['database_schema_version'] = Variable<int>(databaseSchemaVersion);
    map['manifest_version'] = Variable<int>(manifestVersion);
    if (!nullToAbsent || recordCountsJson != null) {
      map['record_counts_json'] = Variable<String>(recordCountsJson);
    }
    if (!nullToAbsent || byteLength != null) {
      map['byte_length'] = Variable<int>(byteLength);
    }
    if (!nullToAbsent || archiveSha256 != null) {
      map['archive_sha256'] = Variable<String>(archiveSha256);
    }
    map['started_at_utc'] = Variable<int>(startedAtUtc);
    if (!nullToAbsent || completedAtUtc != null) {
      map['completed_at_utc'] = Variable<int>(completedAtUtc);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    return map;
  }

  BackupRunsCompanion toCompanion(bool nullToAbsent) {
    return BackupRunsCompanion(
      id: Value(id),
      targetId: targetId == null && nullToAbsent
          ? const Value.absent()
          : Value(targetId),
      encryptionProfileId: encryptionProfileId == null && nullToAbsent
          ? const Value.absent()
          : Value(encryptionProfileId),
      kind: Value(kind),
      status: Value(status),
      archiveName: archiveName == null && nullToAbsent
          ? const Value.absent()
          : Value(archiveName),
      appVersion: Value(appVersion),
      databaseSchemaVersion: Value(databaseSchemaVersion),
      manifestVersion: Value(manifestVersion),
      recordCountsJson: recordCountsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(recordCountsJson),
      byteLength: byteLength == null && nullToAbsent
          ? const Value.absent()
          : Value(byteLength),
      archiveSha256: archiveSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(archiveSha256),
      startedAtUtc: Value(startedAtUtc),
      completedAtUtc: completedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtUtc),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
    );
  }

  factory BackupRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BackupRunRow(
      id: serializer.fromJson<String>(json['id']),
      targetId: serializer.fromJson<String?>(json['targetId']),
      encryptionProfileId: serializer.fromJson<String?>(
        json['encryptionProfileId'],
      ),
      kind: serializer.fromJson<String>(json['kind']),
      status: serializer.fromJson<String>(json['status']),
      archiveName: serializer.fromJson<String?>(json['archiveName']),
      appVersion: serializer.fromJson<String>(json['appVersion']),
      databaseSchemaVersion: serializer.fromJson<int>(
        json['databaseSchemaVersion'],
      ),
      manifestVersion: serializer.fromJson<int>(json['manifestVersion']),
      recordCountsJson: serializer.fromJson<String?>(json['recordCountsJson']),
      byteLength: serializer.fromJson<int?>(json['byteLength']),
      archiveSha256: serializer.fromJson<String?>(json['archiveSha256']),
      startedAtUtc: serializer.fromJson<int>(json['startedAtUtc']),
      completedAtUtc: serializer.fromJson<int?>(json['completedAtUtc']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'targetId': serializer.toJson<String?>(targetId),
      'encryptionProfileId': serializer.toJson<String?>(encryptionProfileId),
      'kind': serializer.toJson<String>(kind),
      'status': serializer.toJson<String>(status),
      'archiveName': serializer.toJson<String?>(archiveName),
      'appVersion': serializer.toJson<String>(appVersion),
      'databaseSchemaVersion': serializer.toJson<int>(databaseSchemaVersion),
      'manifestVersion': serializer.toJson<int>(manifestVersion),
      'recordCountsJson': serializer.toJson<String?>(recordCountsJson),
      'byteLength': serializer.toJson<int?>(byteLength),
      'archiveSha256': serializer.toJson<String?>(archiveSha256),
      'startedAtUtc': serializer.toJson<int>(startedAtUtc),
      'completedAtUtc': serializer.toJson<int?>(completedAtUtc),
      'errorCode': serializer.toJson<String?>(errorCode),
    };
  }

  BackupRunRow copyWith({
    String? id,
    Value<String?> targetId = const Value.absent(),
    Value<String?> encryptionProfileId = const Value.absent(),
    String? kind,
    String? status,
    Value<String?> archiveName = const Value.absent(),
    String? appVersion,
    int? databaseSchemaVersion,
    int? manifestVersion,
    Value<String?> recordCountsJson = const Value.absent(),
    Value<int?> byteLength = const Value.absent(),
    Value<String?> archiveSha256 = const Value.absent(),
    int? startedAtUtc,
    Value<int?> completedAtUtc = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
  }) => BackupRunRow(
    id: id ?? this.id,
    targetId: targetId.present ? targetId.value : this.targetId,
    encryptionProfileId: encryptionProfileId.present
        ? encryptionProfileId.value
        : this.encryptionProfileId,
    kind: kind ?? this.kind,
    status: status ?? this.status,
    archiveName: archiveName.present ? archiveName.value : this.archiveName,
    appVersion: appVersion ?? this.appVersion,
    databaseSchemaVersion: databaseSchemaVersion ?? this.databaseSchemaVersion,
    manifestVersion: manifestVersion ?? this.manifestVersion,
    recordCountsJson: recordCountsJson.present
        ? recordCountsJson.value
        : this.recordCountsJson,
    byteLength: byteLength.present ? byteLength.value : this.byteLength,
    archiveSha256: archiveSha256.present
        ? archiveSha256.value
        : this.archiveSha256,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    completedAtUtc: completedAtUtc.present
        ? completedAtUtc.value
        : this.completedAtUtc,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
  );
  BackupRunRow copyWithCompanion(BackupRunsCompanion data) {
    return BackupRunRow(
      id: data.id.present ? data.id.value : this.id,
      targetId: data.targetId.present ? data.targetId.value : this.targetId,
      encryptionProfileId: data.encryptionProfileId.present
          ? data.encryptionProfileId.value
          : this.encryptionProfileId,
      kind: data.kind.present ? data.kind.value : this.kind,
      status: data.status.present ? data.status.value : this.status,
      archiveName: data.archiveName.present
          ? data.archiveName.value
          : this.archiveName,
      appVersion: data.appVersion.present
          ? data.appVersion.value
          : this.appVersion,
      databaseSchemaVersion: data.databaseSchemaVersion.present
          ? data.databaseSchemaVersion.value
          : this.databaseSchemaVersion,
      manifestVersion: data.manifestVersion.present
          ? data.manifestVersion.value
          : this.manifestVersion,
      recordCountsJson: data.recordCountsJson.present
          ? data.recordCountsJson.value
          : this.recordCountsJson,
      byteLength: data.byteLength.present
          ? data.byteLength.value
          : this.byteLength,
      archiveSha256: data.archiveSha256.present
          ? data.archiveSha256.value
          : this.archiveSha256,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      completedAtUtc: data.completedAtUtc.present
          ? data.completedAtUtc.value
          : this.completedAtUtc,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BackupRunRow(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('encryptionProfileId: $encryptionProfileId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('archiveName: $archiveName, ')
          ..write('appVersion: $appVersion, ')
          ..write('databaseSchemaVersion: $databaseSchemaVersion, ')
          ..write('manifestVersion: $manifestVersion, ')
          ..write('recordCountsJson: $recordCountsJson, ')
          ..write('byteLength: $byteLength, ')
          ..write('archiveSha256: $archiveSha256, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('completedAtUtc: $completedAtUtc, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    targetId,
    encryptionProfileId,
    kind,
    status,
    archiveName,
    appVersion,
    databaseSchemaVersion,
    manifestVersion,
    recordCountsJson,
    byteLength,
    archiveSha256,
    startedAtUtc,
    completedAtUtc,
    errorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BackupRunRow &&
          other.id == this.id &&
          other.targetId == this.targetId &&
          other.encryptionProfileId == this.encryptionProfileId &&
          other.kind == this.kind &&
          other.status == this.status &&
          other.archiveName == this.archiveName &&
          other.appVersion == this.appVersion &&
          other.databaseSchemaVersion == this.databaseSchemaVersion &&
          other.manifestVersion == this.manifestVersion &&
          other.recordCountsJson == this.recordCountsJson &&
          other.byteLength == this.byteLength &&
          other.archiveSha256 == this.archiveSha256 &&
          other.startedAtUtc == this.startedAtUtc &&
          other.completedAtUtc == this.completedAtUtc &&
          other.errorCode == this.errorCode);
}

class BackupRunsCompanion extends UpdateCompanion<BackupRunRow> {
  final Value<String> id;
  final Value<String?> targetId;
  final Value<String?> encryptionProfileId;
  final Value<String> kind;
  final Value<String> status;
  final Value<String?> archiveName;
  final Value<String> appVersion;
  final Value<int> databaseSchemaVersion;
  final Value<int> manifestVersion;
  final Value<String?> recordCountsJson;
  final Value<int?> byteLength;
  final Value<String?> archiveSha256;
  final Value<int> startedAtUtc;
  final Value<int?> completedAtUtc;
  final Value<String?> errorCode;
  final Value<int> rowid;
  const BackupRunsCompanion({
    this.id = const Value.absent(),
    this.targetId = const Value.absent(),
    this.encryptionProfileId = const Value.absent(),
    this.kind = const Value.absent(),
    this.status = const Value.absent(),
    this.archiveName = const Value.absent(),
    this.appVersion = const Value.absent(),
    this.databaseSchemaVersion = const Value.absent(),
    this.manifestVersion = const Value.absent(),
    this.recordCountsJson = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.archiveSha256 = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.completedAtUtc = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BackupRunsCompanion.insert({
    required String id,
    this.targetId = const Value.absent(),
    this.encryptionProfileId = const Value.absent(),
    required String kind,
    required String status,
    this.archiveName = const Value.absent(),
    required String appVersion,
    required int databaseSchemaVersion,
    required int manifestVersion,
    this.recordCountsJson = const Value.absent(),
    this.byteLength = const Value.absent(),
    this.archiveSha256 = const Value.absent(),
    required int startedAtUtc,
    this.completedAtUtc = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       kind = Value(kind),
       status = Value(status),
       appVersion = Value(appVersion),
       databaseSchemaVersion = Value(databaseSchemaVersion),
       manifestVersion = Value(manifestVersion),
       startedAtUtc = Value(startedAtUtc);
  static Insertable<BackupRunRow> custom({
    Expression<String>? id,
    Expression<String>? targetId,
    Expression<String>? encryptionProfileId,
    Expression<String>? kind,
    Expression<String>? status,
    Expression<String>? archiveName,
    Expression<String>? appVersion,
    Expression<int>? databaseSchemaVersion,
    Expression<int>? manifestVersion,
    Expression<String>? recordCountsJson,
    Expression<int>? byteLength,
    Expression<String>? archiveSha256,
    Expression<int>? startedAtUtc,
    Expression<int>? completedAtUtc,
    Expression<String>? errorCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (targetId != null) 'target_id': targetId,
      if (encryptionProfileId != null)
        'encryption_profile_id': encryptionProfileId,
      if (kind != null) 'kind': kind,
      if (status != null) 'status': status,
      if (archiveName != null) 'archive_name': archiveName,
      if (appVersion != null) 'app_version': appVersion,
      if (databaseSchemaVersion != null)
        'database_schema_version': databaseSchemaVersion,
      if (manifestVersion != null) 'manifest_version': manifestVersion,
      if (recordCountsJson != null) 'record_counts_json': recordCountsJson,
      if (byteLength != null) 'byte_length': byteLength,
      if (archiveSha256 != null) 'archive_sha256': archiveSha256,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (completedAtUtc != null) 'completed_at_utc': completedAtUtc,
      if (errorCode != null) 'error_code': errorCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BackupRunsCompanion copyWith({
    Value<String>? id,
    Value<String?>? targetId,
    Value<String?>? encryptionProfileId,
    Value<String>? kind,
    Value<String>? status,
    Value<String?>? archiveName,
    Value<String>? appVersion,
    Value<int>? databaseSchemaVersion,
    Value<int>? manifestVersion,
    Value<String?>? recordCountsJson,
    Value<int?>? byteLength,
    Value<String?>? archiveSha256,
    Value<int>? startedAtUtc,
    Value<int?>? completedAtUtc,
    Value<String?>? errorCode,
    Value<int>? rowid,
  }) {
    return BackupRunsCompanion(
      id: id ?? this.id,
      targetId: targetId ?? this.targetId,
      encryptionProfileId: encryptionProfileId ?? this.encryptionProfileId,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      archiveName: archiveName ?? this.archiveName,
      appVersion: appVersion ?? this.appVersion,
      databaseSchemaVersion:
          databaseSchemaVersion ?? this.databaseSchemaVersion,
      manifestVersion: manifestVersion ?? this.manifestVersion,
      recordCountsJson: recordCountsJson ?? this.recordCountsJson,
      byteLength: byteLength ?? this.byteLength,
      archiveSha256: archiveSha256 ?? this.archiveSha256,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      completedAtUtc: completedAtUtc ?? this.completedAtUtc,
      errorCode: errorCode ?? this.errorCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (targetId.present) {
      map['target_id'] = Variable<String>(targetId.value);
    }
    if (encryptionProfileId.present) {
      map['encryption_profile_id'] = Variable<String>(
        encryptionProfileId.value,
      );
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (archiveName.present) {
      map['archive_name'] = Variable<String>(archiveName.value);
    }
    if (appVersion.present) {
      map['app_version'] = Variable<String>(appVersion.value);
    }
    if (databaseSchemaVersion.present) {
      map['database_schema_version'] = Variable<int>(
        databaseSchemaVersion.value,
      );
    }
    if (manifestVersion.present) {
      map['manifest_version'] = Variable<int>(manifestVersion.value);
    }
    if (recordCountsJson.present) {
      map['record_counts_json'] = Variable<String>(recordCountsJson.value);
    }
    if (byteLength.present) {
      map['byte_length'] = Variable<int>(byteLength.value);
    }
    if (archiveSha256.present) {
      map['archive_sha256'] = Variable<String>(archiveSha256.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<int>(startedAtUtc.value);
    }
    if (completedAtUtc.present) {
      map['completed_at_utc'] = Variable<int>(completedAtUtc.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BackupRunsCompanion(')
          ..write('id: $id, ')
          ..write('targetId: $targetId, ')
          ..write('encryptionProfileId: $encryptionProfileId, ')
          ..write('kind: $kind, ')
          ..write('status: $status, ')
          ..write('archiveName: $archiveName, ')
          ..write('appVersion: $appVersion, ')
          ..write('databaseSchemaVersion: $databaseSchemaVersion, ')
          ..write('manifestVersion: $manifestVersion, ')
          ..write('recordCountsJson: $recordCountsJson, ')
          ..write('byteLength: $byteLength, ')
          ..write('archiveSha256: $archiveSha256, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('completedAtUtc: $completedAtUtc, ')
          ..write('errorCode: $errorCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RestoreRunsTable extends RestoreRuns
    with TableInfo<$RestoreRunsTable, RestoreRunRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestoreRunsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceNameMeta = const VerificationMeta(
    'sourceName',
  );
  @override
  late final GeneratedColumn<String> sourceName = GeneratedColumn<String>(
    'source_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceSha256Meta = const VerificationMeta(
    'sourceSha256',
  );
  @override
  late final GeneratedColumn<String> sourceSha256 = GeneratedColumn<String>(
    'source_sha256',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceSchemaVersionMeta =
      const VerificationMeta('sourceSchemaVersion');
  @override
  late final GeneratedColumn<int> sourceSchemaVersion = GeneratedColumn<int>(
    'source_schema_version',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preRestoreBackupRunIdMeta =
      const VerificationMeta('preRestoreBackupRunId');
  @override
  late final GeneratedColumn<String> preRestoreBackupRunId =
      GeneratedColumn<String>(
        'pre_restore_backup_run_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES backup_runs (id) ON DELETE SET NULL',
        ),
      );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _summaryJsonMeta = const VerificationMeta(
    'summaryJson',
  );
  @override
  late final GeneratedColumn<String> summaryJson = GeneratedColumn<String>(
    'summary_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _startedAtUtcMeta = const VerificationMeta(
    'startedAtUtc',
  );
  @override
  late final GeneratedColumn<int> startedAtUtc = GeneratedColumn<int>(
    'started_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _completedAtUtcMeta = const VerificationMeta(
    'completedAtUtc',
  );
  @override
  late final GeneratedColumn<int> completedAtUtc = GeneratedColumn<int>(
    'completed_at_utc',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorCodeMeta = const VerificationMeta(
    'errorCode',
  );
  @override
  late final GeneratedColumn<String> errorCode = GeneratedColumn<String>(
    'error_code',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    sourceName,
    sourceSha256,
    mode,
    sourceSchemaVersion,
    preRestoreBackupRunId,
    status,
    summaryJson,
    startedAtUtc,
    completedAtUtc,
    errorCode,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restore_runs';
  @override
  VerificationContext validateIntegrity(
    Insertable<RestoreRunRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('source_name')) {
      context.handle(
        _sourceNameMeta,
        sourceName.isAcceptableOrUnknown(data['source_name']!, _sourceNameMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceNameMeta);
    }
    if (data.containsKey('source_sha256')) {
      context.handle(
        _sourceSha256Meta,
        sourceSha256.isAcceptableOrUnknown(
          data['source_sha256']!,
          _sourceSha256Meta,
        ),
      );
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('source_schema_version')) {
      context.handle(
        _sourceSchemaVersionMeta,
        sourceSchemaVersion.isAcceptableOrUnknown(
          data['source_schema_version']!,
          _sourceSchemaVersionMeta,
        ),
      );
    }
    if (data.containsKey('pre_restore_backup_run_id')) {
      context.handle(
        _preRestoreBackupRunIdMeta,
        preRestoreBackupRunId.isAcceptableOrUnknown(
          data['pre_restore_backup_run_id']!,
          _preRestoreBackupRunIdMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    } else if (isInserting) {
      context.missing(_statusMeta);
    }
    if (data.containsKey('summary_json')) {
      context.handle(
        _summaryJsonMeta,
        summaryJson.isAcceptableOrUnknown(
          data['summary_json']!,
          _summaryJsonMeta,
        ),
      );
    }
    if (data.containsKey('started_at_utc')) {
      context.handle(
        _startedAtUtcMeta,
        startedAtUtc.isAcceptableOrUnknown(
          data['started_at_utc']!,
          _startedAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_startedAtUtcMeta);
    }
    if (data.containsKey('completed_at_utc')) {
      context.handle(
        _completedAtUtcMeta,
        completedAtUtc.isAcceptableOrUnknown(
          data['completed_at_utc']!,
          _completedAtUtcMeta,
        ),
      );
    }
    if (data.containsKey('error_code')) {
      context.handle(
        _errorCodeMeta,
        errorCode.isAcceptableOrUnknown(data['error_code']!, _errorCodeMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestoreRunRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestoreRunRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      sourceName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_name'],
      )!,
      sourceSha256: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_sha256'],
      ),
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      sourceSchemaVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}source_schema_version'],
      ),
      preRestoreBackupRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pre_restore_backup_run_id'],
      ),
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      summaryJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary_json'],
      ),
      startedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}started_at_utc'],
      )!,
      completedAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}completed_at_utc'],
      ),
      errorCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error_code'],
      ),
    );
  }

  @override
  $RestoreRunsTable createAlias(String alias) {
    return $RestoreRunsTable(attachedDatabase, alias);
  }
}

class RestoreRunRow extends DataClass implements Insertable<RestoreRunRow> {
  final String id;
  final String sourceName;
  final String? sourceSha256;
  final String mode;
  final int? sourceSchemaVersion;
  final String? preRestoreBackupRunId;
  final String status;
  final String? summaryJson;
  final int startedAtUtc;
  final int? completedAtUtc;
  final String? errorCode;
  const RestoreRunRow({
    required this.id,
    required this.sourceName,
    this.sourceSha256,
    required this.mode,
    this.sourceSchemaVersion,
    this.preRestoreBackupRunId,
    required this.status,
    this.summaryJson,
    required this.startedAtUtc,
    this.completedAtUtc,
    this.errorCode,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['source_name'] = Variable<String>(sourceName);
    if (!nullToAbsent || sourceSha256 != null) {
      map['source_sha256'] = Variable<String>(sourceSha256);
    }
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || sourceSchemaVersion != null) {
      map['source_schema_version'] = Variable<int>(sourceSchemaVersion);
    }
    if (!nullToAbsent || preRestoreBackupRunId != null) {
      map['pre_restore_backup_run_id'] = Variable<String>(
        preRestoreBackupRunId,
      );
    }
    map['status'] = Variable<String>(status);
    if (!nullToAbsent || summaryJson != null) {
      map['summary_json'] = Variable<String>(summaryJson);
    }
    map['started_at_utc'] = Variable<int>(startedAtUtc);
    if (!nullToAbsent || completedAtUtc != null) {
      map['completed_at_utc'] = Variable<int>(completedAtUtc);
    }
    if (!nullToAbsent || errorCode != null) {
      map['error_code'] = Variable<String>(errorCode);
    }
    return map;
  }

  RestoreRunsCompanion toCompanion(bool nullToAbsent) {
    return RestoreRunsCompanion(
      id: Value(id),
      sourceName: Value(sourceName),
      sourceSha256: sourceSha256 == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSha256),
      mode: Value(mode),
      sourceSchemaVersion: sourceSchemaVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(sourceSchemaVersion),
      preRestoreBackupRunId: preRestoreBackupRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(preRestoreBackupRunId),
      status: Value(status),
      summaryJson: summaryJson == null && nullToAbsent
          ? const Value.absent()
          : Value(summaryJson),
      startedAtUtc: Value(startedAtUtc),
      completedAtUtc: completedAtUtc == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAtUtc),
      errorCode: errorCode == null && nullToAbsent
          ? const Value.absent()
          : Value(errorCode),
    );
  }

  factory RestoreRunRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestoreRunRow(
      id: serializer.fromJson<String>(json['id']),
      sourceName: serializer.fromJson<String>(json['sourceName']),
      sourceSha256: serializer.fromJson<String?>(json['sourceSha256']),
      mode: serializer.fromJson<String>(json['mode']),
      sourceSchemaVersion: serializer.fromJson<int?>(
        json['sourceSchemaVersion'],
      ),
      preRestoreBackupRunId: serializer.fromJson<String?>(
        json['preRestoreBackupRunId'],
      ),
      status: serializer.fromJson<String>(json['status']),
      summaryJson: serializer.fromJson<String?>(json['summaryJson']),
      startedAtUtc: serializer.fromJson<int>(json['startedAtUtc']),
      completedAtUtc: serializer.fromJson<int?>(json['completedAtUtc']),
      errorCode: serializer.fromJson<String?>(json['errorCode']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'sourceName': serializer.toJson<String>(sourceName),
      'sourceSha256': serializer.toJson<String?>(sourceSha256),
      'mode': serializer.toJson<String>(mode),
      'sourceSchemaVersion': serializer.toJson<int?>(sourceSchemaVersion),
      'preRestoreBackupRunId': serializer.toJson<String?>(
        preRestoreBackupRunId,
      ),
      'status': serializer.toJson<String>(status),
      'summaryJson': serializer.toJson<String?>(summaryJson),
      'startedAtUtc': serializer.toJson<int>(startedAtUtc),
      'completedAtUtc': serializer.toJson<int?>(completedAtUtc),
      'errorCode': serializer.toJson<String?>(errorCode),
    };
  }

  RestoreRunRow copyWith({
    String? id,
    String? sourceName,
    Value<String?> sourceSha256 = const Value.absent(),
    String? mode,
    Value<int?> sourceSchemaVersion = const Value.absent(),
    Value<String?> preRestoreBackupRunId = const Value.absent(),
    String? status,
    Value<String?> summaryJson = const Value.absent(),
    int? startedAtUtc,
    Value<int?> completedAtUtc = const Value.absent(),
    Value<String?> errorCode = const Value.absent(),
  }) => RestoreRunRow(
    id: id ?? this.id,
    sourceName: sourceName ?? this.sourceName,
    sourceSha256: sourceSha256.present ? sourceSha256.value : this.sourceSha256,
    mode: mode ?? this.mode,
    sourceSchemaVersion: sourceSchemaVersion.present
        ? sourceSchemaVersion.value
        : this.sourceSchemaVersion,
    preRestoreBackupRunId: preRestoreBackupRunId.present
        ? preRestoreBackupRunId.value
        : this.preRestoreBackupRunId,
    status: status ?? this.status,
    summaryJson: summaryJson.present ? summaryJson.value : this.summaryJson,
    startedAtUtc: startedAtUtc ?? this.startedAtUtc,
    completedAtUtc: completedAtUtc.present
        ? completedAtUtc.value
        : this.completedAtUtc,
    errorCode: errorCode.present ? errorCode.value : this.errorCode,
  );
  RestoreRunRow copyWithCompanion(RestoreRunsCompanion data) {
    return RestoreRunRow(
      id: data.id.present ? data.id.value : this.id,
      sourceName: data.sourceName.present
          ? data.sourceName.value
          : this.sourceName,
      sourceSha256: data.sourceSha256.present
          ? data.sourceSha256.value
          : this.sourceSha256,
      mode: data.mode.present ? data.mode.value : this.mode,
      sourceSchemaVersion: data.sourceSchemaVersion.present
          ? data.sourceSchemaVersion.value
          : this.sourceSchemaVersion,
      preRestoreBackupRunId: data.preRestoreBackupRunId.present
          ? data.preRestoreBackupRunId.value
          : this.preRestoreBackupRunId,
      status: data.status.present ? data.status.value : this.status,
      summaryJson: data.summaryJson.present
          ? data.summaryJson.value
          : this.summaryJson,
      startedAtUtc: data.startedAtUtc.present
          ? data.startedAtUtc.value
          : this.startedAtUtc,
      completedAtUtc: data.completedAtUtc.present
          ? data.completedAtUtc.value
          : this.completedAtUtc,
      errorCode: data.errorCode.present ? data.errorCode.value : this.errorCode,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestoreRunRow(')
          ..write('id: $id, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceSha256: $sourceSha256, ')
          ..write('mode: $mode, ')
          ..write('sourceSchemaVersion: $sourceSchemaVersion, ')
          ..write('preRestoreBackupRunId: $preRestoreBackupRunId, ')
          ..write('status: $status, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('completedAtUtc: $completedAtUtc, ')
          ..write('errorCode: $errorCode')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    sourceName,
    sourceSha256,
    mode,
    sourceSchemaVersion,
    preRestoreBackupRunId,
    status,
    summaryJson,
    startedAtUtc,
    completedAtUtc,
    errorCode,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestoreRunRow &&
          other.id == this.id &&
          other.sourceName == this.sourceName &&
          other.sourceSha256 == this.sourceSha256 &&
          other.mode == this.mode &&
          other.sourceSchemaVersion == this.sourceSchemaVersion &&
          other.preRestoreBackupRunId == this.preRestoreBackupRunId &&
          other.status == this.status &&
          other.summaryJson == this.summaryJson &&
          other.startedAtUtc == this.startedAtUtc &&
          other.completedAtUtc == this.completedAtUtc &&
          other.errorCode == this.errorCode);
}

class RestoreRunsCompanion extends UpdateCompanion<RestoreRunRow> {
  final Value<String> id;
  final Value<String> sourceName;
  final Value<String?> sourceSha256;
  final Value<String> mode;
  final Value<int?> sourceSchemaVersion;
  final Value<String?> preRestoreBackupRunId;
  final Value<String> status;
  final Value<String?> summaryJson;
  final Value<int> startedAtUtc;
  final Value<int?> completedAtUtc;
  final Value<String?> errorCode;
  final Value<int> rowid;
  const RestoreRunsCompanion({
    this.id = const Value.absent(),
    this.sourceName = const Value.absent(),
    this.sourceSha256 = const Value.absent(),
    this.mode = const Value.absent(),
    this.sourceSchemaVersion = const Value.absent(),
    this.preRestoreBackupRunId = const Value.absent(),
    this.status = const Value.absent(),
    this.summaryJson = const Value.absent(),
    this.startedAtUtc = const Value.absent(),
    this.completedAtUtc = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestoreRunsCompanion.insert({
    required String id,
    required String sourceName,
    this.sourceSha256 = const Value.absent(),
    required String mode,
    this.sourceSchemaVersion = const Value.absent(),
    this.preRestoreBackupRunId = const Value.absent(),
    required String status,
    this.summaryJson = const Value.absent(),
    required int startedAtUtc,
    this.completedAtUtc = const Value.absent(),
    this.errorCode = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       sourceName = Value(sourceName),
       mode = Value(mode),
       status = Value(status),
       startedAtUtc = Value(startedAtUtc);
  static Insertable<RestoreRunRow> custom({
    Expression<String>? id,
    Expression<String>? sourceName,
    Expression<String>? sourceSha256,
    Expression<String>? mode,
    Expression<int>? sourceSchemaVersion,
    Expression<String>? preRestoreBackupRunId,
    Expression<String>? status,
    Expression<String>? summaryJson,
    Expression<int>? startedAtUtc,
    Expression<int>? completedAtUtc,
    Expression<String>? errorCode,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (sourceName != null) 'source_name': sourceName,
      if (sourceSha256 != null) 'source_sha256': sourceSha256,
      if (mode != null) 'mode': mode,
      if (sourceSchemaVersion != null)
        'source_schema_version': sourceSchemaVersion,
      if (preRestoreBackupRunId != null)
        'pre_restore_backup_run_id': preRestoreBackupRunId,
      if (status != null) 'status': status,
      if (summaryJson != null) 'summary_json': summaryJson,
      if (startedAtUtc != null) 'started_at_utc': startedAtUtc,
      if (completedAtUtc != null) 'completed_at_utc': completedAtUtc,
      if (errorCode != null) 'error_code': errorCode,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestoreRunsCompanion copyWith({
    Value<String>? id,
    Value<String>? sourceName,
    Value<String?>? sourceSha256,
    Value<String>? mode,
    Value<int?>? sourceSchemaVersion,
    Value<String?>? preRestoreBackupRunId,
    Value<String>? status,
    Value<String?>? summaryJson,
    Value<int>? startedAtUtc,
    Value<int?>? completedAtUtc,
    Value<String?>? errorCode,
    Value<int>? rowid,
  }) {
    return RestoreRunsCompanion(
      id: id ?? this.id,
      sourceName: sourceName ?? this.sourceName,
      sourceSha256: sourceSha256 ?? this.sourceSha256,
      mode: mode ?? this.mode,
      sourceSchemaVersion: sourceSchemaVersion ?? this.sourceSchemaVersion,
      preRestoreBackupRunId:
          preRestoreBackupRunId ?? this.preRestoreBackupRunId,
      status: status ?? this.status,
      summaryJson: summaryJson ?? this.summaryJson,
      startedAtUtc: startedAtUtc ?? this.startedAtUtc,
      completedAtUtc: completedAtUtc ?? this.completedAtUtc,
      errorCode: errorCode ?? this.errorCode,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (sourceName.present) {
      map['source_name'] = Variable<String>(sourceName.value);
    }
    if (sourceSha256.present) {
      map['source_sha256'] = Variable<String>(sourceSha256.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (sourceSchemaVersion.present) {
      map['source_schema_version'] = Variable<int>(sourceSchemaVersion.value);
    }
    if (preRestoreBackupRunId.present) {
      map['pre_restore_backup_run_id'] = Variable<String>(
        preRestoreBackupRunId.value,
      );
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (summaryJson.present) {
      map['summary_json'] = Variable<String>(summaryJson.value);
    }
    if (startedAtUtc.present) {
      map['started_at_utc'] = Variable<int>(startedAtUtc.value);
    }
    if (completedAtUtc.present) {
      map['completed_at_utc'] = Variable<int>(completedAtUtc.value);
    }
    if (errorCode.present) {
      map['error_code'] = Variable<String>(errorCode.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestoreRunsCompanion(')
          ..write('id: $id, ')
          ..write('sourceName: $sourceName, ')
          ..write('sourceSha256: $sourceSha256, ')
          ..write('mode: $mode, ')
          ..write('sourceSchemaVersion: $sourceSchemaVersion, ')
          ..write('preRestoreBackupRunId: $preRestoreBackupRunId, ')
          ..write('status: $status, ')
          ..write('summaryJson: $summaryJson, ')
          ..write('startedAtUtc: $startedAtUtc, ')
          ..write('completedAtUtc: $completedAtUtc, ')
          ..write('errorCode: $errorCode, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RestoreConflictsTable extends RestoreConflicts
    with TableInfo<$RestoreConflictsTable, RestoreConflictRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RestoreConflictsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restoreRunIdMeta = const VerificationMeta(
    'restoreRunId',
  );
  @override
  late final GeneratedColumn<String> restoreRunId = GeneratedColumn<String>(
    'restore_run_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES restore_runs (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _incomingIdMeta = const VerificationMeta(
    'incomingId',
  );
  @override
  late final GeneratedColumn<String> incomingId = GeneratedColumn<String>(
    'incoming_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _resolvedLocalIdMeta = const VerificationMeta(
    'resolvedLocalId',
  );
  @override
  late final GeneratedColumn<String> resolvedLocalId = GeneratedColumn<String>(
    'resolved_local_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _incomingHashMeta = const VerificationMeta(
    'incomingHash',
  );
  @override
  late final GeneratedColumn<String> incomingHash = GeneratedColumn<String>(
    'incoming_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _currentHashMeta = const VerificationMeta(
    'currentHash',
  );
  @override
  late final GeneratedColumn<String> currentHash = GeneratedColumn<String>(
    'current_hash',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _resolutionMeta = const VerificationMeta(
    'resolution',
  );
  @override
  late final GeneratedColumn<String> resolution = GeneratedColumn<String>(
    'resolution',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    restoreRunId,
    entityType,
    incomingId,
    resolvedLocalId,
    incomingHash,
    currentHash,
    resolution,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'restore_conflicts';
  @override
  VerificationContext validateIntegrity(
    Insertable<RestoreConflictRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('restore_run_id')) {
      context.handle(
        _restoreRunIdMeta,
        restoreRunId.isAcceptableOrUnknown(
          data['restore_run_id']!,
          _restoreRunIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_restoreRunIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('incoming_id')) {
      context.handle(
        _incomingIdMeta,
        incomingId.isAcceptableOrUnknown(data['incoming_id']!, _incomingIdMeta),
      );
    } else if (isInserting) {
      context.missing(_incomingIdMeta);
    }
    if (data.containsKey('resolved_local_id')) {
      context.handle(
        _resolvedLocalIdMeta,
        resolvedLocalId.isAcceptableOrUnknown(
          data['resolved_local_id']!,
          _resolvedLocalIdMeta,
        ),
      );
    }
    if (data.containsKey('incoming_hash')) {
      context.handle(
        _incomingHashMeta,
        incomingHash.isAcceptableOrUnknown(
          data['incoming_hash']!,
          _incomingHashMeta,
        ),
      );
    }
    if (data.containsKey('current_hash')) {
      context.handle(
        _currentHashMeta,
        currentHash.isAcceptableOrUnknown(
          data['current_hash']!,
          _currentHashMeta,
        ),
      );
    }
    if (data.containsKey('resolution')) {
      context.handle(
        _resolutionMeta,
        resolution.isAcceptableOrUnknown(data['resolution']!, _resolutionMeta),
      );
    } else if (isInserting) {
      context.missing(_resolutionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RestoreConflictRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RestoreConflictRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      restoreRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restore_run_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      incomingId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incoming_id'],
      )!,
      resolvedLocalId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolved_local_id'],
      ),
      incomingHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}incoming_hash'],
      ),
      currentHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_hash'],
      ),
      resolution: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolution'],
      )!,
    );
  }

  @override
  $RestoreConflictsTable createAlias(String alias) {
    return $RestoreConflictsTable(attachedDatabase, alias);
  }
}

class RestoreConflictRow extends DataClass
    implements Insertable<RestoreConflictRow> {
  final String id;
  final String restoreRunId;
  final String entityType;
  final String incomingId;
  final String? resolvedLocalId;
  final String? incomingHash;
  final String? currentHash;
  final String resolution;
  const RestoreConflictRow({
    required this.id,
    required this.restoreRunId,
    required this.entityType,
    required this.incomingId,
    this.resolvedLocalId,
    this.incomingHash,
    this.currentHash,
    required this.resolution,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['restore_run_id'] = Variable<String>(restoreRunId);
    map['entity_type'] = Variable<String>(entityType);
    map['incoming_id'] = Variable<String>(incomingId);
    if (!nullToAbsent || resolvedLocalId != null) {
      map['resolved_local_id'] = Variable<String>(resolvedLocalId);
    }
    if (!nullToAbsent || incomingHash != null) {
      map['incoming_hash'] = Variable<String>(incomingHash);
    }
    if (!nullToAbsent || currentHash != null) {
      map['current_hash'] = Variable<String>(currentHash);
    }
    map['resolution'] = Variable<String>(resolution);
    return map;
  }

  RestoreConflictsCompanion toCompanion(bool nullToAbsent) {
    return RestoreConflictsCompanion(
      id: Value(id),
      restoreRunId: Value(restoreRunId),
      entityType: Value(entityType),
      incomingId: Value(incomingId),
      resolvedLocalId: resolvedLocalId == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedLocalId),
      incomingHash: incomingHash == null && nullToAbsent
          ? const Value.absent()
          : Value(incomingHash),
      currentHash: currentHash == null && nullToAbsent
          ? const Value.absent()
          : Value(currentHash),
      resolution: Value(resolution),
    );
  }

  factory RestoreConflictRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RestoreConflictRow(
      id: serializer.fromJson<String>(json['id']),
      restoreRunId: serializer.fromJson<String>(json['restoreRunId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      incomingId: serializer.fromJson<String>(json['incomingId']),
      resolvedLocalId: serializer.fromJson<String?>(json['resolvedLocalId']),
      incomingHash: serializer.fromJson<String?>(json['incomingHash']),
      currentHash: serializer.fromJson<String?>(json['currentHash']),
      resolution: serializer.fromJson<String>(json['resolution']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'restoreRunId': serializer.toJson<String>(restoreRunId),
      'entityType': serializer.toJson<String>(entityType),
      'incomingId': serializer.toJson<String>(incomingId),
      'resolvedLocalId': serializer.toJson<String?>(resolvedLocalId),
      'incomingHash': serializer.toJson<String?>(incomingHash),
      'currentHash': serializer.toJson<String?>(currentHash),
      'resolution': serializer.toJson<String>(resolution),
    };
  }

  RestoreConflictRow copyWith({
    String? id,
    String? restoreRunId,
    String? entityType,
    String? incomingId,
    Value<String?> resolvedLocalId = const Value.absent(),
    Value<String?> incomingHash = const Value.absent(),
    Value<String?> currentHash = const Value.absent(),
    String? resolution,
  }) => RestoreConflictRow(
    id: id ?? this.id,
    restoreRunId: restoreRunId ?? this.restoreRunId,
    entityType: entityType ?? this.entityType,
    incomingId: incomingId ?? this.incomingId,
    resolvedLocalId: resolvedLocalId.present
        ? resolvedLocalId.value
        : this.resolvedLocalId,
    incomingHash: incomingHash.present ? incomingHash.value : this.incomingHash,
    currentHash: currentHash.present ? currentHash.value : this.currentHash,
    resolution: resolution ?? this.resolution,
  );
  RestoreConflictRow copyWithCompanion(RestoreConflictsCompanion data) {
    return RestoreConflictRow(
      id: data.id.present ? data.id.value : this.id,
      restoreRunId: data.restoreRunId.present
          ? data.restoreRunId.value
          : this.restoreRunId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      incomingId: data.incomingId.present
          ? data.incomingId.value
          : this.incomingId,
      resolvedLocalId: data.resolvedLocalId.present
          ? data.resolvedLocalId.value
          : this.resolvedLocalId,
      incomingHash: data.incomingHash.present
          ? data.incomingHash.value
          : this.incomingHash,
      currentHash: data.currentHash.present
          ? data.currentHash.value
          : this.currentHash,
      resolution: data.resolution.present
          ? data.resolution.value
          : this.resolution,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RestoreConflictRow(')
          ..write('id: $id, ')
          ..write('restoreRunId: $restoreRunId, ')
          ..write('entityType: $entityType, ')
          ..write('incomingId: $incomingId, ')
          ..write('resolvedLocalId: $resolvedLocalId, ')
          ..write('incomingHash: $incomingHash, ')
          ..write('currentHash: $currentHash, ')
          ..write('resolution: $resolution')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    restoreRunId,
    entityType,
    incomingId,
    resolvedLocalId,
    incomingHash,
    currentHash,
    resolution,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RestoreConflictRow &&
          other.id == this.id &&
          other.restoreRunId == this.restoreRunId &&
          other.entityType == this.entityType &&
          other.incomingId == this.incomingId &&
          other.resolvedLocalId == this.resolvedLocalId &&
          other.incomingHash == this.incomingHash &&
          other.currentHash == this.currentHash &&
          other.resolution == this.resolution);
}

class RestoreConflictsCompanion extends UpdateCompanion<RestoreConflictRow> {
  final Value<String> id;
  final Value<String> restoreRunId;
  final Value<String> entityType;
  final Value<String> incomingId;
  final Value<String?> resolvedLocalId;
  final Value<String?> incomingHash;
  final Value<String?> currentHash;
  final Value<String> resolution;
  final Value<int> rowid;
  const RestoreConflictsCompanion({
    this.id = const Value.absent(),
    this.restoreRunId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.incomingId = const Value.absent(),
    this.resolvedLocalId = const Value.absent(),
    this.incomingHash = const Value.absent(),
    this.currentHash = const Value.absent(),
    this.resolution = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RestoreConflictsCompanion.insert({
    required String id,
    required String restoreRunId,
    required String entityType,
    required String incomingId,
    this.resolvedLocalId = const Value.absent(),
    this.incomingHash = const Value.absent(),
    this.currentHash = const Value.absent(),
    required String resolution,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       restoreRunId = Value(restoreRunId),
       entityType = Value(entityType),
       incomingId = Value(incomingId),
       resolution = Value(resolution);
  static Insertable<RestoreConflictRow> custom({
    Expression<String>? id,
    Expression<String>? restoreRunId,
    Expression<String>? entityType,
    Expression<String>? incomingId,
    Expression<String>? resolvedLocalId,
    Expression<String>? incomingHash,
    Expression<String>? currentHash,
    Expression<String>? resolution,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (restoreRunId != null) 'restore_run_id': restoreRunId,
      if (entityType != null) 'entity_type': entityType,
      if (incomingId != null) 'incoming_id': incomingId,
      if (resolvedLocalId != null) 'resolved_local_id': resolvedLocalId,
      if (incomingHash != null) 'incoming_hash': incomingHash,
      if (currentHash != null) 'current_hash': currentHash,
      if (resolution != null) 'resolution': resolution,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RestoreConflictsCompanion copyWith({
    Value<String>? id,
    Value<String>? restoreRunId,
    Value<String>? entityType,
    Value<String>? incomingId,
    Value<String?>? resolvedLocalId,
    Value<String?>? incomingHash,
    Value<String?>? currentHash,
    Value<String>? resolution,
    Value<int>? rowid,
  }) {
    return RestoreConflictsCompanion(
      id: id ?? this.id,
      restoreRunId: restoreRunId ?? this.restoreRunId,
      entityType: entityType ?? this.entityType,
      incomingId: incomingId ?? this.incomingId,
      resolvedLocalId: resolvedLocalId ?? this.resolvedLocalId,
      incomingHash: incomingHash ?? this.incomingHash,
      currentHash: currentHash ?? this.currentHash,
      resolution: resolution ?? this.resolution,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (restoreRunId.present) {
      map['restore_run_id'] = Variable<String>(restoreRunId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (incomingId.present) {
      map['incoming_id'] = Variable<String>(incomingId.value);
    }
    if (resolvedLocalId.present) {
      map['resolved_local_id'] = Variable<String>(resolvedLocalId.value);
    }
    if (incomingHash.present) {
      map['incoming_hash'] = Variable<String>(incomingHash.value);
    }
    if (currentHash.present) {
      map['current_hash'] = Variable<String>(currentHash.value);
    }
    if (resolution.present) {
      map['resolution'] = Variable<String>(resolution.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RestoreConflictsCompanion(')
          ..write('id: $id, ')
          ..write('restoreRunId: $restoreRunId, ')
          ..write('entityType: $entityType, ')
          ..write('incomingId: $incomingId, ')
          ..write('resolvedLocalId: $resolvedLocalId, ')
          ..write('incomingHash: $incomingHash, ')
          ..write('currentHash: $currentHash, ')
          ..write('resolution: $resolution, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ImportProvenanceTable extends ImportProvenance
    with TableInfo<$ImportProvenanceTable, ImportProvenanceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ImportProvenanceTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _originDatasetIdMeta = const VerificationMeta(
    'originDatasetId',
  );
  @override
  late final GeneratedColumn<String> originDatasetId = GeneratedColumn<String>(
    'origin_dataset_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originEntityIdMeta = const VerificationMeta(
    'originEntityId',
  );
  @override
  late final GeneratedColumn<String> originEntityId = GeneratedColumn<String>(
    'origin_entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _originHashMeta = const VerificationMeta(
    'originHash',
  );
  @override
  late final GeneratedColumn<String> originHash = GeneratedColumn<String>(
    'origin_hash',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _localEntityIdMeta = const VerificationMeta(
    'localEntityId',
  );
  @override
  late final GeneratedColumn<String> localEntityId = GeneratedColumn<String>(
    'local_entity_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _restoreRunIdMeta = const VerificationMeta(
    'restoreRunId',
  );
  @override
  late final GeneratedColumn<String> restoreRunId = GeneratedColumn<String>(
    'restore_run_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES restore_runs (id) ON DELETE SET NULL',
    ),
  );
  static const VerificationMeta _createdAtUtcMeta = const VerificationMeta(
    'createdAtUtc',
  );
  @override
  late final GeneratedColumn<int> createdAtUtc = GeneratedColumn<int>(
    'created_at_utc',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    originDatasetId,
    entityType,
    originEntityId,
    originHash,
    localEntityId,
    restoreRunId,
    createdAtUtc,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'import_provenance';
  @override
  VerificationContext validateIntegrity(
    Insertable<ImportProvenanceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('origin_dataset_id')) {
      context.handle(
        _originDatasetIdMeta,
        originDatasetId.isAcceptableOrUnknown(
          data['origin_dataset_id']!,
          _originDatasetIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originDatasetIdMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('origin_entity_id')) {
      context.handle(
        _originEntityIdMeta,
        originEntityId.isAcceptableOrUnknown(
          data['origin_entity_id']!,
          _originEntityIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_originEntityIdMeta);
    }
    if (data.containsKey('origin_hash')) {
      context.handle(
        _originHashMeta,
        originHash.isAcceptableOrUnknown(data['origin_hash']!, _originHashMeta),
      );
    } else if (isInserting) {
      context.missing(_originHashMeta);
    }
    if (data.containsKey('local_entity_id')) {
      context.handle(
        _localEntityIdMeta,
        localEntityId.isAcceptableOrUnknown(
          data['local_entity_id']!,
          _localEntityIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localEntityIdMeta);
    }
    if (data.containsKey('restore_run_id')) {
      context.handle(
        _restoreRunIdMeta,
        restoreRunId.isAcceptableOrUnknown(
          data['restore_run_id']!,
          _restoreRunIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at_utc')) {
      context.handle(
        _createdAtUtcMeta,
        createdAtUtc.isAcceptableOrUnknown(
          data['created_at_utc']!,
          _createdAtUtcMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdAtUtcMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {
    originDatasetId,
    entityType,
    originEntityId,
    originHash,
  };
  @override
  ImportProvenanceRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ImportProvenanceRow(
      originDatasetId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_dataset_id'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      originEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_entity_id'],
      )!,
      originHash: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}origin_hash'],
      )!,
      localEntityId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_entity_id'],
      )!,
      restoreRunId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}restore_run_id'],
      ),
      createdAtUtc: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at_utc'],
      )!,
    );
  }

  @override
  $ImportProvenanceTable createAlias(String alias) {
    return $ImportProvenanceTable(attachedDatabase, alias);
  }
}

class ImportProvenanceRow extends DataClass
    implements Insertable<ImportProvenanceRow> {
  final String originDatasetId;
  final String entityType;
  final String originEntityId;
  final String originHash;
  final String localEntityId;
  final String? restoreRunId;
  final int createdAtUtc;
  const ImportProvenanceRow({
    required this.originDatasetId,
    required this.entityType,
    required this.originEntityId,
    required this.originHash,
    required this.localEntityId,
    this.restoreRunId,
    required this.createdAtUtc,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['origin_dataset_id'] = Variable<String>(originDatasetId);
    map['entity_type'] = Variable<String>(entityType);
    map['origin_entity_id'] = Variable<String>(originEntityId);
    map['origin_hash'] = Variable<String>(originHash);
    map['local_entity_id'] = Variable<String>(localEntityId);
    if (!nullToAbsent || restoreRunId != null) {
      map['restore_run_id'] = Variable<String>(restoreRunId);
    }
    map['created_at_utc'] = Variable<int>(createdAtUtc);
    return map;
  }

  ImportProvenanceCompanion toCompanion(bool nullToAbsent) {
    return ImportProvenanceCompanion(
      originDatasetId: Value(originDatasetId),
      entityType: Value(entityType),
      originEntityId: Value(originEntityId),
      originHash: Value(originHash),
      localEntityId: Value(localEntityId),
      restoreRunId: restoreRunId == null && nullToAbsent
          ? const Value.absent()
          : Value(restoreRunId),
      createdAtUtc: Value(createdAtUtc),
    );
  }

  factory ImportProvenanceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ImportProvenanceRow(
      originDatasetId: serializer.fromJson<String>(json['originDatasetId']),
      entityType: serializer.fromJson<String>(json['entityType']),
      originEntityId: serializer.fromJson<String>(json['originEntityId']),
      originHash: serializer.fromJson<String>(json['originHash']),
      localEntityId: serializer.fromJson<String>(json['localEntityId']),
      restoreRunId: serializer.fromJson<String?>(json['restoreRunId']),
      createdAtUtc: serializer.fromJson<int>(json['createdAtUtc']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'originDatasetId': serializer.toJson<String>(originDatasetId),
      'entityType': serializer.toJson<String>(entityType),
      'originEntityId': serializer.toJson<String>(originEntityId),
      'originHash': serializer.toJson<String>(originHash),
      'localEntityId': serializer.toJson<String>(localEntityId),
      'restoreRunId': serializer.toJson<String?>(restoreRunId),
      'createdAtUtc': serializer.toJson<int>(createdAtUtc),
    };
  }

  ImportProvenanceRow copyWith({
    String? originDatasetId,
    String? entityType,
    String? originEntityId,
    String? originHash,
    String? localEntityId,
    Value<String?> restoreRunId = const Value.absent(),
    int? createdAtUtc,
  }) => ImportProvenanceRow(
    originDatasetId: originDatasetId ?? this.originDatasetId,
    entityType: entityType ?? this.entityType,
    originEntityId: originEntityId ?? this.originEntityId,
    originHash: originHash ?? this.originHash,
    localEntityId: localEntityId ?? this.localEntityId,
    restoreRunId: restoreRunId.present ? restoreRunId.value : this.restoreRunId,
    createdAtUtc: createdAtUtc ?? this.createdAtUtc,
  );
  ImportProvenanceRow copyWithCompanion(ImportProvenanceCompanion data) {
    return ImportProvenanceRow(
      originDatasetId: data.originDatasetId.present
          ? data.originDatasetId.value
          : this.originDatasetId,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      originEntityId: data.originEntityId.present
          ? data.originEntityId.value
          : this.originEntityId,
      originHash: data.originHash.present
          ? data.originHash.value
          : this.originHash,
      localEntityId: data.localEntityId.present
          ? data.localEntityId.value
          : this.localEntityId,
      restoreRunId: data.restoreRunId.present
          ? data.restoreRunId.value
          : this.restoreRunId,
      createdAtUtc: data.createdAtUtc.present
          ? data.createdAtUtc.value
          : this.createdAtUtc,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ImportProvenanceRow(')
          ..write('originDatasetId: $originDatasetId, ')
          ..write('entityType: $entityType, ')
          ..write('originEntityId: $originEntityId, ')
          ..write('originHash: $originHash, ')
          ..write('localEntityId: $localEntityId, ')
          ..write('restoreRunId: $restoreRunId, ')
          ..write('createdAtUtc: $createdAtUtc')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    originDatasetId,
    entityType,
    originEntityId,
    originHash,
    localEntityId,
    restoreRunId,
    createdAtUtc,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ImportProvenanceRow &&
          other.originDatasetId == this.originDatasetId &&
          other.entityType == this.entityType &&
          other.originEntityId == this.originEntityId &&
          other.originHash == this.originHash &&
          other.localEntityId == this.localEntityId &&
          other.restoreRunId == this.restoreRunId &&
          other.createdAtUtc == this.createdAtUtc);
}

class ImportProvenanceCompanion extends UpdateCompanion<ImportProvenanceRow> {
  final Value<String> originDatasetId;
  final Value<String> entityType;
  final Value<String> originEntityId;
  final Value<String> originHash;
  final Value<String> localEntityId;
  final Value<String?> restoreRunId;
  final Value<int> createdAtUtc;
  final Value<int> rowid;
  const ImportProvenanceCompanion({
    this.originDatasetId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.originEntityId = const Value.absent(),
    this.originHash = const Value.absent(),
    this.localEntityId = const Value.absent(),
    this.restoreRunId = const Value.absent(),
    this.createdAtUtc = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ImportProvenanceCompanion.insert({
    required String originDatasetId,
    required String entityType,
    required String originEntityId,
    required String originHash,
    required String localEntityId,
    this.restoreRunId = const Value.absent(),
    required int createdAtUtc,
    this.rowid = const Value.absent(),
  }) : originDatasetId = Value(originDatasetId),
       entityType = Value(entityType),
       originEntityId = Value(originEntityId),
       originHash = Value(originHash),
       localEntityId = Value(localEntityId),
       createdAtUtc = Value(createdAtUtc);
  static Insertable<ImportProvenanceRow> custom({
    Expression<String>? originDatasetId,
    Expression<String>? entityType,
    Expression<String>? originEntityId,
    Expression<String>? originHash,
    Expression<String>? localEntityId,
    Expression<String>? restoreRunId,
    Expression<int>? createdAtUtc,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (originDatasetId != null) 'origin_dataset_id': originDatasetId,
      if (entityType != null) 'entity_type': entityType,
      if (originEntityId != null) 'origin_entity_id': originEntityId,
      if (originHash != null) 'origin_hash': originHash,
      if (localEntityId != null) 'local_entity_id': localEntityId,
      if (restoreRunId != null) 'restore_run_id': restoreRunId,
      if (createdAtUtc != null) 'created_at_utc': createdAtUtc,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ImportProvenanceCompanion copyWith({
    Value<String>? originDatasetId,
    Value<String>? entityType,
    Value<String>? originEntityId,
    Value<String>? originHash,
    Value<String>? localEntityId,
    Value<String?>? restoreRunId,
    Value<int>? createdAtUtc,
    Value<int>? rowid,
  }) {
    return ImportProvenanceCompanion(
      originDatasetId: originDatasetId ?? this.originDatasetId,
      entityType: entityType ?? this.entityType,
      originEntityId: originEntityId ?? this.originEntityId,
      originHash: originHash ?? this.originHash,
      localEntityId: localEntityId ?? this.localEntityId,
      restoreRunId: restoreRunId ?? this.restoreRunId,
      createdAtUtc: createdAtUtc ?? this.createdAtUtc,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (originDatasetId.present) {
      map['origin_dataset_id'] = Variable<String>(originDatasetId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (originEntityId.present) {
      map['origin_entity_id'] = Variable<String>(originEntityId.value);
    }
    if (originHash.present) {
      map['origin_hash'] = Variable<String>(originHash.value);
    }
    if (localEntityId.present) {
      map['local_entity_id'] = Variable<String>(localEntityId.value);
    }
    if (restoreRunId.present) {
      map['restore_run_id'] = Variable<String>(restoreRunId.value);
    }
    if (createdAtUtc.present) {
      map['created_at_utc'] = Variable<int>(createdAtUtc.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ImportProvenanceCompanion(')
          ..write('originDatasetId: $originDatasetId, ')
          ..write('entityType: $entityType, ')
          ..write('originEntityId: $originEntityId, ')
          ..write('originHash: $originHash, ')
          ..write('localEntityId: $localEntityId, ')
          ..write('restoreRunId: $restoreRunId, ')
          ..write('createdAtUtc: $createdAtUtc, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$DangguiDatabase extends GeneratedDatabase {
  _$DangguiDatabase(QueryExecutor e) : super(e);
  $DangguiDatabaseManager get managers => $DangguiDatabaseManager(this);
  late final $AppMetadataTable appMetadata = $AppMetadataTable(this);
  late final $AppSettingsTableTable appSettingsTable = $AppSettingsTableTable(
    this,
  );
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $DocumentBlocksTable documentBlocks = $DocumentBlocksTable(this);
  late final $DocumentRevisionsTable documentRevisions =
      $DocumentRevisionsTable(this);
  late final $TasksTable tasks = $TasksTable(this);
  late final $RemindersTable reminders = $RemindersTable(this);
  late final $NotificationRegistrationsTable notificationRegistrations =
      $NotificationRegistrationsTable(this);
  late final $PlatformJobsTable platformJobs = $PlatformJobsTable(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $NotesTable notes = $NotesTable(this);
  late final $TrashEntriesTable trashEntries = $TrashEntriesTable(this);
  late final $PastEventsTable pastEvents = $PastEventsTable(this);
  late final $PastEventPartsTable pastEventParts = $PastEventPartsTable(this);
  late final $PastAnchorLinksTable pastAnchorLinks = $PastAnchorLinksTable(
    this,
  );
  late final $SearchRecordsTable searchRecords = $SearchRecordsTable(this);
  late final $BackupTargetsTable backupTargets = $BackupTargetsTable(this);
  late final $BackupEncryptionProfilesTable backupEncryptionProfiles =
      $BackupEncryptionProfilesTable(this);
  late final $BackupRunsTable backupRuns = $BackupRunsTable(this);
  late final $RestoreRunsTable restoreRuns = $RestoreRunsTable(this);
  late final $RestoreConflictsTable restoreConflicts = $RestoreConflictsTable(
    this,
  );
  late final $ImportProvenanceTable importProvenance = $ImportProvenanceTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    appMetadata,
    appSettingsTable,
    documents,
    documentBlocks,
    documentRevisions,
    tasks,
    reminders,
    notificationRegistrations,
    platformJobs,
    folders,
    notes,
    trashEntries,
    pastEvents,
    pastEventParts,
    pastAnchorLinks,
    searchRecords,
    backupTargets,
    backupEncryptionProfiles,
    backupRuns,
    restoreRuns,
    restoreConflicts,
    importProvenance,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('document_blocks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'document_blocks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('document_blocks', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'documents',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('document_revisions', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'tasks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('reminders', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'reminders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [
        TableUpdate('notification_registrations', kind: UpdateKind.delete),
      ],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'folders',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('notes', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'past_events',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('past_event_parts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'past_event_parts',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('past_anchor_links', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'document_blocks',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('past_anchor_links', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'backup_targets',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('backup_runs', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'backup_encryption_profiles',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('backup_runs', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'backup_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('restore_runs', kind: UpdateKind.update)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'restore_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('restore_conflicts', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'restore_runs',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('import_provenance', kind: UpdateKind.update)],
    ),
  ]);
}

typedef $$AppMetadataTableCreateCompanionBuilder =
    AppMetadataCompanion Function({
      Value<int> id,
      required String datasetId,
      required int createdAtUtc,
      Value<int?> lastIntegrityCheckAtUtc,
      Value<String> ftsMode,
    });
typedef $$AppMetadataTableUpdateCompanionBuilder =
    AppMetadataCompanion Function({
      Value<int> id,
      Value<String> datasetId,
      Value<int> createdAtUtc,
      Value<int?> lastIntegrityCheckAtUtc,
      Value<String> ftsMode,
    });

class $$AppMetadataTableFilterComposer
    extends Composer<_$DangguiDatabase, $AppMetadataTable> {
  $$AppMetadataTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datasetId => $composableBuilder(
    column: $table.datasetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastIntegrityCheckAtUtc => $composableBuilder(
    column: $table.lastIntegrityCheckAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get ftsMode => $composableBuilder(
    column: $table.ftsMode,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppMetadataTableOrderingComposer
    extends Composer<_$DangguiDatabase, $AppMetadataTable> {
  $$AppMetadataTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datasetId => $composableBuilder(
    column: $table.datasetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastIntegrityCheckAtUtc => $composableBuilder(
    column: $table.lastIntegrityCheckAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get ftsMode => $composableBuilder(
    column: $table.ftsMode,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppMetadataTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $AppMetadataTable> {
  $$AppMetadataTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get datasetId =>
      $composableBuilder(column: $table.datasetId, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastIntegrityCheckAtUtc => $composableBuilder(
    column: $table.lastIntegrityCheckAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get ftsMode =>
      $composableBuilder(column: $table.ftsMode, builder: (column) => column);
}

class $$AppMetadataTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $AppMetadataTable,
          AppMetaRow,
          $$AppMetadataTableFilterComposer,
          $$AppMetadataTableOrderingComposer,
          $$AppMetadataTableAnnotationComposer,
          $$AppMetadataTableCreateCompanionBuilder,
          $$AppMetadataTableUpdateCompanionBuilder,
          (
            AppMetaRow,
            BaseReferences<_$DangguiDatabase, $AppMetadataTable, AppMetaRow>,
          ),
          AppMetaRow,
          PrefetchHooks Function()
        > {
  $$AppMetadataTableTableManager(_$DangguiDatabase db, $AppMetadataTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppMetadataTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppMetadataTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppMetadataTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> datasetId = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> lastIntegrityCheckAtUtc = const Value.absent(),
                Value<String> ftsMode = const Value.absent(),
              }) => AppMetadataCompanion(
                id: id,
                datasetId: datasetId,
                createdAtUtc: createdAtUtc,
                lastIntegrityCheckAtUtc: lastIntegrityCheckAtUtc,
                ftsMode: ftsMode,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String datasetId,
                required int createdAtUtc,
                Value<int?> lastIntegrityCheckAtUtc = const Value.absent(),
                Value<String> ftsMode = const Value.absent(),
              }) => AppMetadataCompanion.insert(
                id: id,
                datasetId: datasetId,
                createdAtUtc: createdAtUtc,
                lastIntegrityCheckAtUtc: lastIntegrityCheckAtUtc,
                ftsMode: ftsMode,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppMetadataTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $AppMetadataTable,
      AppMetaRow,
      $$AppMetadataTableFilterComposer,
      $$AppMetadataTableOrderingComposer,
      $$AppMetadataTableAnnotationComposer,
      $$AppMetadataTableCreateCompanionBuilder,
      $$AppMetadataTableUpdateCompanionBuilder,
      (
        AppMetaRow,
        BaseReferences<_$DangguiDatabase, $AppMetadataTable, AppMetaRow>,
      ),
      AppMetaRow,
      PrefetchHooks Function()
    >;
typedef $$AppSettingsTableTableCreateCompanionBuilder =
    AppSettingsTableCompanion Function({
      Value<int> id,
      required LocaleMode localeMode,
      required FontMode fontMode,
      required int textScalePercent,
      required DisplayDensity density,
      required bool defaultSoundEnabled,
      required bool defaultVibrationEnabled,
      required int defaultSnoozeMinutes,
      required bool autoBackupEnabled,
      Value<int> autoBackupHourLocal,
      Value<int> autoBackupMinuteLocal,
      required bool backupEncryptionEnabled,
      required int helpSeenVersion,
      required int updatedAtUtc,
      required int rowVersion,
    });
typedef $$AppSettingsTableTableUpdateCompanionBuilder =
    AppSettingsTableCompanion Function({
      Value<int> id,
      Value<LocaleMode> localeMode,
      Value<FontMode> fontMode,
      Value<int> textScalePercent,
      Value<DisplayDensity> density,
      Value<bool> defaultSoundEnabled,
      Value<bool> defaultVibrationEnabled,
      Value<int> defaultSnoozeMinutes,
      Value<bool> autoBackupEnabled,
      Value<int> autoBackupHourLocal,
      Value<int> autoBackupMinuteLocal,
      Value<bool> backupEncryptionEnabled,
      Value<int> helpSeenVersion,
      Value<int> updatedAtUtc,
      Value<int> rowVersion,
    });

class $$AppSettingsTableTableFilterComposer
    extends Composer<_$DangguiDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<LocaleMode, LocaleMode, String>
  get localeMode => $composableBuilder(
    column: $table.localeMode,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<FontMode, FontMode, String> get fontMode =>
      $composableBuilder(
        column: $table.fontMode,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get textScalePercent => $composableBuilder(
    column: $table.textScalePercent,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DisplayDensity, DisplayDensity, String>
  get density => $composableBuilder(
    column: $table.density,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<bool> get defaultSoundEnabled => $composableBuilder(
    column: $table.defaultSoundEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get defaultVibrationEnabled => $composableBuilder(
    column: $table.defaultVibrationEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get defaultSnoozeMinutes => $composableBuilder(
    column: $table.defaultSnoozeMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get autoBackupEnabled => $composableBuilder(
    column: $table.autoBackupEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoBackupHourLocal => $composableBuilder(
    column: $table.autoBackupHourLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get autoBackupMinuteLocal => $composableBuilder(
    column: $table.autoBackupMinuteLocal,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get backupEncryptionEnabled => $composableBuilder(
    column: $table.backupEncryptionEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get helpSeenVersion => $composableBuilder(
    column: $table.helpSeenVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppSettingsTableTableOrderingComposer
    extends Composer<_$DangguiDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localeMode => $composableBuilder(
    column: $table.localeMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get fontMode => $composableBuilder(
    column: $table.fontMode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get textScalePercent => $composableBuilder(
    column: $table.textScalePercent,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get density => $composableBuilder(
    column: $table.density,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get defaultSoundEnabled => $composableBuilder(
    column: $table.defaultSoundEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get defaultVibrationEnabled => $composableBuilder(
    column: $table.defaultVibrationEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get defaultSnoozeMinutes => $composableBuilder(
    column: $table.defaultSnoozeMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get autoBackupEnabled => $composableBuilder(
    column: $table.autoBackupEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoBackupHourLocal => $composableBuilder(
    column: $table.autoBackupHourLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get autoBackupMinuteLocal => $composableBuilder(
    column: $table.autoBackupMinuteLocal,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get backupEncryptionEnabled => $composableBuilder(
    column: $table.backupEncryptionEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get helpSeenVersion => $composableBuilder(
    column: $table.helpSeenVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppSettingsTableTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $AppSettingsTableTable> {
  $$AppSettingsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<LocaleMode, String> get localeMode =>
      $composableBuilder(
        column: $table.localeMode,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<FontMode, String> get fontMode =>
      $composableBuilder(column: $table.fontMode, builder: (column) => column);

  GeneratedColumn<int> get textScalePercent => $composableBuilder(
    column: $table.textScalePercent,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<DisplayDensity, String> get density =>
      $composableBuilder(column: $table.density, builder: (column) => column);

  GeneratedColumn<bool> get defaultSoundEnabled => $composableBuilder(
    column: $table.defaultSoundEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get defaultVibrationEnabled => $composableBuilder(
    column: $table.defaultVibrationEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get defaultSnoozeMinutes => $composableBuilder(
    column: $table.defaultSnoozeMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get autoBackupEnabled => $composableBuilder(
    column: $table.autoBackupEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoBackupHourLocal => $composableBuilder(
    column: $table.autoBackupHourLocal,
    builder: (column) => column,
  );

  GeneratedColumn<int> get autoBackupMinuteLocal => $composableBuilder(
    column: $table.autoBackupMinuteLocal,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get backupEncryptionEnabled => $composableBuilder(
    column: $table.backupEncryptionEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get helpSeenVersion => $composableBuilder(
    column: $table.helpSeenVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );
}

class $$AppSettingsTableTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $AppSettingsTableTable,
          AppSettingsRow,
          $$AppSettingsTableTableFilterComposer,
          $$AppSettingsTableTableOrderingComposer,
          $$AppSettingsTableTableAnnotationComposer,
          $$AppSettingsTableTableCreateCompanionBuilder,
          $$AppSettingsTableTableUpdateCompanionBuilder,
          (
            AppSettingsRow,
            BaseReferences<
              _$DangguiDatabase,
              $AppSettingsTableTable,
              AppSettingsRow
            >,
          ),
          AppSettingsRow,
          PrefetchHooks Function()
        > {
  $$AppSettingsTableTableTableManager(
    _$DangguiDatabase db,
    $AppSettingsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppSettingsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppSettingsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppSettingsTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<LocaleMode> localeMode = const Value.absent(),
                Value<FontMode> fontMode = const Value.absent(),
                Value<int> textScalePercent = const Value.absent(),
                Value<DisplayDensity> density = const Value.absent(),
                Value<bool> defaultSoundEnabled = const Value.absent(),
                Value<bool> defaultVibrationEnabled = const Value.absent(),
                Value<int> defaultSnoozeMinutes = const Value.absent(),
                Value<bool> autoBackupEnabled = const Value.absent(),
                Value<int> autoBackupHourLocal = const Value.absent(),
                Value<int> autoBackupMinuteLocal = const Value.absent(),
                Value<bool> backupEncryptionEnabled = const Value.absent(),
                Value<int> helpSeenVersion = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
              }) => AppSettingsTableCompanion(
                id: id,
                localeMode: localeMode,
                fontMode: fontMode,
                textScalePercent: textScalePercent,
                density: density,
                defaultSoundEnabled: defaultSoundEnabled,
                defaultVibrationEnabled: defaultVibrationEnabled,
                defaultSnoozeMinutes: defaultSnoozeMinutes,
                autoBackupEnabled: autoBackupEnabled,
                autoBackupHourLocal: autoBackupHourLocal,
                autoBackupMinuteLocal: autoBackupMinuteLocal,
                backupEncryptionEnabled: backupEncryptionEnabled,
                helpSeenVersion: helpSeenVersion,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required LocaleMode localeMode,
                required FontMode fontMode,
                required int textScalePercent,
                required DisplayDensity density,
                required bool defaultSoundEnabled,
                required bool defaultVibrationEnabled,
                required int defaultSnoozeMinutes,
                required bool autoBackupEnabled,
                Value<int> autoBackupHourLocal = const Value.absent(),
                Value<int> autoBackupMinuteLocal = const Value.absent(),
                required bool backupEncryptionEnabled,
                required int helpSeenVersion,
                required int updatedAtUtc,
                required int rowVersion,
              }) => AppSettingsTableCompanion.insert(
                id: id,
                localeMode: localeMode,
                fontMode: fontMode,
                textScalePercent: textScalePercent,
                density: density,
                defaultSoundEnabled: defaultSoundEnabled,
                defaultVibrationEnabled: defaultVibrationEnabled,
                defaultSnoozeMinutes: defaultSnoozeMinutes,
                autoBackupEnabled: autoBackupEnabled,
                autoBackupHourLocal: autoBackupHourLocal,
                autoBackupMinuteLocal: autoBackupMinuteLocal,
                backupEncryptionEnabled: backupEncryptionEnabled,
                helpSeenVersion: helpSeenVersion,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppSettingsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $AppSettingsTableTable,
      AppSettingsRow,
      $$AppSettingsTableTableFilterComposer,
      $$AppSettingsTableTableOrderingComposer,
      $$AppSettingsTableTableAnnotationComposer,
      $$AppSettingsTableTableCreateCompanionBuilder,
      $$AppSettingsTableTableUpdateCompanionBuilder,
      (
        AppSettingsRow,
        BaseReferences<
          _$DangguiDatabase,
          $AppSettingsTableTable,
          AppSettingsRow
        >,
      ),
      AppSettingsRow,
      PrefetchHooks Function()
    >;
typedef $$DocumentsTableCreateCompanionBuilder = DocumentsCompanion Function({
  required String id,
  required DocumentKind kind,
  Value<String?> singletonKey,
  Value<int> formatVersion,
  Value<int> revision,
  required String semanticHash,
  required int createdAtUtc,
  required int updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});
typedef $$DocumentsTableUpdateCompanionBuilder = DocumentsCompanion Function({
  Value<String> id,
  Value<DocumentKind> kind,
  Value<String?> singletonKey,
  Value<int> formatVersion,
  Value<int> revision,
  Value<String> semanticHash,
  Value<int> createdAtUtc,
  Value<int> updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});

final class $$DocumentsTableReferences
    extends BaseReferences<_$DangguiDatabase, $DocumentsTable, DocumentRow> {
  $$DocumentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$DocumentBlocksTable, List<DocumentBlockRow>>
  _documentBlocksRefsTable(_$DangguiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.documentBlocks,
        aliasName: 'documents__id__document_blocks__document_id',
      );

  $$DocumentBlocksTableProcessedTableManager get documentBlocksRefs {
    final manager = $$DocumentBlocksTableTableManager(
      $_db,
      $_db.documentBlocks,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_documentBlocksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$DocumentRevisionsTable, List<DocumentRevisionRow>>
  _documentRevisionsRefsTable(_$DangguiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.documentRevisions,
        aliasName: 'documents__id__document_revisions__document_id',
      );

  $$DocumentRevisionsTableProcessedTableManager get documentRevisionsRefs {
    final manager = $$DocumentRevisionsTableTableManager(
      $_db,
      $_db.documentRevisions,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _documentRevisionsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TasksTable, List<TaskRow>> _tasksRefsTable(
    _$DangguiDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.tasks,
    aliasName: 'documents__id__tasks__document_id',
  );

  $$TasksTableProcessedTableManager get tasksRefs {
    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_tasksRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NotesTable, List<NoteRow>> _notesRefsTable(
    _$DangguiDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: 'documents__id__notes__document_id',
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$PastEventsTable, List<PastEventRow>>
  _pastEventsRefsTable(_$DangguiDatabase db) => MultiTypedResultKey.fromTable(
    db.pastEvents,
    aliasName: 'documents__id__past_events__document_id',
  );

  $$PastEventsTableProcessedTableManager get pastEventsRefs {
    final manager = $$PastEventsTableTableManager(
      $_db,
      $_db.pastEvents,
    ).filter((f) => f.documentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pastEventsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DocumentsTableFilterComposer
    extends Composer<_$DangguiDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DocumentKind, DocumentKind, String> get kind =>
      $composableBuilder(
        column: $table.kind,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get singletonKey => $composableBuilder(
    column: $table.singletonKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> documentBlocksRefs(
    Expression<bool> Function($$DocumentBlocksTableFilterComposer f) f,
  ) {
    final $$DocumentBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentBlocks,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentBlocksTableFilterComposer(
            $db: $db,
            $table: $db.documentBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> documentRevisionsRefs(
    Expression<bool> Function($$DocumentRevisionsTableFilterComposer f) f,
  ) {
    final $$DocumentRevisionsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentRevisions,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentRevisionsTableFilterComposer(
            $db: $db,
            $table: $db.documentRevisions,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> tasksRefs(
    Expression<bool> Function($$TasksTableFilterComposer f) f,
  ) {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> pastEventsRefs(
    Expression<bool> Function($$PastEventsTableFilterComposer f) f,
  ) {
    final $$PastEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pastEvents,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventsTableFilterComposer(
            $db: $db,
            $table: $db.pastEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get singletonKey => $composableBuilder(
    column: $table.singletonKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DocumentsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DocumentKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get singletonKey => $composableBuilder(
    column: $table.singletonKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get formatVersion => $composableBuilder(
    column: $table.formatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  Expression<T> documentBlocksRefs<T extends Object>(
    Expression<T> Function($$DocumentBlocksTableAnnotationComposer a) f,
  ) {
    final $$DocumentBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.documentBlocks,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.documentBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> documentRevisionsRefs<T extends Object>(
    Expression<T> Function($$DocumentRevisionsTableAnnotationComposer a) f,
  ) {
    final $$DocumentRevisionsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.documentRevisions,
          getReferencedColumn: (t) => t.documentId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$DocumentRevisionsTableAnnotationComposer(
                $db: $db,
                $table: $db.documentRevisions,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> tasksRefs<T extends Object>(
    Expression<T> Function($$TasksTableAnnotationComposer a) f,
  ) {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> pastEventsRefs<T extends Object>(
    Expression<T> Function($$PastEventsTableAnnotationComposer a) f,
  ) {
    final $$PastEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pastEvents,
      getReferencedColumn: (t) => t.documentId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.pastEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $DocumentsTable,
          DocumentRow,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (DocumentRow, $$DocumentsTableReferences),
          DocumentRow,
          PrefetchHooks Function({
            bool documentBlocksRefs,
            bool documentRevisionsRefs,
            bool tasksRefs,
            bool notesRefs,
            bool pastEventsRefs,
          })
        > {
  $$DocumentsTableTableManager(_$DangguiDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<DocumentKind> kind = const Value.absent(),
                Value<String?> singletonKey = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> semanticHash = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                id: id,
                kind: kind,
                singletonKey: singletonKey,
                formatVersion: formatVersion,
                revision: revision,
                semanticHash: semanticHash,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required DocumentKind kind,
                Value<String?> singletonKey = const Value.absent(),
                Value<int> formatVersion = const Value.absent(),
                Value<int> revision = const Value.absent(),
                required String semanticHash,
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                id: id,
                kind: kind,
                singletonKey: singletonKey,
                formatVersion: formatVersion,
                revision: revision,
                semanticHash: semanticHash,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                documentBlocksRefs = false,
                documentRevisionsRefs = false,
                tasksRefs = false,
                notesRefs = false,
                pastEventsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (documentBlocksRefs) db.documentBlocks,
                    if (documentRevisionsRefs) db.documentRevisions,
                    if (tasksRefs) db.tasks,
                    if (notesRefs) db.notes,
                    if (pastEventsRefs) db.pastEvents,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (documentBlocksRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          DocumentBlockRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._documentBlocksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentBlocksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (documentRevisionsRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          DocumentRevisionRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._documentRevisionsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).documentRevisionsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (tasksRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          TaskRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._tasksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).tasksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (notesRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          NoteRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._notesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).notesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (pastEventsRefs)
                        await $_getPrefetchedData<
                          DocumentRow,
                          $DocumentsTable,
                          PastEventRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentsTableReferences
                              ._pastEventsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentsTableReferences(
                                db,
                                table,
                                p0,
                              ).pastEventsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.documentId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $DocumentsTable,
      DocumentRow,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (DocumentRow, $$DocumentsTableReferences),
      DocumentRow,
      PrefetchHooks Function({
        bool documentBlocksRefs,
        bool documentRevisionsRefs,
        bool tasksRefs,
        bool notesRefs,
        bool pastEventsRefs,
      })
    >;
typedef $$DocumentBlocksTableCreateCompanionBuilder =
    DocumentBlocksCompanion Function({
      required String id,
      required String documentId,
      Value<String?> parentBlockId,
      required int sortRank,
      required DocumentBlockType blockType,
      Value<String> plainText,
      Value<String> payloadJson,
      Value<String> attributesJson,
      Value<bool?> isChecked,
      required String semanticHash,
      required int createdAtUtc,
      required int updatedAtUtc,
      Value<int> rowVersion,
      Value<int> rowid,
    });
typedef $$DocumentBlocksTableUpdateCompanionBuilder =
    DocumentBlocksCompanion Function({
      Value<String> id,
      Value<String> documentId,
      Value<String?> parentBlockId,
      Value<int> sortRank,
      Value<DocumentBlockType> blockType,
      Value<String> plainText,
      Value<String> payloadJson,
      Value<String> attributesJson,
      Value<bool?> isChecked,
      Value<String> semanticHash,
      Value<int> createdAtUtc,
      Value<int> updatedAtUtc,
      Value<int> rowVersion,
      Value<int> rowid,
    });

final class $$DocumentBlocksTableReferences
    extends
        BaseReferences<
          _$DangguiDatabase,
          $DocumentBlocksTable,
          DocumentBlockRow
        > {
  $$DocumentBlocksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$DangguiDatabase db) =>
      db.documents.createAlias('document_blocks__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DocumentBlocksTable _parentBlockIdTable(_$DangguiDatabase db) => db
      .documentBlocks
      .createAlias('document_blocks__parent_block_id__document_blocks__id');

  $$DocumentBlocksTableProcessedTableManager? get parentBlockId {
    final $_column = $_itemColumn<String>('parent_block_id');
    if ($_column == null) return null;
    final manager = $$DocumentBlocksTableTableManager(
      $_db,
      $_db.documentBlocks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentBlockIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PastAnchorLinksTable, List<PastAnchorLinkRow>>
  _pastAnchorLinksRefsTable(_$DangguiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pastAnchorLinks,
        aliasName: 'document_blocks__id__past_anchor_links__current_block_id',
      );

  $$PastAnchorLinksTableProcessedTableManager get pastAnchorLinksRefs {
    final manager = $$PastAnchorLinksTableTableManager(
      $_db,
      $_db.pastAnchorLinks,
    ).filter((f) => f.currentBlockId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _pastAnchorLinksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$DocumentBlocksTableFilterComposer
    extends Composer<_$DangguiDatabase, $DocumentBlocksTable> {
  $$DocumentBlocksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortRank => $composableBuilder(
    column: $table.sortRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<DocumentBlockType, DocumentBlockType, String>
  get blockType => $composableBuilder(
    column: $table.blockType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get attributesJson => $composableBuilder(
    column: $table.attributesJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isChecked => $composableBuilder(
    column: $table.isChecked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DocumentBlocksTableFilterComposer get parentBlockId {
    final $$DocumentBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentBlockId,
      referencedTable: $db.documentBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentBlocksTableFilterComposer(
            $db: $db,
            $table: $db.documentBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> pastAnchorLinksRefs(
    Expression<bool> Function($$PastAnchorLinksTableFilterComposer f) f,
  ) {
    final $$PastAnchorLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pastAnchorLinks,
      getReferencedColumn: (t) => t.currentBlockId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastAnchorLinksTableFilterComposer(
            $db: $db,
            $table: $db.pastAnchorLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentBlocksTableOrderingComposer
    extends Composer<_$DangguiDatabase, $DocumentBlocksTable> {
  $$DocumentBlocksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortRank => $composableBuilder(
    column: $table.sortRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get blockType => $composableBuilder(
    column: $table.blockType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get plainText => $composableBuilder(
    column: $table.plainText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get attributesJson => $composableBuilder(
    column: $table.attributesJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isChecked => $composableBuilder(
    column: $table.isChecked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DocumentBlocksTableOrderingComposer get parentBlockId {
    final $$DocumentBlocksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentBlockId,
      referencedTable: $db.documentBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentBlocksTableOrderingComposer(
            $db: $db,
            $table: $db.documentBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentBlocksTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $DocumentBlocksTable> {
  $$DocumentBlocksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get sortRank =>
      $composableBuilder(column: $table.sortRank, builder: (column) => column);

  GeneratedColumnWithTypeConverter<DocumentBlockType, String> get blockType =>
      $composableBuilder(column: $table.blockType, builder: (column) => column);

  GeneratedColumn<String> get plainText =>
      $composableBuilder(column: $table.plainText, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get attributesJson => $composableBuilder(
    column: $table.attributesJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isChecked =>
      $composableBuilder(column: $table.isChecked, builder: (column) => column);

  GeneratedColumn<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DocumentBlocksTableAnnotationComposer get parentBlockId {
    final $$DocumentBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentBlockId,
      referencedTable: $db.documentBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.documentBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> pastAnchorLinksRefs<T extends Object>(
    Expression<T> Function($$PastAnchorLinksTableAnnotationComposer a) f,
  ) {
    final $$PastAnchorLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pastAnchorLinks,
      getReferencedColumn: (t) => t.currentBlockId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastAnchorLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.pastAnchorLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$DocumentBlocksTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $DocumentBlocksTable,
          DocumentBlockRow,
          $$DocumentBlocksTableFilterComposer,
          $$DocumentBlocksTableOrderingComposer,
          $$DocumentBlocksTableAnnotationComposer,
          $$DocumentBlocksTableCreateCompanionBuilder,
          $$DocumentBlocksTableUpdateCompanionBuilder,
          (DocumentBlockRow, $$DocumentBlocksTableReferences),
          DocumentBlockRow,
          PrefetchHooks Function({
            bool documentId,
            bool parentBlockId,
            bool pastAnchorLinksRefs,
          })
        > {
  $$DocumentBlocksTableTableManager(
    _$DangguiDatabase db,
    $DocumentBlocksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentBlocksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentBlocksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentBlocksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String?> parentBlockId = const Value.absent(),
                Value<int> sortRank = const Value.absent(),
                Value<DocumentBlockType> blockType = const Value.absent(),
                Value<String> plainText = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> attributesJson = const Value.absent(),
                Value<bool?> isChecked = const Value.absent(),
                Value<String> semanticHash = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentBlocksCompanion(
                id: id,
                documentId: documentId,
                parentBlockId: parentBlockId,
                sortRank: sortRank,
                blockType: blockType,
                plainText: plainText,
                payloadJson: payloadJson,
                attributesJson: attributesJson,
                isChecked: isChecked,
                semanticHash: semanticHash,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String documentId,
                Value<String?> parentBlockId = const Value.absent(),
                required int sortRank,
                required DocumentBlockType blockType,
                Value<String> plainText = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<String> attributesJson = const Value.absent(),
                Value<bool?> isChecked = const Value.absent(),
                required String semanticHash,
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentBlocksCompanion.insert(
                id: id,
                documentId: documentId,
                parentBlockId: parentBlockId,
                sortRank: sortRank,
                blockType: blockType,
                plainText: plainText,
                payloadJson: payloadJson,
                attributesJson: attributesJson,
                isChecked: isChecked,
                semanticHash: semanticHash,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentBlocksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                documentId = false,
                parentBlockId = false,
                pastAnchorLinksRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pastAnchorLinksRefs) db.pastAnchorLinks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (documentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.documentId,
                            referencedTable: $$DocumentBlocksTableReferences
                                ._documentIdTable(db),
                            referencedColumn: $$DocumentBlocksTableReferences
                                ._documentIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (parentBlockId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.parentBlockId,
                            referencedTable: $$DocumentBlocksTableReferences
                                ._parentBlockIdTable(db),
                            referencedColumn: $$DocumentBlocksTableReferences
                                ._parentBlockIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pastAnchorLinksRefs)
                        await $_getPrefetchedData<
                          DocumentBlockRow,
                          $DocumentBlocksTable,
                          PastAnchorLinkRow
                        >(
                          currentTable: table,
                          referencedTable: $$DocumentBlocksTableReferences
                              ._pastAnchorLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$DocumentBlocksTableReferences(
                                db,
                                table,
                                p0,
                              ).pastAnchorLinksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.currentBlockId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$DocumentBlocksTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $DocumentBlocksTable,
      DocumentBlockRow,
      $$DocumentBlocksTableFilterComposer,
      $$DocumentBlocksTableOrderingComposer,
      $$DocumentBlocksTableAnnotationComposer,
      $$DocumentBlocksTableCreateCompanionBuilder,
      $$DocumentBlocksTableUpdateCompanionBuilder,
      (DocumentBlockRow, $$DocumentBlocksTableReferences),
      DocumentBlockRow,
      PrefetchHooks Function({
        bool documentId,
        bool parentBlockId,
        bool pastAnchorLinksRefs,
      })
    >;
typedef $$DocumentRevisionsTableCreateCompanionBuilder =
    DocumentRevisionsCompanion Function({
      required String id,
      required String documentId,
      required int revision,
      required String reason,
      Value<String> codec,
      required Uint8List snapshotBlob,
      required String snapshotSha256,
      required int createdAtUtc,
      Value<int> rowid,
    });
typedef $$DocumentRevisionsTableUpdateCompanionBuilder =
    DocumentRevisionsCompanion Function({
      Value<String> id,
      Value<String> documentId,
      Value<int> revision,
      Value<String> reason,
      Value<String> codec,
      Value<Uint8List> snapshotBlob,
      Value<String> snapshotSha256,
      Value<int> createdAtUtc,
      Value<int> rowid,
    });

final class $$DocumentRevisionsTableReferences
    extends
        BaseReferences<
          _$DangguiDatabase,
          $DocumentRevisionsTable,
          DocumentRevisionRow
        > {
  $$DocumentRevisionsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $DocumentsTable _documentIdTable(_$DangguiDatabase db) => db.documents
      .createAlias('document_revisions__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$DocumentRevisionsTableFilterComposer
    extends Composer<_$DangguiDatabase, $DocumentRevisionsTable> {
  $$DocumentRevisionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get snapshotBlob => $composableBuilder(
    column: $table.snapshotBlob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotSha256 => $composableBuilder(
    column: $table.snapshotSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentRevisionsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $DocumentRevisionsTable> {
  $$DocumentRevisionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get codec => $composableBuilder(
    column: $table.codec,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get snapshotBlob => $composableBuilder(
    column: $table.snapshotBlob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotSha256 => $composableBuilder(
    column: $table.snapshotSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentRevisionsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $DocumentRevisionsTable> {
  $$DocumentRevisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get codec =>
      $composableBuilder(column: $table.codec, builder: (column) => column);

  GeneratedColumn<Uint8List> get snapshotBlob => $composableBuilder(
    column: $table.snapshotBlob,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotSha256 => $composableBuilder(
    column: $table.snapshotSha256,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$DocumentRevisionsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $DocumentRevisionsTable,
          DocumentRevisionRow,
          $$DocumentRevisionsTableFilterComposer,
          $$DocumentRevisionsTableOrderingComposer,
          $$DocumentRevisionsTableAnnotationComposer,
          $$DocumentRevisionsTableCreateCompanionBuilder,
          $$DocumentRevisionsTableUpdateCompanionBuilder,
          (DocumentRevisionRow, $$DocumentRevisionsTableReferences),
          DocumentRevisionRow,
          PrefetchHooks Function({bool documentId})
        > {
  $$DocumentRevisionsTableTableManager(
    _$DangguiDatabase db,
    $DocumentRevisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DocumentRevisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DocumentRevisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DocumentRevisionsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> codec = const Value.absent(),
                Value<Uint8List> snapshotBlob = const Value.absent(),
                Value<String> snapshotSha256 = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentRevisionsCompanion(
                id: id,
                documentId: documentId,
                revision: revision,
                reason: reason,
                codec: codec,
                snapshotBlob: snapshotBlob,
                snapshotSha256: snapshotSha256,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String documentId,
                required int revision,
                required String reason,
                Value<String> codec = const Value.absent(),
                required Uint8List snapshotBlob,
                required String snapshotSha256,
                required int createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => DocumentRevisionsCompanion.insert(
                id: id,
                documentId: documentId,
                revision: revision,
                reason: reason,
                codec: codec,
                snapshotBlob: snapshotBlob,
                snapshotSha256: snapshotSha256,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$DocumentRevisionsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.documentId,
                        referencedTable: $$DocumentRevisionsTableReferences
                            ._documentIdTable(db),
                        referencedColumn: $$DocumentRevisionsTableReferences
                            ._documentIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$DocumentRevisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $DocumentRevisionsTable,
      DocumentRevisionRow,
      $$DocumentRevisionsTableFilterComposer,
      $$DocumentRevisionsTableOrderingComposer,
      $$DocumentRevisionsTableAnnotationComposer,
      $$DocumentRevisionsTableCreateCompanionBuilder,
      $$DocumentRevisionsTableUpdateCompanionBuilder,
      (DocumentRevisionRow, $$DocumentRevisionsTableReferences),
      DocumentRevisionRow,
      PrefetchHooks Function({bool documentId})
    >;
typedef $$TasksTableCreateCompanionBuilder = TasksCompanion Function({
  required String id,
  required String documentId,
  required String title,
  Value<String?> dueLocalDate,
  Value<String> planText,
  required TaskStatus status,
  required int manualRank,
  Value<int?> closedAtUtc,
  Value<String?> closedLocalDate,
  Value<String?> closedLocalTime,
  Value<String?> closedZoneId,
  Value<int?> archivedAtUtc,
  Value<int?> deletedAtUtc,
  required String semanticHash,
  required int createdAtUtc,
  required int updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});
typedef $$TasksTableUpdateCompanionBuilder = TasksCompanion Function({
  Value<String> id,
  Value<String> documentId,
  Value<String> title,
  Value<String?> dueLocalDate,
  Value<String> planText,
  Value<TaskStatus> status,
  Value<int> manualRank,
  Value<int?> closedAtUtc,
  Value<String?> closedLocalDate,
  Value<String?> closedLocalTime,
  Value<String?> closedZoneId,
  Value<int?> archivedAtUtc,
  Value<int?> deletedAtUtc,
  Value<String> semanticHash,
  Value<int> createdAtUtc,
  Value<int> updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});

final class $$TasksTableReferences
    extends BaseReferences<_$DangguiDatabase, $TasksTable, TaskRow> {
  $$TasksTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DocumentsTable _documentIdTable(_$DangguiDatabase db) =>
      db.documents.createAlias('tasks__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RemindersTable, List<ReminderRow>>
  _remindersRefsTable(_$DangguiDatabase db) => MultiTypedResultKey.fromTable(
    db.reminders,
    aliasName: 'tasks__id__reminders__task_id',
  );

  $$RemindersTableProcessedTableManager get remindersRefs {
    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.taskId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_remindersRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TasksTableFilterComposer
    extends Composer<_$DangguiDatabase, $TasksTable> {
  $$TasksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dueLocalDate => $composableBuilder(
    column: $table.dueLocalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get planText => $composableBuilder(
    column: $table.planText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TaskStatus, TaskStatus, String> get status =>
      $composableBuilder(
        column: $table.status,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get manualRank => $composableBuilder(
    column: $table.manualRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get closedAtUtc => $composableBuilder(
    column: $table.closedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedLocalDate => $composableBuilder(
    column: $table.closedLocalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedLocalTime => $composableBuilder(
    column: $table.closedLocalTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get closedZoneId => $composableBuilder(
    column: $table.closedZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get archivedAtUtc => $composableBuilder(
    column: $table.archivedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> remindersRefs(
    Expression<bool> Function($$RemindersTableFilterComposer f) f,
  ) {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableOrderingComposer
    extends Composer<_$DangguiDatabase, $TasksTable> {
  $$TasksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dueLocalDate => $composableBuilder(
    column: $table.dueLocalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get planText => $composableBuilder(
    column: $table.planText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualRank => $composableBuilder(
    column: $table.manualRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get closedAtUtc => $composableBuilder(
    column: $table.closedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedLocalDate => $composableBuilder(
    column: $table.closedLocalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedLocalTime => $composableBuilder(
    column: $table.closedLocalTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get closedZoneId => $composableBuilder(
    column: $table.closedZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get archivedAtUtc => $composableBuilder(
    column: $table.archivedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TasksTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $TasksTable> {
  $$TasksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get dueLocalDate => $composableBuilder(
    column: $table.dueLocalDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get planText =>
      $composableBuilder(column: $table.planText, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TaskStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get manualRank => $composableBuilder(
    column: $table.manualRank,
    builder: (column) => column,
  );

  GeneratedColumn<int> get closedAtUtc => $composableBuilder(
    column: $table.closedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get closedLocalDate => $composableBuilder(
    column: $table.closedLocalDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get closedLocalTime => $composableBuilder(
    column: $table.closedLocalTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get closedZoneId => $composableBuilder(
    column: $table.closedZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get archivedAtUtc => $composableBuilder(
    column: $table.archivedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> remindersRefs<T extends Object>(
    Expression<T> Function($$RemindersTableAnnotationComposer a) f,
  ) {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.taskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TasksTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $TasksTable,
          TaskRow,
          $$TasksTableFilterComposer,
          $$TasksTableOrderingComposer,
          $$TasksTableAnnotationComposer,
          $$TasksTableCreateCompanionBuilder,
          $$TasksTableUpdateCompanionBuilder,
          (TaskRow, $$TasksTableReferences),
          TaskRow,
          PrefetchHooks Function({bool documentId, bool remindersRefs})
        > {
  $$TasksTableTableManager(_$DangguiDatabase db, $TasksTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TasksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TasksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TasksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> dueLocalDate = const Value.absent(),
                Value<String> planText = const Value.absent(),
                Value<TaskStatus> status = const Value.absent(),
                Value<int> manualRank = const Value.absent(),
                Value<int?> closedAtUtc = const Value.absent(),
                Value<String?> closedLocalDate = const Value.absent(),
                Value<String?> closedLocalTime = const Value.absent(),
                Value<String?> closedZoneId = const Value.absent(),
                Value<int?> archivedAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<String> semanticHash = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion(
                id: id,
                documentId: documentId,
                title: title,
                dueLocalDate: dueLocalDate,
                planText: planText,
                status: status,
                manualRank: manualRank,
                closedAtUtc: closedAtUtc,
                closedLocalDate: closedLocalDate,
                closedLocalTime: closedLocalTime,
                closedZoneId: closedZoneId,
                archivedAtUtc: archivedAtUtc,
                deletedAtUtc: deletedAtUtc,
                semanticHash: semanticHash,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String documentId,
                required String title,
                Value<String?> dueLocalDate = const Value.absent(),
                Value<String> planText = const Value.absent(),
                required TaskStatus status,
                required int manualRank,
                Value<int?> closedAtUtc = const Value.absent(),
                Value<String?> closedLocalDate = const Value.absent(),
                Value<String?> closedLocalTime = const Value.absent(),
                Value<String?> closedZoneId = const Value.absent(),
                Value<int?> archivedAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                required String semanticHash,
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TasksCompanion.insert(
                id: id,
                documentId: documentId,
                title: title,
                dueLocalDate: dueLocalDate,
                planText: planText,
                status: status,
                manualRank: manualRank,
                closedAtUtc: closedAtUtc,
                closedLocalDate: closedLocalDate,
                closedLocalTime: closedLocalTime,
                closedZoneId: closedZoneId,
                archivedAtUtc: archivedAtUtc,
                deletedAtUtc: deletedAtUtc,
                semanticHash: semanticHash,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TasksTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false, remindersRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (remindersRefs) db.reminders],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.documentId,
                        referencedTable: $$TasksTableReferences
                            ._documentIdTable(db),
                        referencedColumn: $$TasksTableReferences
                            ._documentIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (remindersRefs)
                    await $_getPrefetchedData<
                      TaskRow,
                      $TasksTable,
                      ReminderRow
                    >(
                      currentTable: table,
                      referencedTable: $$TasksTableReferences
                          ._remindersRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TasksTableReferences(db, table, p0).remindersRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.taskId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TasksTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $TasksTable,
      TaskRow,
      $$TasksTableFilterComposer,
      $$TasksTableOrderingComposer,
      $$TasksTableAnnotationComposer,
      $$TasksTableCreateCompanionBuilder,
      $$TasksTableUpdateCompanionBuilder,
      (TaskRow, $$TasksTableReferences),
      TaskRow,
      PrefetchHooks Function({bool documentId, bool remindersRefs})
    >;
typedef $$RemindersTableCreateCompanionBuilder = RemindersCompanion Function({
  required String id,
  required String taskId,
  required String scheduledLocalDateTime,
  required String scheduledZoneId,
  required int scheduledAtUtc,
  Value<int?> snoozedUntilUtc,
  required bool soundEnabled,
  required bool vibrationEnabled,
  required ReminderStatus status,
  Value<ReminderPauseReason?> pauseReason,
  Value<int> snoozeCount,
  Value<int> scheduleRevision,
  Value<int?> lastFiredAtUtc,
  required int createdAtUtc,
  required int updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});
typedef $$RemindersTableUpdateCompanionBuilder = RemindersCompanion Function({
  Value<String> id,
  Value<String> taskId,
  Value<String> scheduledLocalDateTime,
  Value<String> scheduledZoneId,
  Value<int> scheduledAtUtc,
  Value<int?> snoozedUntilUtc,
  Value<bool> soundEnabled,
  Value<bool> vibrationEnabled,
  Value<ReminderStatus> status,
  Value<ReminderPauseReason?> pauseReason,
  Value<int> snoozeCount,
  Value<int> scheduleRevision,
  Value<int?> lastFiredAtUtc,
  Value<int> createdAtUtc,
  Value<int> updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});

final class $$RemindersTableReferences
    extends BaseReferences<_$DangguiDatabase, $RemindersTable, ReminderRow> {
  $$RemindersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TasksTable _taskIdTable(_$DangguiDatabase db) =>
      db.tasks.createAlias('reminders__task_id__tasks__id');

  $$TasksTableProcessedTableManager get taskId {
    final $_column = $_itemColumn<String>('task_id')!;

    final manager = $$TasksTableTableManager(
      $_db,
      $_db.tasks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_taskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<
    $NotificationRegistrationsTable,
    List<NotificationRegistrationRow>
  >
  _notificationRegistrationsRefsTable(_$DangguiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.notificationRegistrations,
        aliasName: 'reminders__id__notification_registrations__reminder_id',
      );

  $$NotificationRegistrationsTableProcessedTableManager
  get notificationRegistrationsRefs {
    final manager = $$NotificationRegistrationsTableTableManager(
      $_db,
      $_db.notificationRegistrations,
    ).filter((f) => f.reminderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _notificationRegistrationsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RemindersTableFilterComposer
    extends Composer<_$DangguiDatabase, $RemindersTable> {
  $$RemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledLocalDateTime => $composableBuilder(
    column: $table.scheduledLocalDateTime,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledZoneId => $composableBuilder(
    column: $table.scheduledZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduledAtUtc => $composableBuilder(
    column: $table.scheduledAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get snoozedUntilUtc => $composableBuilder(
    column: $table.snoozedUntilUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get vibrationEnabled => $composableBuilder(
    column: $table.vibrationEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ReminderStatus, ReminderStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<
    ReminderPauseReason?,
    ReminderPauseReason,
    String
  >
  get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduleRevision => $composableBuilder(
    column: $table.scheduleRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastFiredAtUtc => $composableBuilder(
    column: $table.lastFiredAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$TasksTableFilterComposer get taskId {
    final $$TasksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableFilterComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> notificationRegistrationsRefs(
    Expression<bool> Function($$NotificationRegistrationsTableFilterComposer f)
    f,
  ) {
    final $$NotificationRegistrationsTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.notificationRegistrations,
          getReferencedColumn: (t) => t.reminderId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NotificationRegistrationsTableFilterComposer(
                $db: $db,
                $table: $db.notificationRegistrations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$RemindersTableOrderingComposer
    extends Composer<_$DangguiDatabase, $RemindersTable> {
  $$RemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledLocalDateTime => $composableBuilder(
    column: $table.scheduledLocalDateTime,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledZoneId => $composableBuilder(
    column: $table.scheduledZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduledAtUtc => $composableBuilder(
    column: $table.scheduledAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozedUntilUtc => $composableBuilder(
    column: $table.snoozedUntilUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get vibrationEnabled => $composableBuilder(
    column: $table.vibrationEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduleRevision => $composableBuilder(
    column: $table.scheduleRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastFiredAtUtc => $composableBuilder(
    column: $table.lastFiredAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$TasksTableOrderingComposer get taskId {
    final $$TasksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableOrderingComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RemindersTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $RemindersTable> {
  $$RemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get scheduledLocalDateTime => $composableBuilder(
    column: $table.scheduledLocalDateTime,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledZoneId => $composableBuilder(
    column: $table.scheduledZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduledAtUtc => $composableBuilder(
    column: $table.scheduledAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozedUntilUtc => $composableBuilder(
    column: $table.snoozedUntilUtc,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get soundEnabled => $composableBuilder(
    column: $table.soundEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get vibrationEnabled => $composableBuilder(
    column: $table.vibrationEnabled,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<ReminderStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ReminderPauseReason?, String>
  get pauseReason => $composableBuilder(
    column: $table.pauseReason,
    builder: (column) => column,
  );

  GeneratedColumn<int> get snoozeCount => $composableBuilder(
    column: $table.snoozeCount,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduleRevision => $composableBuilder(
    column: $table.scheduleRevision,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastFiredAtUtc => $composableBuilder(
    column: $table.lastFiredAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  $$TasksTableAnnotationComposer get taskId {
    final $$TasksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.taskId,
      referencedTable: $db.tasks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TasksTableAnnotationComposer(
            $db: $db,
            $table: $db.tasks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> notificationRegistrationsRefs<T extends Object>(
    Expression<T> Function($$NotificationRegistrationsTableAnnotationComposer a)
    f,
  ) {
    final $$NotificationRegistrationsTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.notificationRegistrations,
          getReferencedColumn: (t) => t.reminderId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$NotificationRegistrationsTableAnnotationComposer(
                $db: $db,
                $table: $db.notificationRegistrations,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }
}

class $$RemindersTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $RemindersTable,
          ReminderRow,
          $$RemindersTableFilterComposer,
          $$RemindersTableOrderingComposer,
          $$RemindersTableAnnotationComposer,
          $$RemindersTableCreateCompanionBuilder,
          $$RemindersTableUpdateCompanionBuilder,
          (ReminderRow, $$RemindersTableReferences),
          ReminderRow,
          PrefetchHooks Function({
            bool taskId,
            bool notificationRegistrationsRefs,
          })
        > {
  $$RemindersTableTableManager(_$DangguiDatabase db, $RemindersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> taskId = const Value.absent(),
                Value<String> scheduledLocalDateTime = const Value.absent(),
                Value<String> scheduledZoneId = const Value.absent(),
                Value<int> scheduledAtUtc = const Value.absent(),
                Value<int?> snoozedUntilUtc = const Value.absent(),
                Value<bool> soundEnabled = const Value.absent(),
                Value<bool> vibrationEnabled = const Value.absent(),
                Value<ReminderStatus> status = const Value.absent(),
                Value<ReminderPauseReason?> pauseReason = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
                Value<int> scheduleRevision = const Value.absent(),
                Value<int?> lastFiredAtUtc = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion(
                id: id,
                taskId: taskId,
                scheduledLocalDateTime: scheduledLocalDateTime,
                scheduledZoneId: scheduledZoneId,
                scheduledAtUtc: scheduledAtUtc,
                snoozedUntilUtc: snoozedUntilUtc,
                soundEnabled: soundEnabled,
                vibrationEnabled: vibrationEnabled,
                status: status,
                pauseReason: pauseReason,
                snoozeCount: snoozeCount,
                scheduleRevision: scheduleRevision,
                lastFiredAtUtc: lastFiredAtUtc,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String taskId,
                required String scheduledLocalDateTime,
                required String scheduledZoneId,
                required int scheduledAtUtc,
                Value<int?> snoozedUntilUtc = const Value.absent(),
                required bool soundEnabled,
                required bool vibrationEnabled,
                required ReminderStatus status,
                Value<ReminderPauseReason?> pauseReason = const Value.absent(),
                Value<int> snoozeCount = const Value.absent(),
                Value<int> scheduleRevision = const Value.absent(),
                Value<int?> lastFiredAtUtc = const Value.absent(),
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RemindersCompanion.insert(
                id: id,
                taskId: taskId,
                scheduledLocalDateTime: scheduledLocalDateTime,
                scheduledZoneId: scheduledZoneId,
                scheduledAtUtc: scheduledAtUtc,
                snoozedUntilUtc: snoozedUntilUtc,
                soundEnabled: soundEnabled,
                vibrationEnabled: vibrationEnabled,
                status: status,
                pauseReason: pauseReason,
                snoozeCount: snoozeCount,
                scheduleRevision: scheduleRevision,
                lastFiredAtUtc: lastFiredAtUtc,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RemindersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({taskId = false, notificationRegistrationsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (notificationRegistrationsRefs)
                      db.notificationRegistrations,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (taskId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.taskId,
                            referencedTable: $$RemindersTableReferences
                                ._taskIdTable(db),
                            referencedColumn: $$RemindersTableReferences
                                ._taskIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (notificationRegistrationsRefs)
                        await $_getPrefetchedData<
                          ReminderRow,
                          $RemindersTable,
                          NotificationRegistrationRow
                        >(
                          currentTable: table,
                          referencedTable: $$RemindersTableReferences
                              ._notificationRegistrationsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RemindersTableReferences(
                                db,
                                table,
                                p0,
                              ).notificationRegistrationsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.reminderId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RemindersTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $RemindersTable,
      ReminderRow,
      $$RemindersTableFilterComposer,
      $$RemindersTableOrderingComposer,
      $$RemindersTableAnnotationComposer,
      $$RemindersTableCreateCompanionBuilder,
      $$RemindersTableUpdateCompanionBuilder,
      (ReminderRow, $$RemindersTableReferences),
      ReminderRow,
      PrefetchHooks Function({bool taskId, bool notificationRegistrationsRefs})
    >;
typedef $$NotificationRegistrationsTableCreateCompanionBuilder =
    NotificationRegistrationsCompanion Function({
      required String reminderId,
      required String platform,
      required int platformNotificationId,
      required int scheduleRevision,
      required String scheduledLocale,
      required int registeredAtUtc,
      Value<String?> lastErrorCode,
      Value<int> rowid,
    });
typedef $$NotificationRegistrationsTableUpdateCompanionBuilder =
    NotificationRegistrationsCompanion Function({
      Value<String> reminderId,
      Value<String> platform,
      Value<int> platformNotificationId,
      Value<int> scheduleRevision,
      Value<String> scheduledLocale,
      Value<int> registeredAtUtc,
      Value<String?> lastErrorCode,
      Value<int> rowid,
    });

final class $$NotificationRegistrationsTableReferences
    extends
        BaseReferences<
          _$DangguiDatabase,
          $NotificationRegistrationsTable,
          NotificationRegistrationRow
        > {
  $$NotificationRegistrationsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RemindersTable _reminderIdTable(_$DangguiDatabase db) => db.reminders
      .createAlias('notification_registrations__reminder_id__reminders__id');

  $$RemindersTableProcessedTableManager get reminderId {
    final $_column = $_itemColumn<String>('reminder_id')!;

    final manager = $$RemindersTableTableManager(
      $_db,
      $_db.reminders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_reminderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NotificationRegistrationsTableFilterComposer
    extends Composer<_$DangguiDatabase, $NotificationRegistrationsTable> {
  $$NotificationRegistrationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get platformNotificationId => $composableBuilder(
    column: $table.platformNotificationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get scheduleRevision => $composableBuilder(
    column: $table.scheduleRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get scheduledLocale => $composableBuilder(
    column: $table.scheduledLocale,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get registeredAtUtc => $composableBuilder(
    column: $table.registeredAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  $$RemindersTableFilterComposer get reminderId {
    final $$RemindersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reminderId,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableFilterComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotificationRegistrationsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $NotificationRegistrationsTable> {
  $$NotificationRegistrationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get platformNotificationId => $composableBuilder(
    column: $table.platformNotificationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get scheduleRevision => $composableBuilder(
    column: $table.scheduleRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scheduledLocale => $composableBuilder(
    column: $table.scheduledLocale,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get registeredAtUtc => $composableBuilder(
    column: $table.registeredAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$RemindersTableOrderingComposer get reminderId {
    final $$RemindersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reminderId,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableOrderingComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotificationRegistrationsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $NotificationRegistrationsTable> {
  $$NotificationRegistrationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<int> get platformNotificationId => $composableBuilder(
    column: $table.platformNotificationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get scheduleRevision => $composableBuilder(
    column: $table.scheduleRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get scheduledLocale => $composableBuilder(
    column: $table.scheduledLocale,
    builder: (column) => column,
  );

  GeneratedColumn<int> get registeredAtUtc => $composableBuilder(
    column: $table.registeredAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  $$RemindersTableAnnotationComposer get reminderId {
    final $$RemindersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.reminderId,
      referencedTable: $db.reminders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RemindersTableAnnotationComposer(
            $db: $db,
            $table: $db.reminders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotificationRegistrationsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $NotificationRegistrationsTable,
          NotificationRegistrationRow,
          $$NotificationRegistrationsTableFilterComposer,
          $$NotificationRegistrationsTableOrderingComposer,
          $$NotificationRegistrationsTableAnnotationComposer,
          $$NotificationRegistrationsTableCreateCompanionBuilder,
          $$NotificationRegistrationsTableUpdateCompanionBuilder,
          (
            NotificationRegistrationRow,
            $$NotificationRegistrationsTableReferences,
          ),
          NotificationRegistrationRow,
          PrefetchHooks Function({bool reminderId})
        > {
  $$NotificationRegistrationsTableTableManager(
    _$DangguiDatabase db,
    $NotificationRegistrationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationRegistrationsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationRegistrationsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationRegistrationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> reminderId = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<int> platformNotificationId = const Value.absent(),
                Value<int> scheduleRevision = const Value.absent(),
                Value<String> scheduledLocale = const Value.absent(),
                Value<int> registeredAtUtc = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationRegistrationsCompanion(
                reminderId: reminderId,
                platform: platform,
                platformNotificationId: platformNotificationId,
                scheduleRevision: scheduleRevision,
                scheduledLocale: scheduledLocale,
                registeredAtUtc: registeredAtUtc,
                lastErrorCode: lastErrorCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String reminderId,
                required String platform,
                required int platformNotificationId,
                required int scheduleRevision,
                required String scheduledLocale,
                required int registeredAtUtc,
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationRegistrationsCompanion.insert(
                reminderId: reminderId,
                platform: platform,
                platformNotificationId: platformNotificationId,
                scheduleRevision: scheduleRevision,
                scheduledLocale: scheduledLocale,
                registeredAtUtc: registeredAtUtc,
                lastErrorCode: lastErrorCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$NotificationRegistrationsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({reminderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (reminderId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.reminderId,
                        referencedTable:
                            $$NotificationRegistrationsTableReferences
                                ._reminderIdTable(db),
                        referencedColumn:
                            $$NotificationRegistrationsTableReferences
                                ._reminderIdTable(db)
                                .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NotificationRegistrationsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $NotificationRegistrationsTable,
      NotificationRegistrationRow,
      $$NotificationRegistrationsTableFilterComposer,
      $$NotificationRegistrationsTableOrderingComposer,
      $$NotificationRegistrationsTableAnnotationComposer,
      $$NotificationRegistrationsTableCreateCompanionBuilder,
      $$NotificationRegistrationsTableUpdateCompanionBuilder,
      (NotificationRegistrationRow, $$NotificationRegistrationsTableReferences),
      NotificationRegistrationRow,
      PrefetchHooks Function({bool reminderId})
    >;
typedef $$PlatformJobsTableCreateCompanionBuilder =
    PlatformJobsCompanion Function({
      required String id,
      required PlatformJobKind kind,
      required String aggregateId,
      required int aggregateRevision,
      required String dedupeKey,
      required String payloadJson,
      required PlatformJobStatus status,
      Value<int> attempts,
      required int nextAttemptAtUtc,
      Value<String?> lastErrorCode,
      required int createdAtUtc,
      required int updatedAtUtc,
      Value<int> rowid,
    });
typedef $$PlatformJobsTableUpdateCompanionBuilder =
    PlatformJobsCompanion Function({
      Value<String> id,
      Value<PlatformJobKind> kind,
      Value<String> aggregateId,
      Value<int> aggregateRevision,
      Value<String> dedupeKey,
      Value<String> payloadJson,
      Value<PlatformJobStatus> status,
      Value<int> attempts,
      Value<int> nextAttemptAtUtc,
      Value<String?> lastErrorCode,
      Value<int> createdAtUtc,
      Value<int> updatedAtUtc,
      Value<int> rowid,
    });

class $$PlatformJobsTableFilterComposer
    extends Composer<_$DangguiDatabase, $PlatformJobsTable> {
  $$PlatformJobsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PlatformJobKind, PlatformJobKind, String>
  get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get aggregateRevision => $composableBuilder(
    column: $table.aggregateRevision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PlatformJobStatus, PlatformJobStatus, String>
  get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextAttemptAtUtc => $composableBuilder(
    column: $table.nextAttemptAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PlatformJobsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $PlatformJobsTable> {
  $$PlatformJobsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get aggregateRevision => $composableBuilder(
    column: $table.aggregateRevision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dedupeKey => $composableBuilder(
    column: $table.dedupeKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextAttemptAtUtc => $composableBuilder(
    column: $table.nextAttemptAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PlatformJobsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $PlatformJobsTable> {
  $$PlatformJobsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PlatformJobKind, String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get aggregateId => $composableBuilder(
    column: $table.aggregateId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get aggregateRevision => $composableBuilder(
    column: $table.aggregateRevision,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dedupeKey =>
      $composableBuilder(column: $table.dedupeKey, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PlatformJobStatus, String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<int> get nextAttemptAtUtc => $composableBuilder(
    column: $table.nextAttemptAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastErrorCode => $composableBuilder(
    column: $table.lastErrorCode,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$PlatformJobsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $PlatformJobsTable,
          PlatformJobRow,
          $$PlatformJobsTableFilterComposer,
          $$PlatformJobsTableOrderingComposer,
          $$PlatformJobsTableAnnotationComposer,
          $$PlatformJobsTableCreateCompanionBuilder,
          $$PlatformJobsTableUpdateCompanionBuilder,
          (
            PlatformJobRow,
            BaseReferences<
              _$DangguiDatabase,
              $PlatformJobsTable,
              PlatformJobRow
            >,
          ),
          PlatformJobRow,
          PrefetchHooks Function()
        > {
  $$PlatformJobsTableTableManager(
    _$DangguiDatabase db,
    $PlatformJobsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PlatformJobsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PlatformJobsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PlatformJobsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<PlatformJobKind> kind = const Value.absent(),
                Value<String> aggregateId = const Value.absent(),
                Value<int> aggregateRevision = const Value.absent(),
                Value<String> dedupeKey = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<PlatformJobStatus> status = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<int> nextAttemptAtUtc = const Value.absent(),
                Value<String?> lastErrorCode = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PlatformJobsCompanion(
                id: id,
                kind: kind,
                aggregateId: aggregateId,
                aggregateRevision: aggregateRevision,
                dedupeKey: dedupeKey,
                payloadJson: payloadJson,
                status: status,
                attempts: attempts,
                nextAttemptAtUtc: nextAttemptAtUtc,
                lastErrorCode: lastErrorCode,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required PlatformJobKind kind,
                required String aggregateId,
                required int aggregateRevision,
                required String dedupeKey,
                required String payloadJson,
                required PlatformJobStatus status,
                Value<int> attempts = const Value.absent(),
                required int nextAttemptAtUtc,
                Value<String?> lastErrorCode = const Value.absent(),
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => PlatformJobsCompanion.insert(
                id: id,
                kind: kind,
                aggregateId: aggregateId,
                aggregateRevision: aggregateRevision,
                dedupeKey: dedupeKey,
                payloadJson: payloadJson,
                status: status,
                attempts: attempts,
                nextAttemptAtUtc: nextAttemptAtUtc,
                lastErrorCode: lastErrorCode,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlatformJobsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $PlatformJobsTable,
      PlatformJobRow,
      $$PlatformJobsTableFilterComposer,
      $$PlatformJobsTableOrderingComposer,
      $$PlatformJobsTableAnnotationComposer,
      $$PlatformJobsTableCreateCompanionBuilder,
      $$PlatformJobsTableUpdateCompanionBuilder,
      (
        PlatformJobRow,
        BaseReferences<_$DangguiDatabase, $PlatformJobsTable, PlatformJobRow>,
      ),
      PlatformJobRow,
      PrefetchHooks Function()
    >;
typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  required String id,
  required String name,
  required String normalizedName,
  required int sortRank,
  required int createdAtUtc,
  required int updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String> normalizedName,
  Value<int> sortRank,
  Value<int> createdAtUtc,
  Value<int> updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});

final class $$FoldersTableReferences
    extends BaseReferences<_$DangguiDatabase, $FoldersTable, FolderRow> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$NotesTable, List<NoteRow>> _notesRefsTable(
    _$DangguiDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.notes,
    aliasName: 'folders__id__notes__folder_id',
  );

  $$NotesTableProcessedTableManager get notesRefs {
    final manager = $$NotesTableTableManager(
      $_db,
      $_db.notes,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_notesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoldersTableFilterComposer
    extends Composer<_$DangguiDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortRank => $composableBuilder(
    column: $table.sortRank,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> notesRefs(
    Expression<bool> Function($$NotesTableFilterComposer f) f,
  ) {
    final $$NotesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableFilterComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer
    extends Composer<_$DangguiDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortRank => $composableBuilder(
    column: $table.sortRank,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoldersTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get normalizedName => $composableBuilder(
    column: $table.normalizedName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortRank =>
      $composableBuilder(column: $table.sortRank, builder: (column) => column);

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  Expression<T> notesRefs<T extends Object>(
    Expression<T> Function($$NotesTableAnnotationComposer a) f,
  ) {
    final $$NotesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.notes,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NotesTableAnnotationComposer(
            $db: $db,
            $table: $db.notes,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $FoldersTable,
          FolderRow,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (FolderRow, $$FoldersTableReferences),
          FolderRow,
          PrefetchHooks Function({bool notesRefs})
        > {
  $$FoldersTableTableManager(_$DangguiDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> normalizedName = const Value.absent(),
                Value<int> sortRank = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                name: name,
                normalizedName: normalizedName,
                sortRank: sortRank,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String normalizedName,
                required int sortRank,
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                name: name,
                normalizedName: normalizedName,
                sortRank: sortRank,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({notesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (notesRefs) db.notes],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (notesRefs)
                    await $_getPrefetchedData<
                      FolderRow,
                      $FoldersTable,
                      NoteRow
                    >(
                      currentTable: table,
                      referencedTable: $$FoldersTableReferences._notesRefsTable(
                        db,
                      ),
                      managerFromTypedResult: (p0) =>
                          $$FoldersTableReferences(db, table, p0).notesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $FoldersTable,
      FolderRow,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (FolderRow, $$FoldersTableReferences),
      FolderRow,
      PrefetchHooks Function({bool notesRefs})
    >;
typedef $$NotesTableCreateCompanionBuilder = NotesCompanion Function({
  required String id,
  required String documentId,
  Value<String?> folderId,
  Value<String> title,
  Value<int?> pinnedAtUtc,
  Value<int?> deletedAtUtc,
  required String semanticHash,
  required int createdAtUtc,
  required int updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});
typedef $$NotesTableUpdateCompanionBuilder = NotesCompanion Function({
  Value<String> id,
  Value<String> documentId,
  Value<String?> folderId,
  Value<String> title,
  Value<int?> pinnedAtUtc,
  Value<int?> deletedAtUtc,
  Value<String> semanticHash,
  Value<int> createdAtUtc,
  Value<int> updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});

final class $$NotesTableReferences
    extends BaseReferences<_$DangguiDatabase, $NotesTable, NoteRow> {
  $$NotesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DocumentsTable _documentIdTable(_$DangguiDatabase db) =>
      db.documents.createAlias('notes__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FoldersTable _folderIdTable(_$DangguiDatabase db) =>
      db.folders.createAlias('notes__folder_id__folders__id');

  $$FoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<String>('folder_id');
    if ($_column == null) return null;
    final manager = $$FoldersTableTableManager(
      $_db,
      $_db.folders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NotesTableFilterComposer
    extends Composer<_$DangguiDatabase, $NotesTable> {
  $$NotesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pinnedAtUtc => $composableBuilder(
    column: $table.pinnedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableOrderingComposer
    extends Composer<_$DangguiDatabase, $NotesTable> {
  $$NotesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pinnedAtUtc => $composableBuilder(
    column: $table.pinnedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $NotesTable> {
  $$NotesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get pinnedAtUtc => $composableBuilder(
    column: $table.pinnedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get semanticHash => $composableBuilder(
    column: $table.semanticHash,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NotesTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $NotesTable,
          NoteRow,
          $$NotesTableFilterComposer,
          $$NotesTableOrderingComposer,
          $$NotesTableAnnotationComposer,
          $$NotesTableCreateCompanionBuilder,
          $$NotesTableUpdateCompanionBuilder,
          (NoteRow, $$NotesTableReferences),
          NoteRow,
          PrefetchHooks Function({bool documentId, bool folderId})
        > {
  $$NotesTableTableManager(_$DangguiDatabase db, $NotesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NotesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NotesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String?> folderId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> pinnedAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                Value<String> semanticHash = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion(
                id: id,
                documentId: documentId,
                folderId: folderId,
                title: title,
                pinnedAtUtc: pinnedAtUtc,
                deletedAtUtc: deletedAtUtc,
                semanticHash: semanticHash,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String documentId,
                Value<String?> folderId = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> pinnedAtUtc = const Value.absent(),
                Value<int?> deletedAtUtc = const Value.absent(),
                required String semanticHash,
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotesCompanion.insert(
                id: id,
                documentId: documentId,
                folderId: folderId,
                title: title,
                pinnedAtUtc: pinnedAtUtc,
                deletedAtUtc: deletedAtUtc,
                semanticHash: semanticHash,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$NotesTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({documentId = false, folderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (documentId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.documentId,
                        referencedTable: $$NotesTableReferences
                            ._documentIdTable(db),
                        referencedColumn: $$NotesTableReferences
                            ._documentIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (folderId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.folderId,
                        referencedTable: $$NotesTableReferences._folderIdTable(
                          db,
                        ),
                        referencedColumn: $$NotesTableReferences
                            ._folderIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NotesTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $NotesTable,
      NoteRow,
      $$NotesTableFilterComposer,
      $$NotesTableOrderingComposer,
      $$NotesTableAnnotationComposer,
      $$NotesTableCreateCompanionBuilder,
      $$NotesTableUpdateCompanionBuilder,
      (NoteRow, $$NotesTableReferences),
      NoteRow,
      PrefetchHooks Function({bool documentId, bool folderId})
    >;
typedef $$TrashEntriesTableCreateCompanionBuilder =
    TrashEntriesCompanion Function({
      required String id,
      required TrashEntityType entityType,
      required String entityId,
      required int deletedAtUtc,
      required int purgeAfterUtc,
      required String restoreContextJson,
      required String snapshotSha256,
      Value<int> rowid,
    });
typedef $$TrashEntriesTableUpdateCompanionBuilder =
    TrashEntriesCompanion Function({
      Value<String> id,
      Value<TrashEntityType> entityType,
      Value<String> entityId,
      Value<int> deletedAtUtc,
      Value<int> purgeAfterUtc,
      Value<String> restoreContextJson,
      Value<String> snapshotSha256,
      Value<int> rowid,
    });

class $$TrashEntriesTableFilterComposer
    extends Composer<_$DangguiDatabase, $TrashEntriesTable> {
  $$TrashEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<TrashEntityType, TrashEntityType, String>
  get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get purgeAfterUtc => $composableBuilder(
    column: $table.purgeAfterUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get restoreContextJson => $composableBuilder(
    column: $table.restoreContextJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get snapshotSha256 => $composableBuilder(
    column: $table.snapshotSha256,
    builder: (column) => ColumnFilters(column),
  );
}

class $$TrashEntriesTableOrderingComposer
    extends Composer<_$DangguiDatabase, $TrashEntriesTable> {
  $$TrashEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get purgeAfterUtc => $composableBuilder(
    column: $table.purgeAfterUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get restoreContextJson => $composableBuilder(
    column: $table.restoreContextJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get snapshotSha256 => $composableBuilder(
    column: $table.snapshotSha256,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TrashEntriesTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $TrashEntriesTable> {
  $$TrashEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<TrashEntityType, String> get entityType =>
      $composableBuilder(
        column: $table.entityType,
        builder: (column) => column,
      );

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<int> get deletedAtUtc => $composableBuilder(
    column: $table.deletedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get purgeAfterUtc => $composableBuilder(
    column: $table.purgeAfterUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get restoreContextJson => $composableBuilder(
    column: $table.restoreContextJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get snapshotSha256 => $composableBuilder(
    column: $table.snapshotSha256,
    builder: (column) => column,
  );
}

class $$TrashEntriesTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $TrashEntriesTable,
          TrashEntryRow,
          $$TrashEntriesTableFilterComposer,
          $$TrashEntriesTableOrderingComposer,
          $$TrashEntriesTableAnnotationComposer,
          $$TrashEntriesTableCreateCompanionBuilder,
          $$TrashEntriesTableUpdateCompanionBuilder,
          (
            TrashEntryRow,
            BaseReferences<
              _$DangguiDatabase,
              $TrashEntriesTable,
              TrashEntryRow
            >,
          ),
          TrashEntryRow,
          PrefetchHooks Function()
        > {
  $$TrashEntriesTableTableManager(
    _$DangguiDatabase db,
    $TrashEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrashEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrashEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrashEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<TrashEntityType> entityType = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<int> deletedAtUtc = const Value.absent(),
                Value<int> purgeAfterUtc = const Value.absent(),
                Value<String> restoreContextJson = const Value.absent(),
                Value<String> snapshotSha256 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => TrashEntriesCompanion(
                id: id,
                entityType: entityType,
                entityId: entityId,
                deletedAtUtc: deletedAtUtc,
                purgeAfterUtc: purgeAfterUtc,
                restoreContextJson: restoreContextJson,
                snapshotSha256: snapshotSha256,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required TrashEntityType entityType,
                required String entityId,
                required int deletedAtUtc,
                required int purgeAfterUtc,
                required String restoreContextJson,
                required String snapshotSha256,
                Value<int> rowid = const Value.absent(),
              }) => TrashEntriesCompanion.insert(
                id: id,
                entityType: entityType,
                entityId: entityId,
                deletedAtUtc: deletedAtUtc,
                purgeAfterUtc: purgeAfterUtc,
                restoreContextJson: restoreContextJson,
                snapshotSha256: snapshotSha256,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$TrashEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $TrashEntriesTable,
      TrashEntryRow,
      $$TrashEntriesTableFilterComposer,
      $$TrashEntriesTableOrderingComposer,
      $$TrashEntriesTableAnnotationComposer,
      $$TrashEntriesTableCreateCompanionBuilder,
      $$TrashEntriesTableUpdateCompanionBuilder,
      (
        TrashEntryRow,
        BaseReferences<_$DangguiDatabase, $TrashEntriesTable, TrashEntryRow>,
      ),
      TrashEntryRow,
      PrefetchHooks Function()
    >;
typedef $$PastEventsTableCreateCompanionBuilder = PastEventsCompanion Function({
  required String id,
  required String documentId,
  required String sourceTaskId,
  required int appendSequence,
  required int completedAtUtc,
  required String completionLocalDate,
  required String completionZoneId,
  Value<int> sourceSnapshotVersion,
  required String sourceSnapshotJson,
  required String sourceSha256,
  required PastAnchorState anchorState,
  required int createdAtUtc,
  required int updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});
typedef $$PastEventsTableUpdateCompanionBuilder = PastEventsCompanion Function({
  Value<String> id,
  Value<String> documentId,
  Value<String> sourceTaskId,
  Value<int> appendSequence,
  Value<int> completedAtUtc,
  Value<String> completionLocalDate,
  Value<String> completionZoneId,
  Value<int> sourceSnapshotVersion,
  Value<String> sourceSnapshotJson,
  Value<String> sourceSha256,
  Value<PastAnchorState> anchorState,
  Value<int> createdAtUtc,
  Value<int> updatedAtUtc,
  Value<int> rowVersion,
  Value<int> rowid,
});

final class $$PastEventsTableReferences
    extends BaseReferences<_$DangguiDatabase, $PastEventsTable, PastEventRow> {
  $$PastEventsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $DocumentsTable _documentIdTable(_$DangguiDatabase db) =>
      db.documents.createAlias('past_events__document_id__documents__id');

  $$DocumentsTableProcessedTableManager get documentId {
    final $_column = $_itemColumn<String>('document_id')!;

    final manager = $$DocumentsTableTableManager(
      $_db,
      $_db.documents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_documentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PastEventPartsTable, List<PastEventPartRow>>
  _pastEventPartsRefsTable(_$DangguiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pastEventParts,
        aliasName: 'past_events__id__past_event_parts__event_id',
      );

  $$PastEventPartsTableProcessedTableManager get pastEventPartsRefs {
    final manager = $$PastEventPartsTableTableManager(
      $_db,
      $_db.pastEventParts,
    ).filter((f) => f.eventId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_pastEventPartsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PastEventsTableFilterComposer
    extends Composer<_$DangguiDatabase, $PastEventsTable> {
  $$PastEventsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceTaskId => $composableBuilder(
    column: $table.sourceTaskId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get appendSequence => $composableBuilder(
    column: $table.appendSequence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completionLocalDate => $composableBuilder(
    column: $table.completionLocalDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get completionZoneId => $composableBuilder(
    column: $table.completionZoneId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceSnapshotVersion => $composableBuilder(
    column: $table.sourceSnapshotVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSnapshotJson => $composableBuilder(
    column: $table.sourceSnapshotJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PastAnchorState, PastAnchorState, String>
  get anchorState => $composableBuilder(
    column: $table.anchorState,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnFilters(column),
  );

  $$DocumentsTableFilterComposer get documentId {
    final $$DocumentsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableFilterComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> pastEventPartsRefs(
    Expression<bool> Function($$PastEventPartsTableFilterComposer f) f,
  ) {
    final $$PastEventPartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pastEventParts,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventPartsTableFilterComposer(
            $db: $db,
            $table: $db.pastEventParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PastEventsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $PastEventsTable> {
  $$PastEventsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceTaskId => $composableBuilder(
    column: $table.sourceTaskId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get appendSequence => $composableBuilder(
    column: $table.appendSequence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completionLocalDate => $composableBuilder(
    column: $table.completionLocalDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get completionZoneId => $composableBuilder(
    column: $table.completionZoneId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceSnapshotVersion => $composableBuilder(
    column: $table.sourceSnapshotVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSnapshotJson => $composableBuilder(
    column: $table.sourceSnapshotJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get anchorState => $composableBuilder(
    column: $table.anchorState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => ColumnOrderings(column),
  );

  $$DocumentsTableOrderingComposer get documentId {
    final $$DocumentsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableOrderingComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PastEventsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $PastEventsTable> {
  $$PastEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceTaskId => $composableBuilder(
    column: $table.sourceTaskId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get appendSequence => $composableBuilder(
    column: $table.appendSequence,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completionLocalDate => $composableBuilder(
    column: $table.completionLocalDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get completionZoneId => $composableBuilder(
    column: $table.completionZoneId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sourceSnapshotVersion => $composableBuilder(
    column: $table.sourceSnapshotVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceSnapshotJson => $composableBuilder(
    column: $table.sourceSnapshotJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<PastAnchorState, String> get anchorState =>
      $composableBuilder(
        column: $table.anchorState,
        builder: (column) => column,
      );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rowVersion => $composableBuilder(
    column: $table.rowVersion,
    builder: (column) => column,
  );

  $$DocumentsTableAnnotationComposer get documentId {
    final $$DocumentsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.documentId,
      referencedTable: $db.documents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentsTableAnnotationComposer(
            $db: $db,
            $table: $db.documents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> pastEventPartsRefs<T extends Object>(
    Expression<T> Function($$PastEventPartsTableAnnotationComposer a) f,
  ) {
    final $$PastEventPartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pastEventParts,
      getReferencedColumn: (t) => t.eventId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventPartsTableAnnotationComposer(
            $db: $db,
            $table: $db.pastEventParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PastEventsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $PastEventsTable,
          PastEventRow,
          $$PastEventsTableFilterComposer,
          $$PastEventsTableOrderingComposer,
          $$PastEventsTableAnnotationComposer,
          $$PastEventsTableCreateCompanionBuilder,
          $$PastEventsTableUpdateCompanionBuilder,
          (PastEventRow, $$PastEventsTableReferences),
          PastEventRow,
          PrefetchHooks Function({bool documentId, bool pastEventPartsRefs})
        > {
  $$PastEventsTableTableManager(_$DangguiDatabase db, $PastEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PastEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PastEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PastEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> documentId = const Value.absent(),
                Value<String> sourceTaskId = const Value.absent(),
                Value<int> appendSequence = const Value.absent(),
                Value<int> completedAtUtc = const Value.absent(),
                Value<String> completionLocalDate = const Value.absent(),
                Value<String> completionZoneId = const Value.absent(),
                Value<int> sourceSnapshotVersion = const Value.absent(),
                Value<String> sourceSnapshotJson = const Value.absent(),
                Value<String> sourceSha256 = const Value.absent(),
                Value<PastAnchorState> anchorState = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PastEventsCompanion(
                id: id,
                documentId: documentId,
                sourceTaskId: sourceTaskId,
                appendSequence: appendSequence,
                completedAtUtc: completedAtUtc,
                completionLocalDate: completionLocalDate,
                completionZoneId: completionZoneId,
                sourceSnapshotVersion: sourceSnapshotVersion,
                sourceSnapshotJson: sourceSnapshotJson,
                sourceSha256: sourceSha256,
                anchorState: anchorState,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String documentId,
                required String sourceTaskId,
                required int appendSequence,
                required int completedAtUtc,
                required String completionLocalDate,
                required String completionZoneId,
                Value<int> sourceSnapshotVersion = const Value.absent(),
                required String sourceSnapshotJson,
                required String sourceSha256,
                required PastAnchorState anchorState,
                required int createdAtUtc,
                required int updatedAtUtc,
                Value<int> rowVersion = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PastEventsCompanion.insert(
                id: id,
                documentId: documentId,
                sourceTaskId: sourceTaskId,
                appendSequence: appendSequence,
                completedAtUtc: completedAtUtc,
                completionLocalDate: completionLocalDate,
                completionZoneId: completionZoneId,
                sourceSnapshotVersion: sourceSnapshotVersion,
                sourceSnapshotJson: sourceSnapshotJson,
                sourceSha256: sourceSha256,
                anchorState: anchorState,
                createdAtUtc: createdAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowVersion: rowVersion,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PastEventsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({documentId = false, pastEventPartsRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pastEventPartsRefs) db.pastEventParts,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (documentId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.documentId,
                            referencedTable: $$PastEventsTableReferences
                                ._documentIdTable(db),
                            referencedColumn: $$PastEventsTableReferences
                                ._documentIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pastEventPartsRefs)
                        await $_getPrefetchedData<
                          PastEventRow,
                          $PastEventsTable,
                          PastEventPartRow
                        >(
                          currentTable: table,
                          referencedTable: $$PastEventsTableReferences
                              ._pastEventPartsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PastEventsTableReferences(
                                db,
                                table,
                                p0,
                              ).pastEventPartsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.eventId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PastEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $PastEventsTable,
      PastEventRow,
      $$PastEventsTableFilterComposer,
      $$PastEventsTableOrderingComposer,
      $$PastEventsTableAnnotationComposer,
      $$PastEventsTableCreateCompanionBuilder,
      $$PastEventsTableUpdateCompanionBuilder,
      (PastEventRow, $$PastEventsTableReferences),
      PastEventRow,
      PrefetchHooks Function({bool documentId, bool pastEventPartsRefs})
    >;
typedef $$PastEventPartsTableCreateCompanionBuilder =
    PastEventPartsCompanion Function({
      required String id,
      required String eventId,
      required PastPartRole role,
      required int sourceOrder,
      required String originalPayloadJson,
      required String originalPlainText,
      required String originalSha256,
      Value<int> rowid,
    });
typedef $$PastEventPartsTableUpdateCompanionBuilder =
    PastEventPartsCompanion Function({
      Value<String> id,
      Value<String> eventId,
      Value<PastPartRole> role,
      Value<int> sourceOrder,
      Value<String> originalPayloadJson,
      Value<String> originalPlainText,
      Value<String> originalSha256,
      Value<int> rowid,
    });

final class $$PastEventPartsTableReferences
    extends
        BaseReferences<
          _$DangguiDatabase,
          $PastEventPartsTable,
          PastEventPartRow
        > {
  $$PastEventPartsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PastEventsTable _eventIdTable(_$DangguiDatabase db) =>
      db.pastEvents.createAlias('past_event_parts__event_id__past_events__id');

  $$PastEventsTableProcessedTableManager get eventId {
    final $_column = $_itemColumn<String>('event_id')!;

    final manager = $$PastEventsTableTableManager(
      $_db,
      $_db.pastEvents,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_eventIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$PastAnchorLinksTable, List<PastAnchorLinkRow>>
  _pastAnchorLinksRefsTable(_$DangguiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.pastAnchorLinks,
        aliasName: 'past_event_parts__id__past_anchor_links__part_id',
      );

  $$PastAnchorLinksTableProcessedTableManager get pastAnchorLinksRefs {
    final manager = $$PastAnchorLinksTableTableManager(
      $_db,
      $_db.pastAnchorLinks,
    ).filter((f) => f.partId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _pastAnchorLinksRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$PastEventPartsTableFilterComposer
    extends Composer<_$DangguiDatabase, $PastEventPartsTable> {
  $$PastEventPartsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<PastPartRole, PastPartRole, String> get role =>
      $composableBuilder(
        column: $table.role,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<int> get sourceOrder => $composableBuilder(
    column: $table.sourceOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalPayloadJson => $composableBuilder(
    column: $table.originalPayloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalPlainText => $composableBuilder(
    column: $table.originalPlainText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originalSha256 => $composableBuilder(
    column: $table.originalSha256,
    builder: (column) => ColumnFilters(column),
  );

  $$PastEventsTableFilterComposer get eventId {
    final $$PastEventsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.pastEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventsTableFilterComposer(
            $db: $db,
            $table: $db.pastEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> pastAnchorLinksRefs(
    Expression<bool> Function($$PastAnchorLinksTableFilterComposer f) f,
  ) {
    final $$PastAnchorLinksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pastAnchorLinks,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastAnchorLinksTableFilterComposer(
            $db: $db,
            $table: $db.pastAnchorLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PastEventPartsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $PastEventPartsTable> {
  $$PastEventPartsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceOrder => $composableBuilder(
    column: $table.sourceOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalPayloadJson => $composableBuilder(
    column: $table.originalPayloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalPlainText => $composableBuilder(
    column: $table.originalPlainText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originalSha256 => $composableBuilder(
    column: $table.originalSha256,
    builder: (column) => ColumnOrderings(column),
  );

  $$PastEventsTableOrderingComposer get eventId {
    final $$PastEventsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.pastEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventsTableOrderingComposer(
            $db: $db,
            $table: $db.pastEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PastEventPartsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $PastEventPartsTable> {
  $$PastEventPartsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<PastPartRole, String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get sourceOrder => $composableBuilder(
    column: $table.sourceOrder,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalPayloadJson => $composableBuilder(
    column: $table.originalPayloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalPlainText => $composableBuilder(
    column: $table.originalPlainText,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originalSha256 => $composableBuilder(
    column: $table.originalSha256,
    builder: (column) => column,
  );

  $$PastEventsTableAnnotationComposer get eventId {
    final $$PastEventsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.eventId,
      referencedTable: $db.pastEvents,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventsTableAnnotationComposer(
            $db: $db,
            $table: $db.pastEvents,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> pastAnchorLinksRefs<T extends Object>(
    Expression<T> Function($$PastAnchorLinksTableAnnotationComposer a) f,
  ) {
    final $$PastAnchorLinksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.pastAnchorLinks,
      getReferencedColumn: (t) => t.partId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastAnchorLinksTableAnnotationComposer(
            $db: $db,
            $table: $db.pastAnchorLinks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$PastEventPartsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $PastEventPartsTable,
          PastEventPartRow,
          $$PastEventPartsTableFilterComposer,
          $$PastEventPartsTableOrderingComposer,
          $$PastEventPartsTableAnnotationComposer,
          $$PastEventPartsTableCreateCompanionBuilder,
          $$PastEventPartsTableUpdateCompanionBuilder,
          (PastEventPartRow, $$PastEventPartsTableReferences),
          PastEventPartRow,
          PrefetchHooks Function({bool eventId, bool pastAnchorLinksRefs})
        > {
  $$PastEventPartsTableTableManager(
    _$DangguiDatabase db,
    $PastEventPartsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PastEventPartsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PastEventPartsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PastEventPartsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> eventId = const Value.absent(),
                Value<PastPartRole> role = const Value.absent(),
                Value<int> sourceOrder = const Value.absent(),
                Value<String> originalPayloadJson = const Value.absent(),
                Value<String> originalPlainText = const Value.absent(),
                Value<String> originalSha256 = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PastEventPartsCompanion(
                id: id,
                eventId: eventId,
                role: role,
                sourceOrder: sourceOrder,
                originalPayloadJson: originalPayloadJson,
                originalPlainText: originalPlainText,
                originalSha256: originalSha256,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String eventId,
                required PastPartRole role,
                required int sourceOrder,
                required String originalPayloadJson,
                required String originalPlainText,
                required String originalSha256,
                Value<int> rowid = const Value.absent(),
              }) => PastEventPartsCompanion.insert(
                id: id,
                eventId: eventId,
                role: role,
                sourceOrder: sourceOrder,
                originalPayloadJson: originalPayloadJson,
                originalPlainText: originalPlainText,
                originalSha256: originalSha256,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PastEventPartsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({eventId = false, pastAnchorLinksRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (pastAnchorLinksRefs) db.pastAnchorLinks,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (eventId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.eventId,
                            referencedTable: $$PastEventPartsTableReferences
                                ._eventIdTable(db),
                            referencedColumn: $$PastEventPartsTableReferences
                                ._eventIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (pastAnchorLinksRefs)
                        await $_getPrefetchedData<
                          PastEventPartRow,
                          $PastEventPartsTable,
                          PastAnchorLinkRow
                        >(
                          currentTable: table,
                          referencedTable: $$PastEventPartsTableReferences
                              ._pastAnchorLinksRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$PastEventPartsTableReferences(
                                db,
                                table,
                                p0,
                              ).pastAnchorLinksRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.partId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$PastEventPartsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $PastEventPartsTable,
      PastEventPartRow,
      $$PastEventPartsTableFilterComposer,
      $$PastEventPartsTableOrderingComposer,
      $$PastEventPartsTableAnnotationComposer,
      $$PastEventPartsTableCreateCompanionBuilder,
      $$PastEventPartsTableUpdateCompanionBuilder,
      (PastEventPartRow, $$PastEventPartsTableReferences),
      PastEventPartRow,
      PrefetchHooks Function({bool eventId, bool pastAnchorLinksRefs})
    >;
typedef $$PastAnchorLinksTableCreateCompanionBuilder =
    PastAnchorLinksCompanion Function({
      required String id,
      required String partId,
      Value<String?> currentBlockId,
      required String lastKnownBlockId,
      required AnchorRelation relation,
      required AnchorLinkState linkState,
      Value<String?> currentSha256,
      required int updatedAtUtc,
      Value<int> rowid,
    });
typedef $$PastAnchorLinksTableUpdateCompanionBuilder =
    PastAnchorLinksCompanion Function({
      Value<String> id,
      Value<String> partId,
      Value<String?> currentBlockId,
      Value<String> lastKnownBlockId,
      Value<AnchorRelation> relation,
      Value<AnchorLinkState> linkState,
      Value<String?> currentSha256,
      Value<int> updatedAtUtc,
      Value<int> rowid,
    });

final class $$PastAnchorLinksTableReferences
    extends
        BaseReferences<
          _$DangguiDatabase,
          $PastAnchorLinksTable,
          PastAnchorLinkRow
        > {
  $$PastAnchorLinksTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $PastEventPartsTable _partIdTable(_$DangguiDatabase db) => db
      .pastEventParts
      .createAlias('past_anchor_links__part_id__past_event_parts__id');

  $$PastEventPartsTableProcessedTableManager get partId {
    final $_column = $_itemColumn<String>('part_id')!;

    final manager = $$PastEventPartsTableTableManager(
      $_db,
      $_db.pastEventParts,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_partIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $DocumentBlocksTable _currentBlockIdTable(_$DangguiDatabase db) => db
      .documentBlocks
      .createAlias('past_anchor_links__current_block_id__document_blocks__id');

  $$DocumentBlocksTableProcessedTableManager? get currentBlockId {
    final $_column = $_itemColumn<String>('current_block_id');
    if ($_column == null) return null;
    final manager = $$DocumentBlocksTableTableManager(
      $_db,
      $_db.documentBlocks,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_currentBlockIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$PastAnchorLinksTableFilterComposer
    extends Composer<_$DangguiDatabase, $PastAnchorLinksTable> {
  $$PastAnchorLinksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastKnownBlockId => $composableBuilder(
    column: $table.lastKnownBlockId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<AnchorRelation, AnchorRelation, String>
  get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<AnchorLinkState, AnchorLinkState, String>
  get linkState => $composableBuilder(
    column: $table.linkState,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<String> get currentSha256 => $composableBuilder(
    column: $table.currentSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$PastEventPartsTableFilterComposer get partId {
    final $$PastEventPartsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.pastEventParts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventPartsTableFilterComposer(
            $db: $db,
            $table: $db.pastEventParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DocumentBlocksTableFilterComposer get currentBlockId {
    final $$DocumentBlocksTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentBlockId,
      referencedTable: $db.documentBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentBlocksTableFilterComposer(
            $db: $db,
            $table: $db.documentBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PastAnchorLinksTableOrderingComposer
    extends Composer<_$DangguiDatabase, $PastAnchorLinksTable> {
  $$PastAnchorLinksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastKnownBlockId => $composableBuilder(
    column: $table.lastKnownBlockId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkState => $composableBuilder(
    column: $table.linkState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentSha256 => $composableBuilder(
    column: $table.currentSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$PastEventPartsTableOrderingComposer get partId {
    final $$PastEventPartsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.pastEventParts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventPartsTableOrderingComposer(
            $db: $db,
            $table: $db.pastEventParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DocumentBlocksTableOrderingComposer get currentBlockId {
    final $$DocumentBlocksTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentBlockId,
      referencedTable: $db.documentBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentBlocksTableOrderingComposer(
            $db: $db,
            $table: $db.documentBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PastAnchorLinksTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $PastAnchorLinksTable> {
  $$PastAnchorLinksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get lastKnownBlockId => $composableBuilder(
    column: $table.lastKnownBlockId,
    builder: (column) => column,
  );

  GeneratedColumnWithTypeConverter<AnchorRelation, String> get relation =>
      $composableBuilder(column: $table.relation, builder: (column) => column);

  GeneratedColumnWithTypeConverter<AnchorLinkState, String> get linkState =>
      $composableBuilder(column: $table.linkState, builder: (column) => column);

  GeneratedColumn<String> get currentSha256 => $composableBuilder(
    column: $table.currentSha256,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  $$PastEventPartsTableAnnotationComposer get partId {
    final $$PastEventPartsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.partId,
      referencedTable: $db.pastEventParts,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$PastEventPartsTableAnnotationComposer(
            $db: $db,
            $table: $db.pastEventParts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$DocumentBlocksTableAnnotationComposer get currentBlockId {
    final $$DocumentBlocksTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.currentBlockId,
      referencedTable: $db.documentBlocks,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$DocumentBlocksTableAnnotationComposer(
            $db: $db,
            $table: $db.documentBlocks,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$PastAnchorLinksTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $PastAnchorLinksTable,
          PastAnchorLinkRow,
          $$PastAnchorLinksTableFilterComposer,
          $$PastAnchorLinksTableOrderingComposer,
          $$PastAnchorLinksTableAnnotationComposer,
          $$PastAnchorLinksTableCreateCompanionBuilder,
          $$PastAnchorLinksTableUpdateCompanionBuilder,
          (PastAnchorLinkRow, $$PastAnchorLinksTableReferences),
          PastAnchorLinkRow,
          PrefetchHooks Function({bool partId, bool currentBlockId})
        > {
  $$PastAnchorLinksTableTableManager(
    _$DangguiDatabase db,
    $PastAnchorLinksTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PastAnchorLinksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PastAnchorLinksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PastAnchorLinksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> partId = const Value.absent(),
                Value<String?> currentBlockId = const Value.absent(),
                Value<String> lastKnownBlockId = const Value.absent(),
                Value<AnchorRelation> relation = const Value.absent(),
                Value<AnchorLinkState> linkState = const Value.absent(),
                Value<String?> currentSha256 = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PastAnchorLinksCompanion(
                id: id,
                partId: partId,
                currentBlockId: currentBlockId,
                lastKnownBlockId: lastKnownBlockId,
                relation: relation,
                linkState: linkState,
                currentSha256: currentSha256,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String partId,
                Value<String?> currentBlockId = const Value.absent(),
                required String lastKnownBlockId,
                required AnchorRelation relation,
                required AnchorLinkState linkState,
                Value<String?> currentSha256 = const Value.absent(),
                required int updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => PastAnchorLinksCompanion.insert(
                id: id,
                partId: partId,
                currentBlockId: currentBlockId,
                lastKnownBlockId: lastKnownBlockId,
                relation: relation,
                linkState: linkState,
                currentSha256: currentSha256,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$PastAnchorLinksTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({partId = false, currentBlockId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (partId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.partId,
                        referencedTable: $$PastAnchorLinksTableReferences
                            ._partIdTable(db),
                        referencedColumn: $$PastAnchorLinksTableReferences
                            ._partIdTable(db)
                            .id,
                      ) as T;
                    }
                    if (currentBlockId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.currentBlockId,
                        referencedTable: $$PastAnchorLinksTableReferences
                            ._currentBlockIdTable(db),
                        referencedColumn: $$PastAnchorLinksTableReferences
                            ._currentBlockIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$PastAnchorLinksTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $PastAnchorLinksTable,
      PastAnchorLinkRow,
      $$PastAnchorLinksTableFilterComposer,
      $$PastAnchorLinksTableOrderingComposer,
      $$PastAnchorLinksTableAnnotationComposer,
      $$PastAnchorLinksTableCreateCompanionBuilder,
      $$PastAnchorLinksTableUpdateCompanionBuilder,
      (PastAnchorLinkRow, $$PastAnchorLinksTableReferences),
      PastAnchorLinkRow,
      PrefetchHooks Function({bool partId, bool currentBlockId})
    >;
typedef $$SearchRecordsTableCreateCompanionBuilder =
    SearchRecordsCompanion Function({
      Value<int> rowId,
      required SearchScope scope,
      required String entityId,
      Value<String?> documentId,
      Value<String> titleNorm,
      Value<String> bodyNorm,
      Value<String> dateKey,
      required int updatedAtUtc,
    });
typedef $$SearchRecordsTableUpdateCompanionBuilder =
    SearchRecordsCompanion Function({
      Value<int> rowId,
      Value<SearchScope> scope,
      Value<String> entityId,
      Value<String?> documentId,
      Value<String> titleNorm,
      Value<String> bodyNorm,
      Value<String> dateKey,
      Value<int> updatedAtUtc,
    });

class $$SearchRecordsTableFilterComposer
    extends Composer<_$DangguiDatabase, $SearchRecordsTable> {
  $$SearchRecordsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<SearchScope, SearchScope, String> get scope =>
      $composableBuilder(
        column: $table.scope,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get titleNorm => $composableBuilder(
    column: $table.titleNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get bodyNorm => $composableBuilder(
    column: $table.bodyNorm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SearchRecordsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $SearchRecordsTable> {
  $$SearchRecordsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get rowId => $composableBuilder(
    column: $table.rowId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get scope => $composableBuilder(
    column: $table.scope,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get titleNorm => $composableBuilder(
    column: $table.titleNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get bodyNorm => $composableBuilder(
    column: $table.bodyNorm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dateKey => $composableBuilder(
    column: $table.dateKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SearchRecordsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $SearchRecordsTable> {
  $$SearchRecordsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get rowId =>
      $composableBuilder(column: $table.rowId, builder: (column) => column);

  GeneratedColumnWithTypeConverter<SearchScope, String> get scope =>
      $composableBuilder(column: $table.scope, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get documentId => $composableBuilder(
    column: $table.documentId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get titleNorm =>
      $composableBuilder(column: $table.titleNorm, builder: (column) => column);

  GeneratedColumn<String> get bodyNorm =>
      $composableBuilder(column: $table.bodyNorm, builder: (column) => column);

  GeneratedColumn<String> get dateKey =>
      $composableBuilder(column: $table.dateKey, builder: (column) => column);

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );
}

class $$SearchRecordsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $SearchRecordsTable,
          SearchRecordRow,
          $$SearchRecordsTableFilterComposer,
          $$SearchRecordsTableOrderingComposer,
          $$SearchRecordsTableAnnotationComposer,
          $$SearchRecordsTableCreateCompanionBuilder,
          $$SearchRecordsTableUpdateCompanionBuilder,
          (
            SearchRecordRow,
            BaseReferences<
              _$DangguiDatabase,
              $SearchRecordsTable,
              SearchRecordRow
            >,
          ),
          SearchRecordRow,
          PrefetchHooks Function()
        > {
  $$SearchRecordsTableTableManager(
    _$DangguiDatabase db,
    $SearchRecordsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SearchRecordsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SearchRecordsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SearchRecordsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                Value<SearchScope> scope = const Value.absent(),
                Value<String> entityId = const Value.absent(),
                Value<String?> documentId = const Value.absent(),
                Value<String> titleNorm = const Value.absent(),
                Value<String> bodyNorm = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
              }) => SearchRecordsCompanion(
                rowId: rowId,
                scope: scope,
                entityId: entityId,
                documentId: documentId,
                titleNorm: titleNorm,
                bodyNorm: bodyNorm,
                dateKey: dateKey,
                updatedAtUtc: updatedAtUtc,
              ),
          createCompanionCallback:
              ({
                Value<int> rowId = const Value.absent(),
                required SearchScope scope,
                required String entityId,
                Value<String?> documentId = const Value.absent(),
                Value<String> titleNorm = const Value.absent(),
                Value<String> bodyNorm = const Value.absent(),
                Value<String> dateKey = const Value.absent(),
                required int updatedAtUtc,
              }) => SearchRecordsCompanion.insert(
                rowId: rowId,
                scope: scope,
                entityId: entityId,
                documentId: documentId,
                titleNorm: titleNorm,
                bodyNorm: bodyNorm,
                dateKey: dateKey,
                updatedAtUtc: updatedAtUtc,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SearchRecordsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $SearchRecordsTable,
      SearchRecordRow,
      $$SearchRecordsTableFilterComposer,
      $$SearchRecordsTableOrderingComposer,
      $$SearchRecordsTableAnnotationComposer,
      $$SearchRecordsTableCreateCompanionBuilder,
      $$SearchRecordsTableUpdateCompanionBuilder,
      (
        SearchRecordRow,
        BaseReferences<_$DangguiDatabase, $SearchRecordsTable, SearchRecordRow>,
      ),
      SearchRecordRow,
      PrefetchHooks Function()
    >;
typedef $$BackupTargetsTableCreateCompanionBuilder =
    BackupTargetsCompanion Function({
      required String id,
      required String platform,
      required String displayName,
      Value<String?> locatorText,
      Value<Uint8List?> locatorBlob,
      required String permissionState,
      required bool isDefault,
      Value<int?> grantedAtUtc,
      Value<int?> lastVerifiedAtUtc,
      required int updatedAtUtc,
      Value<int> rowid,
    });
typedef $$BackupTargetsTableUpdateCompanionBuilder =
    BackupTargetsCompanion Function({
      Value<String> id,
      Value<String> platform,
      Value<String> displayName,
      Value<String?> locatorText,
      Value<Uint8List?> locatorBlob,
      Value<String> permissionState,
      Value<bool> isDefault,
      Value<int?> grantedAtUtc,
      Value<int?> lastVerifiedAtUtc,
      Value<int> updatedAtUtc,
      Value<int> rowid,
    });

final class $$BackupTargetsTableReferences
    extends
        BaseReferences<
          _$DangguiDatabase,
          $BackupTargetsTable,
          BackupTargetRow
        > {
  $$BackupTargetsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$BackupRunsTable, List<BackupRunRow>>
  _backupRunsRefsTable(_$DangguiDatabase db) => MultiTypedResultKey.fromTable(
    db.backupRuns,
    aliasName: 'backup_targets__id__backup_runs__target_id',
  );

  $$BackupRunsTableProcessedTableManager get backupRunsRefs {
    final manager = $$BackupRunsTableTableManager(
      $_db,
      $_db.backupRuns,
    ).filter((f) => f.targetId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_backupRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BackupTargetsTableFilterComposer
    extends Composer<_$DangguiDatabase, $BackupTargetsTable> {
  $$BackupTargetsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get locatorText => $composableBuilder(
    column: $table.locatorText,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get locatorBlob => $composableBuilder(
    column: $table.locatorBlob,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get permissionState => $composableBuilder(
    column: $table.permissionState,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get grantedAtUtc => $composableBuilder(
    column: $table.grantedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastVerifiedAtUtc => $composableBuilder(
    column: $table.lastVerifiedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> backupRunsRefs(
    Expression<bool> Function($$BackupRunsTableFilterComposer f) f,
  ) {
    final $$BackupRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.backupRuns,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupRunsTableFilterComposer(
            $db: $db,
            $table: $db.backupRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BackupTargetsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $BackupTargetsTable> {
  $$BackupTargetsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platform => $composableBuilder(
    column: $table.platform,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get locatorText => $composableBuilder(
    column: $table.locatorText,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get locatorBlob => $composableBuilder(
    column: $table.locatorBlob,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get permissionState => $composableBuilder(
    column: $table.permissionState,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDefault => $composableBuilder(
    column: $table.isDefault,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get grantedAtUtc => $composableBuilder(
    column: $table.grantedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastVerifiedAtUtc => $composableBuilder(
    column: $table.lastVerifiedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupTargetsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $BackupTargetsTable> {
  $$BackupTargetsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get platform =>
      $composableBuilder(column: $table.platform, builder: (column) => column);

  GeneratedColumn<String> get displayName => $composableBuilder(
    column: $table.displayName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get locatorText => $composableBuilder(
    column: $table.locatorText,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get locatorBlob => $composableBuilder(
    column: $table.locatorBlob,
    builder: (column) => column,
  );

  GeneratedColumn<String> get permissionState => $composableBuilder(
    column: $table.permissionState,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDefault =>
      $composableBuilder(column: $table.isDefault, builder: (column) => column);

  GeneratedColumn<int> get grantedAtUtc => $composableBuilder(
    column: $table.grantedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastVerifiedAtUtc => $composableBuilder(
    column: $table.lastVerifiedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtUtc => $composableBuilder(
    column: $table.updatedAtUtc,
    builder: (column) => column,
  );

  Expression<T> backupRunsRefs<T extends Object>(
    Expression<T> Function($$BackupRunsTableAnnotationComposer a) f,
  ) {
    final $$BackupRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.backupRuns,
      getReferencedColumn: (t) => t.targetId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.backupRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BackupTargetsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $BackupTargetsTable,
          BackupTargetRow,
          $$BackupTargetsTableFilterComposer,
          $$BackupTargetsTableOrderingComposer,
          $$BackupTargetsTableAnnotationComposer,
          $$BackupTargetsTableCreateCompanionBuilder,
          $$BackupTargetsTableUpdateCompanionBuilder,
          (BackupTargetRow, $$BackupTargetsTableReferences),
          BackupTargetRow,
          PrefetchHooks Function({bool backupRunsRefs})
        > {
  $$BackupTargetsTableTableManager(
    _$DangguiDatabase db,
    $BackupTargetsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupTargetsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupTargetsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupTargetsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> platform = const Value.absent(),
                Value<String> displayName = const Value.absent(),
                Value<String?> locatorText = const Value.absent(),
                Value<Uint8List?> locatorBlob = const Value.absent(),
                Value<String> permissionState = const Value.absent(),
                Value<bool> isDefault = const Value.absent(),
                Value<int?> grantedAtUtc = const Value.absent(),
                Value<int?> lastVerifiedAtUtc = const Value.absent(),
                Value<int> updatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupTargetsCompanion(
                id: id,
                platform: platform,
                displayName: displayName,
                locatorText: locatorText,
                locatorBlob: locatorBlob,
                permissionState: permissionState,
                isDefault: isDefault,
                grantedAtUtc: grantedAtUtc,
                lastVerifiedAtUtc: lastVerifiedAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String platform,
                required String displayName,
                Value<String?> locatorText = const Value.absent(),
                Value<Uint8List?> locatorBlob = const Value.absent(),
                required String permissionState,
                required bool isDefault,
                Value<int?> grantedAtUtc = const Value.absent(),
                Value<int?> lastVerifiedAtUtc = const Value.absent(),
                required int updatedAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => BackupTargetsCompanion.insert(
                id: id,
                platform: platform,
                displayName: displayName,
                locatorText: locatorText,
                locatorBlob: locatorBlob,
                permissionState: permissionState,
                isDefault: isDefault,
                grantedAtUtc: grantedAtUtc,
                lastVerifiedAtUtc: lastVerifiedAtUtc,
                updatedAtUtc: updatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BackupTargetsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({backupRunsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (backupRunsRefs) db.backupRuns],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (backupRunsRefs)
                    await $_getPrefetchedData<
                      BackupTargetRow,
                      $BackupTargetsTable,
                      BackupRunRow
                    >(
                      currentTable: table,
                      referencedTable: $$BackupTargetsTableReferences
                          ._backupRunsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BackupTargetsTableReferences(
                            db,
                            table,
                            p0,
                          ).backupRunsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.targetId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BackupTargetsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $BackupTargetsTable,
      BackupTargetRow,
      $$BackupTargetsTableFilterComposer,
      $$BackupTargetsTableOrderingComposer,
      $$BackupTargetsTableAnnotationComposer,
      $$BackupTargetsTableCreateCompanionBuilder,
      $$BackupTargetsTableUpdateCompanionBuilder,
      (BackupTargetRow, $$BackupTargetsTableReferences),
      BackupTargetRow,
      PrefetchHooks Function({bool backupRunsRefs})
    >;
typedef $$BackupEncryptionProfilesTableCreateCompanionBuilder =
    BackupEncryptionProfilesCompanion Function({
      required String id,
      Value<String> kdf,
      Value<int> kdfMemoryKib,
      Value<int> kdfIterations,
      Value<int> kdfParallelism,
      required Uint8List kdfSalt,
      required Uint8List passwordEnvelopeNonce,
      required Uint8List wrappedMasterKey,
      required Uint8List wrappedMasterKeyMac,
      Value<String?> platformKeyAlias,
      required int createdAtUtc,
      Value<int?> rotatedAtUtc,
      Value<int> rowid,
    });
typedef $$BackupEncryptionProfilesTableUpdateCompanionBuilder =
    BackupEncryptionProfilesCompanion Function({
      Value<String> id,
      Value<String> kdf,
      Value<int> kdfMemoryKib,
      Value<int> kdfIterations,
      Value<int> kdfParallelism,
      Value<Uint8List> kdfSalt,
      Value<Uint8List> passwordEnvelopeNonce,
      Value<Uint8List> wrappedMasterKey,
      Value<Uint8List> wrappedMasterKeyMac,
      Value<String?> platformKeyAlias,
      Value<int> createdAtUtc,
      Value<int?> rotatedAtUtc,
      Value<int> rowid,
    });

final class $$BackupEncryptionProfilesTableReferences
    extends
        BaseReferences<
          _$DangguiDatabase,
          $BackupEncryptionProfilesTable,
          BackupEncryptionProfileRow
        > {
  $$BackupEncryptionProfilesTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$BackupRunsTable, List<BackupRunRow>>
  _backupRunsRefsTable(_$DangguiDatabase db) => MultiTypedResultKey.fromTable(
    db.backupRuns,
    aliasName:
        'backup_encryption_profiles__id__backup_runs__encryption_profile_id',
  );

  $$BackupRunsTableProcessedTableManager get backupRunsRefs {
    final manager = $$BackupRunsTableTableManager($_db, $_db.backupRuns).filter(
      (f) => f.encryptionProfileId.id.sqlEquals($_itemColumn<String>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_backupRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BackupEncryptionProfilesTableFilterComposer
    extends Composer<_$DangguiDatabase, $BackupEncryptionProfilesTable> {
  $$BackupEncryptionProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kdf => $composableBuilder(
    column: $table.kdf,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kdfMemoryKib => $composableBuilder(
    column: $table.kdfMemoryKib,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kdfIterations => $composableBuilder(
    column: $table.kdfIterations,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get kdfParallelism => $composableBuilder(
    column: $table.kdfParallelism,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get kdfSalt => $composableBuilder(
    column: $table.kdfSalt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get passwordEnvelopeNonce => $composableBuilder(
    column: $table.passwordEnvelopeNonce,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get wrappedMasterKey => $composableBuilder(
    column: $table.wrappedMasterKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get wrappedMasterKeyMac => $composableBuilder(
    column: $table.wrappedMasterKeyMac,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get platformKeyAlias => $composableBuilder(
    column: $table.platformKeyAlias,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get rotatedAtUtc => $composableBuilder(
    column: $table.rotatedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> backupRunsRefs(
    Expression<bool> Function($$BackupRunsTableFilterComposer f) f,
  ) {
    final $$BackupRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.backupRuns,
      getReferencedColumn: (t) => t.encryptionProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupRunsTableFilterComposer(
            $db: $db,
            $table: $db.backupRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BackupEncryptionProfilesTableOrderingComposer
    extends Composer<_$DangguiDatabase, $BackupEncryptionProfilesTable> {
  $$BackupEncryptionProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kdf => $composableBuilder(
    column: $table.kdf,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kdfMemoryKib => $composableBuilder(
    column: $table.kdfMemoryKib,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kdfIterations => $composableBuilder(
    column: $table.kdfIterations,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get kdfParallelism => $composableBuilder(
    column: $table.kdfParallelism,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get kdfSalt => $composableBuilder(
    column: $table.kdfSalt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get passwordEnvelopeNonce => $composableBuilder(
    column: $table.passwordEnvelopeNonce,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get wrappedMasterKey => $composableBuilder(
    column: $table.wrappedMasterKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get wrappedMasterKeyMac => $composableBuilder(
    column: $table.wrappedMasterKeyMac,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get platformKeyAlias => $composableBuilder(
    column: $table.platformKeyAlias,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get rotatedAtUtc => $composableBuilder(
    column: $table.rotatedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BackupEncryptionProfilesTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $BackupEncryptionProfilesTable> {
  $$BackupEncryptionProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kdf =>
      $composableBuilder(column: $table.kdf, builder: (column) => column);

  GeneratedColumn<int> get kdfMemoryKib => $composableBuilder(
    column: $table.kdfMemoryKib,
    builder: (column) => column,
  );

  GeneratedColumn<int> get kdfIterations => $composableBuilder(
    column: $table.kdfIterations,
    builder: (column) => column,
  );

  GeneratedColumn<int> get kdfParallelism => $composableBuilder(
    column: $table.kdfParallelism,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get kdfSalt =>
      $composableBuilder(column: $table.kdfSalt, builder: (column) => column);

  GeneratedColumn<Uint8List> get passwordEnvelopeNonce => $composableBuilder(
    column: $table.passwordEnvelopeNonce,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get wrappedMasterKey => $composableBuilder(
    column: $table.wrappedMasterKey,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get wrappedMasterKeyMac => $composableBuilder(
    column: $table.wrappedMasterKeyMac,
    builder: (column) => column,
  );

  GeneratedColumn<String> get platformKeyAlias => $composableBuilder(
    column: $table.platformKeyAlias,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get rotatedAtUtc => $composableBuilder(
    column: $table.rotatedAtUtc,
    builder: (column) => column,
  );

  Expression<T> backupRunsRefs<T extends Object>(
    Expression<T> Function($$BackupRunsTableAnnotationComposer a) f,
  ) {
    final $$BackupRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.backupRuns,
      getReferencedColumn: (t) => t.encryptionProfileId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.backupRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BackupEncryptionProfilesTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $BackupEncryptionProfilesTable,
          BackupEncryptionProfileRow,
          $$BackupEncryptionProfilesTableFilterComposer,
          $$BackupEncryptionProfilesTableOrderingComposer,
          $$BackupEncryptionProfilesTableAnnotationComposer,
          $$BackupEncryptionProfilesTableCreateCompanionBuilder,
          $$BackupEncryptionProfilesTableUpdateCompanionBuilder,
          (
            BackupEncryptionProfileRow,
            $$BackupEncryptionProfilesTableReferences,
          ),
          BackupEncryptionProfileRow,
          PrefetchHooks Function({bool backupRunsRefs})
        > {
  $$BackupEncryptionProfilesTableTableManager(
    _$DangguiDatabase db,
    $BackupEncryptionProfilesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupEncryptionProfilesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$BackupEncryptionProfilesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$BackupEncryptionProfilesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> kdf = const Value.absent(),
                Value<int> kdfMemoryKib = const Value.absent(),
                Value<int> kdfIterations = const Value.absent(),
                Value<int> kdfParallelism = const Value.absent(),
                Value<Uint8List> kdfSalt = const Value.absent(),
                Value<Uint8List> passwordEnvelopeNonce = const Value.absent(),
                Value<Uint8List> wrappedMasterKey = const Value.absent(),
                Value<Uint8List> wrappedMasterKeyMac = const Value.absent(),
                Value<String?> platformKeyAlias = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int?> rotatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupEncryptionProfilesCompanion(
                id: id,
                kdf: kdf,
                kdfMemoryKib: kdfMemoryKib,
                kdfIterations: kdfIterations,
                kdfParallelism: kdfParallelism,
                kdfSalt: kdfSalt,
                passwordEnvelopeNonce: passwordEnvelopeNonce,
                wrappedMasterKey: wrappedMasterKey,
                wrappedMasterKeyMac: wrappedMasterKeyMac,
                platformKeyAlias: platformKeyAlias,
                createdAtUtc: createdAtUtc,
                rotatedAtUtc: rotatedAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String> kdf = const Value.absent(),
                Value<int> kdfMemoryKib = const Value.absent(),
                Value<int> kdfIterations = const Value.absent(),
                Value<int> kdfParallelism = const Value.absent(),
                required Uint8List kdfSalt,
                required Uint8List passwordEnvelopeNonce,
                required Uint8List wrappedMasterKey,
                required Uint8List wrappedMasterKeyMac,
                Value<String?> platformKeyAlias = const Value.absent(),
                required int createdAtUtc,
                Value<int?> rotatedAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupEncryptionProfilesCompanion.insert(
                id: id,
                kdf: kdf,
                kdfMemoryKib: kdfMemoryKib,
                kdfIterations: kdfIterations,
                kdfParallelism: kdfParallelism,
                kdfSalt: kdfSalt,
                passwordEnvelopeNonce: passwordEnvelopeNonce,
                wrappedMasterKey: wrappedMasterKey,
                wrappedMasterKeyMac: wrappedMasterKeyMac,
                platformKeyAlias: platformKeyAlias,
                createdAtUtc: createdAtUtc,
                rotatedAtUtc: rotatedAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BackupEncryptionProfilesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({backupRunsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (backupRunsRefs) db.backupRuns],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (backupRunsRefs)
                    await $_getPrefetchedData<
                      BackupEncryptionProfileRow,
                      $BackupEncryptionProfilesTable,
                      BackupRunRow
                    >(
                      currentTable: table,
                      referencedTable: $$BackupEncryptionProfilesTableReferences
                          ._backupRunsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$BackupEncryptionProfilesTableReferences(
                            db,
                            table,
                            p0,
                          ).backupRunsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.encryptionProfileId == item.id,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$BackupEncryptionProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $BackupEncryptionProfilesTable,
      BackupEncryptionProfileRow,
      $$BackupEncryptionProfilesTableFilterComposer,
      $$BackupEncryptionProfilesTableOrderingComposer,
      $$BackupEncryptionProfilesTableAnnotationComposer,
      $$BackupEncryptionProfilesTableCreateCompanionBuilder,
      $$BackupEncryptionProfilesTableUpdateCompanionBuilder,
      (BackupEncryptionProfileRow, $$BackupEncryptionProfilesTableReferences),
      BackupEncryptionProfileRow,
      PrefetchHooks Function({bool backupRunsRefs})
    >;
typedef $$BackupRunsTableCreateCompanionBuilder = BackupRunsCompanion Function({
  required String id,
  Value<String?> targetId,
  Value<String?> encryptionProfileId,
  required String kind,
  required String status,
  Value<String?> archiveName,
  required String appVersion,
  required int databaseSchemaVersion,
  required int manifestVersion,
  Value<String?> recordCountsJson,
  Value<int?> byteLength,
  Value<String?> archiveSha256,
  required int startedAtUtc,
  Value<int?> completedAtUtc,
  Value<String?> errorCode,
  Value<int> rowid,
});
typedef $$BackupRunsTableUpdateCompanionBuilder = BackupRunsCompanion Function({
  Value<String> id,
  Value<String?> targetId,
  Value<String?> encryptionProfileId,
  Value<String> kind,
  Value<String> status,
  Value<String?> archiveName,
  Value<String> appVersion,
  Value<int> databaseSchemaVersion,
  Value<int> manifestVersion,
  Value<String?> recordCountsJson,
  Value<int?> byteLength,
  Value<String?> archiveSha256,
  Value<int> startedAtUtc,
  Value<int?> completedAtUtc,
  Value<String?> errorCode,
  Value<int> rowid,
});

final class $$BackupRunsTableReferences
    extends BaseReferences<_$DangguiDatabase, $BackupRunsTable, BackupRunRow> {
  $$BackupRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BackupTargetsTable _targetIdTable(_$DangguiDatabase db) => db
      .backupTargets
      .createAlias('backup_runs__target_id__backup_targets__id');

  $$BackupTargetsTableProcessedTableManager? get targetId {
    final $_column = $_itemColumn<String>('target_id');
    if ($_column == null) return null;
    final manager = $$BackupTargetsTableTableManager(
      $_db,
      $_db.backupTargets,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_targetIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $BackupEncryptionProfilesTable _encryptionProfileIdTable(
    _$DangguiDatabase db,
  ) => db.backupEncryptionProfiles.createAlias(
    'backup_runs__encryption_profile_id__backup_encryption_profiles__id',
  );

  $$BackupEncryptionProfilesTableProcessedTableManager?
  get encryptionProfileId {
    final $_column = $_itemColumn<String>('encryption_profile_id');
    if ($_column == null) return null;
    final manager = $$BackupEncryptionProfilesTableTableManager(
      $_db,
      $_db.backupEncryptionProfiles,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_encryptionProfileIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RestoreRunsTable, List<RestoreRunRow>>
  _restoreRunsRefsTable(_$DangguiDatabase db) => MultiTypedResultKey.fromTable(
    db.restoreRuns,
    aliasName: 'backup_runs__id__restore_runs__pre_restore_backup_run_id',
  );

  $$RestoreRunsTableProcessedTableManager get restoreRunsRefs {
    final manager = $$RestoreRunsTableTableManager($_db, $_db.restoreRuns)
        .filter(
          (f) =>
              f.preRestoreBackupRunId.id.sqlEquals($_itemColumn<String>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_restoreRunsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$BackupRunsTableFilterComposer
    extends Composer<_$DangguiDatabase, $BackupRunsTable> {
  $$BackupRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archiveName => $composableBuilder(
    column: $table.archiveName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get databaseSchemaVersion => $composableBuilder(
    column: $table.databaseSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manifestVersion => $composableBuilder(
    column: $table.manifestVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recordCountsJson => $composableBuilder(
    column: $table.recordCountsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get archiveSha256 => $composableBuilder(
    column: $table.archiveSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  $$BackupTargetsTableFilterComposer get targetId {
    final $$BackupTargetsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.backupTargets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupTargetsTableFilterComposer(
            $db: $db,
            $table: $db.backupTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BackupEncryptionProfilesTableFilterComposer get encryptionProfileId {
    final $$BackupEncryptionProfilesTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.encryptionProfileId,
          referencedTable: $db.backupEncryptionProfiles,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$BackupEncryptionProfilesTableFilterComposer(
                $db: $db,
                $table: $db.backupEncryptionProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<bool> restoreRunsRefs(
    Expression<bool> Function($$RestoreRunsTableFilterComposer f) f,
  ) {
    final $$RestoreRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.restoreRuns,
      getReferencedColumn: (t) => t.preRestoreBackupRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreRunsTableFilterComposer(
            $db: $db,
            $table: $db.restoreRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BackupRunsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $BackupRunsTable> {
  $$BackupRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archiveName => $composableBuilder(
    column: $table.archiveName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get databaseSchemaVersion => $composableBuilder(
    column: $table.databaseSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manifestVersion => $composableBuilder(
    column: $table.manifestVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recordCountsJson => $composableBuilder(
    column: $table.recordCountsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get archiveSha256 => $composableBuilder(
    column: $table.archiveSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$BackupTargetsTableOrderingComposer get targetId {
    final $$BackupTargetsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.backupTargets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupTargetsTableOrderingComposer(
            $db: $db,
            $table: $db.backupTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BackupEncryptionProfilesTableOrderingComposer get encryptionProfileId {
    final $$BackupEncryptionProfilesTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.encryptionProfileId,
          referencedTable: $db.backupEncryptionProfiles,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$BackupEncryptionProfilesTableOrderingComposer(
                $db: $db,
                $table: $db.backupEncryptionProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }
}

class $$BackupRunsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $BackupRunsTable> {
  $$BackupRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get archiveName => $composableBuilder(
    column: $table.archiveName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get appVersion => $composableBuilder(
    column: $table.appVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get databaseSchemaVersion => $composableBuilder(
    column: $table.databaseSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get manifestVersion => $composableBuilder(
    column: $table.manifestVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get recordCountsJson => $composableBuilder(
    column: $table.recordCountsJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get byteLength => $composableBuilder(
    column: $table.byteLength,
    builder: (column) => column,
  );

  GeneratedColumn<String> get archiveSha256 => $composableBuilder(
    column: $table.archiveSha256,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  $$BackupTargetsTableAnnotationComposer get targetId {
    final $$BackupTargetsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.targetId,
      referencedTable: $db.backupTargets,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupTargetsTableAnnotationComposer(
            $db: $db,
            $table: $db.backupTargets,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$BackupEncryptionProfilesTableAnnotationComposer get encryptionProfileId {
    final $$BackupEncryptionProfilesTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.encryptionProfileId,
          referencedTable: $db.backupEncryptionProfiles,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$BackupEncryptionProfilesTableAnnotationComposer(
                $db: $db,
                $table: $db.backupEncryptionProfiles,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  Expression<T> restoreRunsRefs<T extends Object>(
    Expression<T> Function($$RestoreRunsTableAnnotationComposer a) f,
  ) {
    final $$RestoreRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.restoreRuns,
      getReferencedColumn: (t) => t.preRestoreBackupRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.restoreRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$BackupRunsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $BackupRunsTable,
          BackupRunRow,
          $$BackupRunsTableFilterComposer,
          $$BackupRunsTableOrderingComposer,
          $$BackupRunsTableAnnotationComposer,
          $$BackupRunsTableCreateCompanionBuilder,
          $$BackupRunsTableUpdateCompanionBuilder,
          (BackupRunRow, $$BackupRunsTableReferences),
          BackupRunRow,
          PrefetchHooks Function({
            bool targetId,
            bool encryptionProfileId,
            bool restoreRunsRefs,
          })
        > {
  $$BackupRunsTableTableManager(_$DangguiDatabase db, $BackupRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BackupRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BackupRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BackupRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String?> targetId = const Value.absent(),
                Value<String?> encryptionProfileId = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> archiveName = const Value.absent(),
                Value<String> appVersion = const Value.absent(),
                Value<int> databaseSchemaVersion = const Value.absent(),
                Value<int> manifestVersion = const Value.absent(),
                Value<String?> recordCountsJson = const Value.absent(),
                Value<int?> byteLength = const Value.absent(),
                Value<String?> archiveSha256 = const Value.absent(),
                Value<int> startedAtUtc = const Value.absent(),
                Value<int?> completedAtUtc = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupRunsCompanion(
                id: id,
                targetId: targetId,
                encryptionProfileId: encryptionProfileId,
                kind: kind,
                status: status,
                archiveName: archiveName,
                appVersion: appVersion,
                databaseSchemaVersion: databaseSchemaVersion,
                manifestVersion: manifestVersion,
                recordCountsJson: recordCountsJson,
                byteLength: byteLength,
                archiveSha256: archiveSha256,
                startedAtUtc: startedAtUtc,
                completedAtUtc: completedAtUtc,
                errorCode: errorCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                Value<String?> targetId = const Value.absent(),
                Value<String?> encryptionProfileId = const Value.absent(),
                required String kind,
                required String status,
                Value<String?> archiveName = const Value.absent(),
                required String appVersion,
                required int databaseSchemaVersion,
                required int manifestVersion,
                Value<String?> recordCountsJson = const Value.absent(),
                Value<int?> byteLength = const Value.absent(),
                Value<String?> archiveSha256 = const Value.absent(),
                required int startedAtUtc,
                Value<int?> completedAtUtc = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BackupRunsCompanion.insert(
                id: id,
                targetId: targetId,
                encryptionProfileId: encryptionProfileId,
                kind: kind,
                status: status,
                archiveName: archiveName,
                appVersion: appVersion,
                databaseSchemaVersion: databaseSchemaVersion,
                manifestVersion: manifestVersion,
                recordCountsJson: recordCountsJson,
                byteLength: byteLength,
                archiveSha256: archiveSha256,
                startedAtUtc: startedAtUtc,
                completedAtUtc: completedAtUtc,
                errorCode: errorCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$BackupRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                targetId = false,
                encryptionProfileId = false,
                restoreRunsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (restoreRunsRefs) db.restoreRuns,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (targetId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.targetId,
                            referencedTable: $$BackupRunsTableReferences
                                ._targetIdTable(db),
                            referencedColumn: $$BackupRunsTableReferences
                                ._targetIdTable(db)
                                .id,
                          ) as T;
                        }
                        if (encryptionProfileId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.encryptionProfileId,
                            referencedTable: $$BackupRunsTableReferences
                                ._encryptionProfileIdTable(db),
                            referencedColumn: $$BackupRunsTableReferences
                                ._encryptionProfileIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (restoreRunsRefs)
                        await $_getPrefetchedData<
                          BackupRunRow,
                          $BackupRunsTable,
                          RestoreRunRow
                        >(
                          currentTable: table,
                          referencedTable: $$BackupRunsTableReferences
                              ._restoreRunsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$BackupRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).restoreRunsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.preRestoreBackupRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$BackupRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $BackupRunsTable,
      BackupRunRow,
      $$BackupRunsTableFilterComposer,
      $$BackupRunsTableOrderingComposer,
      $$BackupRunsTableAnnotationComposer,
      $$BackupRunsTableCreateCompanionBuilder,
      $$BackupRunsTableUpdateCompanionBuilder,
      (BackupRunRow, $$BackupRunsTableReferences),
      BackupRunRow,
      PrefetchHooks Function({
        bool targetId,
        bool encryptionProfileId,
        bool restoreRunsRefs,
      })
    >;
typedef $$RestoreRunsTableCreateCompanionBuilder =
    RestoreRunsCompanion Function({
      required String id,
      required String sourceName,
      Value<String?> sourceSha256,
      required String mode,
      Value<int?> sourceSchemaVersion,
      Value<String?> preRestoreBackupRunId,
      required String status,
      Value<String?> summaryJson,
      required int startedAtUtc,
      Value<int?> completedAtUtc,
      Value<String?> errorCode,
      Value<int> rowid,
    });
typedef $$RestoreRunsTableUpdateCompanionBuilder =
    RestoreRunsCompanion Function({
      Value<String> id,
      Value<String> sourceName,
      Value<String?> sourceSha256,
      Value<String> mode,
      Value<int?> sourceSchemaVersion,
      Value<String?> preRestoreBackupRunId,
      Value<String> status,
      Value<String?> summaryJson,
      Value<int> startedAtUtc,
      Value<int?> completedAtUtc,
      Value<String?> errorCode,
      Value<int> rowid,
    });

final class $$RestoreRunsTableReferences
    extends
        BaseReferences<_$DangguiDatabase, $RestoreRunsTable, RestoreRunRow> {
  $$RestoreRunsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $BackupRunsTable _preRestoreBackupRunIdTable(_$DangguiDatabase db) =>
      db.backupRuns.createAlias(
        'restore_runs__pre_restore_backup_run_id__backup_runs__id',
      );

  $$BackupRunsTableProcessedTableManager? get preRestoreBackupRunId {
    final $_column = $_itemColumn<String>('pre_restore_backup_run_id');
    if ($_column == null) return null;
    final manager = $$BackupRunsTableTableManager(
      $_db,
      $_db.backupRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(
      _preRestoreBackupRunIdTable($_db),
    );
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$RestoreConflictsTable, List<RestoreConflictRow>>
  _restoreConflictsRefsTable(_$DangguiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.restoreConflicts,
        aliasName: 'restore_runs__id__restore_conflicts__restore_run_id',
      );

  $$RestoreConflictsTableProcessedTableManager get restoreConflictsRefs {
    final manager = $$RestoreConflictsTableTableManager(
      $_db,
      $_db.restoreConflicts,
    ).filter((f) => f.restoreRunId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _restoreConflictsRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ImportProvenanceTable, List<ImportProvenanceRow>>
  _importProvenanceRefsTable(_$DangguiDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.importProvenance,
        aliasName: 'restore_runs__id__import_provenance__restore_run_id',
      );

  $$ImportProvenanceTableProcessedTableManager get importProvenanceRefs {
    final manager = $$ImportProvenanceTableTableManager(
      $_db,
      $_db.importProvenance,
    ).filter((f) => f.restoreRunId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _importProvenanceRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$RestoreRunsTableFilterComposer
    extends Composer<_$DangguiDatabase, $RestoreRunsTable> {
  $$RestoreRunsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sourceSchemaVersion => $composableBuilder(
    column: $table.sourceSchemaVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnFilters(column),
  );

  $$BackupRunsTableFilterComposer get preRestoreBackupRunId {
    final $$BackupRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.preRestoreBackupRunId,
      referencedTable: $db.backupRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupRunsTableFilterComposer(
            $db: $db,
            $table: $db.backupRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> restoreConflictsRefs(
    Expression<bool> Function($$RestoreConflictsTableFilterComposer f) f,
  ) {
    final $$RestoreConflictsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.restoreConflicts,
      getReferencedColumn: (t) => t.restoreRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreConflictsTableFilterComposer(
            $db: $db,
            $table: $db.restoreConflicts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> importProvenanceRefs(
    Expression<bool> Function($$ImportProvenanceTableFilterComposer f) f,
  ) {
    final $$ImportProvenanceTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importProvenance,
      getReferencedColumn: (t) => t.restoreRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportProvenanceTableFilterComposer(
            $db: $db,
            $table: $db.importProvenance,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RestoreRunsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $RestoreRunsTable> {
  $$RestoreRunsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sourceSchemaVersion => $composableBuilder(
    column: $table.sourceSchemaVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get errorCode => $composableBuilder(
    column: $table.errorCode,
    builder: (column) => ColumnOrderings(column),
  );

  $$BackupRunsTableOrderingComposer get preRestoreBackupRunId {
    final $$BackupRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.preRestoreBackupRunId,
      referencedTable: $db.backupRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupRunsTableOrderingComposer(
            $db: $db,
            $table: $db.backupRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RestoreRunsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $RestoreRunsTable> {
  $$RestoreRunsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get sourceName => $composableBuilder(
    column: $table.sourceName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceSha256 => $composableBuilder(
    column: $table.sourceSha256,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get sourceSchemaVersion => $composableBuilder(
    column: $table.sourceSchemaVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get summaryJson => $composableBuilder(
    column: $table.summaryJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get startedAtUtc => $composableBuilder(
    column: $table.startedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<int> get completedAtUtc => $composableBuilder(
    column: $table.completedAtUtc,
    builder: (column) => column,
  );

  GeneratedColumn<String> get errorCode =>
      $composableBuilder(column: $table.errorCode, builder: (column) => column);

  $$BackupRunsTableAnnotationComposer get preRestoreBackupRunId {
    final $$BackupRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.preRestoreBackupRunId,
      referencedTable: $db.backupRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$BackupRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.backupRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> restoreConflictsRefs<T extends Object>(
    Expression<T> Function($$RestoreConflictsTableAnnotationComposer a) f,
  ) {
    final $$RestoreConflictsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.restoreConflicts,
      getReferencedColumn: (t) => t.restoreRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreConflictsTableAnnotationComposer(
            $db: $db,
            $table: $db.restoreConflicts,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> importProvenanceRefs<T extends Object>(
    Expression<T> Function($$ImportProvenanceTableAnnotationComposer a) f,
  ) {
    final $$ImportProvenanceTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.importProvenance,
      getReferencedColumn: (t) => t.restoreRunId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ImportProvenanceTableAnnotationComposer(
            $db: $db,
            $table: $db.importProvenance,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$RestoreRunsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $RestoreRunsTable,
          RestoreRunRow,
          $$RestoreRunsTableFilterComposer,
          $$RestoreRunsTableOrderingComposer,
          $$RestoreRunsTableAnnotationComposer,
          $$RestoreRunsTableCreateCompanionBuilder,
          $$RestoreRunsTableUpdateCompanionBuilder,
          (RestoreRunRow, $$RestoreRunsTableReferences),
          RestoreRunRow,
          PrefetchHooks Function({
            bool preRestoreBackupRunId,
            bool restoreConflictsRefs,
            bool importProvenanceRefs,
          })
        > {
  $$RestoreRunsTableTableManager(_$DangguiDatabase db, $RestoreRunsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestoreRunsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestoreRunsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestoreRunsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> sourceName = const Value.absent(),
                Value<String?> sourceSha256 = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int?> sourceSchemaVersion = const Value.absent(),
                Value<String?> preRestoreBackupRunId = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String?> summaryJson = const Value.absent(),
                Value<int> startedAtUtc = const Value.absent(),
                Value<int?> completedAtUtc = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestoreRunsCompanion(
                id: id,
                sourceName: sourceName,
                sourceSha256: sourceSha256,
                mode: mode,
                sourceSchemaVersion: sourceSchemaVersion,
                preRestoreBackupRunId: preRestoreBackupRunId,
                status: status,
                summaryJson: summaryJson,
                startedAtUtc: startedAtUtc,
                completedAtUtc: completedAtUtc,
                errorCode: errorCode,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String sourceName,
                Value<String?> sourceSha256 = const Value.absent(),
                required String mode,
                Value<int?> sourceSchemaVersion = const Value.absent(),
                Value<String?> preRestoreBackupRunId = const Value.absent(),
                required String status,
                Value<String?> summaryJson = const Value.absent(),
                required int startedAtUtc,
                Value<int?> completedAtUtc = const Value.absent(),
                Value<String?> errorCode = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestoreRunsCompanion.insert(
                id: id,
                sourceName: sourceName,
                sourceSha256: sourceSha256,
                mode: mode,
                sourceSchemaVersion: sourceSchemaVersion,
                preRestoreBackupRunId: preRestoreBackupRunId,
                status: status,
                summaryJson: summaryJson,
                startedAtUtc: startedAtUtc,
                completedAtUtc: completedAtUtc,
                errorCode: errorCode,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RestoreRunsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                preRestoreBackupRunId = false,
                restoreConflictsRefs = false,
                importProvenanceRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (restoreConflictsRefs) db.restoreConflicts,
                    if (importProvenanceRefs) db.importProvenance,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (preRestoreBackupRunId) {
                          state = state.withJoin(
                            currentTable: table,
                            currentColumn: table.preRestoreBackupRunId,
                            referencedTable: $$RestoreRunsTableReferences
                                ._preRestoreBackupRunIdTable(db),
                            referencedColumn: $$RestoreRunsTableReferences
                                ._preRestoreBackupRunIdTable(db)
                                .id,
                          ) as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (restoreConflictsRefs)
                        await $_getPrefetchedData<
                          RestoreRunRow,
                          $RestoreRunsTable,
                          RestoreConflictRow
                        >(
                          currentTable: table,
                          referencedTable: $$RestoreRunsTableReferences
                              ._restoreConflictsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RestoreRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).restoreConflictsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.restoreRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (importProvenanceRefs)
                        await $_getPrefetchedData<
                          RestoreRunRow,
                          $RestoreRunsTable,
                          ImportProvenanceRow
                        >(
                          currentTable: table,
                          referencedTable: $$RestoreRunsTableReferences
                              ._importProvenanceRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$RestoreRunsTableReferences(
                                db,
                                table,
                                p0,
                              ).importProvenanceRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.restoreRunId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$RestoreRunsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $RestoreRunsTable,
      RestoreRunRow,
      $$RestoreRunsTableFilterComposer,
      $$RestoreRunsTableOrderingComposer,
      $$RestoreRunsTableAnnotationComposer,
      $$RestoreRunsTableCreateCompanionBuilder,
      $$RestoreRunsTableUpdateCompanionBuilder,
      (RestoreRunRow, $$RestoreRunsTableReferences),
      RestoreRunRow,
      PrefetchHooks Function({
        bool preRestoreBackupRunId,
        bool restoreConflictsRefs,
        bool importProvenanceRefs,
      })
    >;
typedef $$RestoreConflictsTableCreateCompanionBuilder =
    RestoreConflictsCompanion Function({
      required String id,
      required String restoreRunId,
      required String entityType,
      required String incomingId,
      Value<String?> resolvedLocalId,
      Value<String?> incomingHash,
      Value<String?> currentHash,
      required String resolution,
      Value<int> rowid,
    });
typedef $$RestoreConflictsTableUpdateCompanionBuilder =
    RestoreConflictsCompanion Function({
      Value<String> id,
      Value<String> restoreRunId,
      Value<String> entityType,
      Value<String> incomingId,
      Value<String?> resolvedLocalId,
      Value<String?> incomingHash,
      Value<String?> currentHash,
      Value<String> resolution,
      Value<int> rowid,
    });

final class $$RestoreConflictsTableReferences
    extends
        BaseReferences<
          _$DangguiDatabase,
          $RestoreConflictsTable,
          RestoreConflictRow
        > {
  $$RestoreConflictsTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RestoreRunsTable _restoreRunIdTable(_$DangguiDatabase db) => db
      .restoreRuns
      .createAlias('restore_conflicts__restore_run_id__restore_runs__id');

  $$RestoreRunsTableProcessedTableManager get restoreRunId {
    final $_column = $_itemColumn<String>('restore_run_id')!;

    final manager = $$RestoreRunsTableTableManager(
      $_db,
      $_db.restoreRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_restoreRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RestoreConflictsTableFilterComposer
    extends Composer<_$DangguiDatabase, $RestoreConflictsTable> {
  $$RestoreConflictsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incomingId => $composableBuilder(
    column: $table.incomingId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolvedLocalId => $composableBuilder(
    column: $table.resolvedLocalId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get incomingHash => $composableBuilder(
    column: $table.incomingHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentHash => $composableBuilder(
    column: $table.currentHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnFilters(column),
  );

  $$RestoreRunsTableFilterComposer get restoreRunId {
    final $$RestoreRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restoreRunId,
      referencedTable: $db.restoreRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreRunsTableFilterComposer(
            $db: $db,
            $table: $db.restoreRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RestoreConflictsTableOrderingComposer
    extends Composer<_$DangguiDatabase, $RestoreConflictsTable> {
  $$RestoreConflictsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incomingId => $composableBuilder(
    column: $table.incomingId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolvedLocalId => $composableBuilder(
    column: $table.resolvedLocalId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get incomingHash => $composableBuilder(
    column: $table.incomingHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentHash => $composableBuilder(
    column: $table.currentHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => ColumnOrderings(column),
  );

  $$RestoreRunsTableOrderingComposer get restoreRunId {
    final $$RestoreRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restoreRunId,
      referencedTable: $db.restoreRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreRunsTableOrderingComposer(
            $db: $db,
            $table: $db.restoreRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RestoreConflictsTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $RestoreConflictsTable> {
  $$RestoreConflictsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get incomingId => $composableBuilder(
    column: $table.incomingId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolvedLocalId => $composableBuilder(
    column: $table.resolvedLocalId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get incomingHash => $composableBuilder(
    column: $table.incomingHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get currentHash => $composableBuilder(
    column: $table.currentHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolution => $composableBuilder(
    column: $table.resolution,
    builder: (column) => column,
  );

  $$RestoreRunsTableAnnotationComposer get restoreRunId {
    final $$RestoreRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restoreRunId,
      referencedTable: $db.restoreRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.restoreRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RestoreConflictsTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $RestoreConflictsTable,
          RestoreConflictRow,
          $$RestoreConflictsTableFilterComposer,
          $$RestoreConflictsTableOrderingComposer,
          $$RestoreConflictsTableAnnotationComposer,
          $$RestoreConflictsTableCreateCompanionBuilder,
          $$RestoreConflictsTableUpdateCompanionBuilder,
          (RestoreConflictRow, $$RestoreConflictsTableReferences),
          RestoreConflictRow,
          PrefetchHooks Function({bool restoreRunId})
        > {
  $$RestoreConflictsTableTableManager(
    _$DangguiDatabase db,
    $RestoreConflictsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RestoreConflictsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RestoreConflictsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RestoreConflictsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> restoreRunId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> incomingId = const Value.absent(),
                Value<String?> resolvedLocalId = const Value.absent(),
                Value<String?> incomingHash = const Value.absent(),
                Value<String?> currentHash = const Value.absent(),
                Value<String> resolution = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RestoreConflictsCompanion(
                id: id,
                restoreRunId: restoreRunId,
                entityType: entityType,
                incomingId: incomingId,
                resolvedLocalId: resolvedLocalId,
                incomingHash: incomingHash,
                currentHash: currentHash,
                resolution: resolution,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String restoreRunId,
                required String entityType,
                required String incomingId,
                Value<String?> resolvedLocalId = const Value.absent(),
                Value<String?> incomingHash = const Value.absent(),
                Value<String?> currentHash = const Value.absent(),
                required String resolution,
                Value<int> rowid = const Value.absent(),
              }) => RestoreConflictsCompanion.insert(
                id: id,
                restoreRunId: restoreRunId,
                entityType: entityType,
                incomingId: incomingId,
                resolvedLocalId: resolvedLocalId,
                incomingHash: incomingHash,
                currentHash: currentHash,
                resolution: resolution,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RestoreConflictsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({restoreRunId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (restoreRunId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.restoreRunId,
                        referencedTable: $$RestoreConflictsTableReferences
                            ._restoreRunIdTable(db),
                        referencedColumn: $$RestoreConflictsTableReferences
                            ._restoreRunIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RestoreConflictsTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $RestoreConflictsTable,
      RestoreConflictRow,
      $$RestoreConflictsTableFilterComposer,
      $$RestoreConflictsTableOrderingComposer,
      $$RestoreConflictsTableAnnotationComposer,
      $$RestoreConflictsTableCreateCompanionBuilder,
      $$RestoreConflictsTableUpdateCompanionBuilder,
      (RestoreConflictRow, $$RestoreConflictsTableReferences),
      RestoreConflictRow,
      PrefetchHooks Function({bool restoreRunId})
    >;
typedef $$ImportProvenanceTableCreateCompanionBuilder =
    ImportProvenanceCompanion Function({
      required String originDatasetId,
      required String entityType,
      required String originEntityId,
      required String originHash,
      required String localEntityId,
      Value<String?> restoreRunId,
      required int createdAtUtc,
      Value<int> rowid,
    });
typedef $$ImportProvenanceTableUpdateCompanionBuilder =
    ImportProvenanceCompanion Function({
      Value<String> originDatasetId,
      Value<String> entityType,
      Value<String> originEntityId,
      Value<String> originHash,
      Value<String> localEntityId,
      Value<String?> restoreRunId,
      Value<int> createdAtUtc,
      Value<int> rowid,
    });

final class $$ImportProvenanceTableReferences
    extends
        BaseReferences<
          _$DangguiDatabase,
          $ImportProvenanceTable,
          ImportProvenanceRow
        > {
  $$ImportProvenanceTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $RestoreRunsTable _restoreRunIdTable(_$DangguiDatabase db) => db
      .restoreRuns
      .createAlias('import_provenance__restore_run_id__restore_runs__id');

  $$RestoreRunsTableProcessedTableManager? get restoreRunId {
    final $_column = $_itemColumn<String>('restore_run_id');
    if ($_column == null) return null;
    final manager = $$RestoreRunsTableTableManager(
      $_db,
      $_db.restoreRuns,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_restoreRunIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ImportProvenanceTableFilterComposer
    extends Composer<_$DangguiDatabase, $ImportProvenanceTable> {
  $$ImportProvenanceTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get originDatasetId => $composableBuilder(
    column: $table.originDatasetId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originEntityId => $composableBuilder(
    column: $table.originEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get originHash => $composableBuilder(
    column: $table.originHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localEntityId => $composableBuilder(
    column: $table.localEntityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnFilters(column),
  );

  $$RestoreRunsTableFilterComposer get restoreRunId {
    final $$RestoreRunsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restoreRunId,
      referencedTable: $db.restoreRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreRunsTableFilterComposer(
            $db: $db,
            $table: $db.restoreRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportProvenanceTableOrderingComposer
    extends Composer<_$DangguiDatabase, $ImportProvenanceTable> {
  $$ImportProvenanceTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get originDatasetId => $composableBuilder(
    column: $table.originDatasetId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originEntityId => $composableBuilder(
    column: $table.originEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get originHash => $composableBuilder(
    column: $table.originHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localEntityId => $composableBuilder(
    column: $table.localEntityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => ColumnOrderings(column),
  );

  $$RestoreRunsTableOrderingComposer get restoreRunId {
    final $$RestoreRunsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restoreRunId,
      referencedTable: $db.restoreRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreRunsTableOrderingComposer(
            $db: $db,
            $table: $db.restoreRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportProvenanceTableAnnotationComposer
    extends Composer<_$DangguiDatabase, $ImportProvenanceTable> {
  $$ImportProvenanceTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get originDatasetId => $composableBuilder(
    column: $table.originDatasetId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originEntityId => $composableBuilder(
    column: $table.originEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get originHash => $composableBuilder(
    column: $table.originHash,
    builder: (column) => column,
  );

  GeneratedColumn<String> get localEntityId => $composableBuilder(
    column: $table.localEntityId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAtUtc => $composableBuilder(
    column: $table.createdAtUtc,
    builder: (column) => column,
  );

  $$RestoreRunsTableAnnotationComposer get restoreRunId {
    final $$RestoreRunsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.restoreRunId,
      referencedTable: $db.restoreRuns,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RestoreRunsTableAnnotationComposer(
            $db: $db,
            $table: $db.restoreRuns,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ImportProvenanceTableTableManager
    extends
        RootTableManager<
          _$DangguiDatabase,
          $ImportProvenanceTable,
          ImportProvenanceRow,
          $$ImportProvenanceTableFilterComposer,
          $$ImportProvenanceTableOrderingComposer,
          $$ImportProvenanceTableAnnotationComposer,
          $$ImportProvenanceTableCreateCompanionBuilder,
          $$ImportProvenanceTableUpdateCompanionBuilder,
          (ImportProvenanceRow, $$ImportProvenanceTableReferences),
          ImportProvenanceRow,
          PrefetchHooks Function({bool restoreRunId})
        > {
  $$ImportProvenanceTableTableManager(
    _$DangguiDatabase db,
    $ImportProvenanceTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ImportProvenanceTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ImportProvenanceTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ImportProvenanceTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> originDatasetId = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<String> originEntityId = const Value.absent(),
                Value<String> originHash = const Value.absent(),
                Value<String> localEntityId = const Value.absent(),
                Value<String?> restoreRunId = const Value.absent(),
                Value<int> createdAtUtc = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ImportProvenanceCompanion(
                originDatasetId: originDatasetId,
                entityType: entityType,
                originEntityId: originEntityId,
                originHash: originHash,
                localEntityId: localEntityId,
                restoreRunId: restoreRunId,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String originDatasetId,
                required String entityType,
                required String originEntityId,
                required String originHash,
                required String localEntityId,
                Value<String?> restoreRunId = const Value.absent(),
                required int createdAtUtc,
                Value<int> rowid = const Value.absent(),
              }) => ImportProvenanceCompanion.insert(
                originDatasetId: originDatasetId,
                entityType: entityType,
                originEntityId: originEntityId,
                originHash: originHash,
                localEntityId: localEntityId,
                restoreRunId: restoreRunId,
                createdAtUtc: createdAtUtc,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$ImportProvenanceTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({restoreRunId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (restoreRunId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.restoreRunId,
                        referencedTable: $$ImportProvenanceTableReferences
                            ._restoreRunIdTable(db),
                        referencedColumn: $$ImportProvenanceTableReferences
                            ._restoreRunIdTable(db)
                            .id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ImportProvenanceTableProcessedTableManager =
    ProcessedTableManager<
      _$DangguiDatabase,
      $ImportProvenanceTable,
      ImportProvenanceRow,
      $$ImportProvenanceTableFilterComposer,
      $$ImportProvenanceTableOrderingComposer,
      $$ImportProvenanceTableAnnotationComposer,
      $$ImportProvenanceTableCreateCompanionBuilder,
      $$ImportProvenanceTableUpdateCompanionBuilder,
      (ImportProvenanceRow, $$ImportProvenanceTableReferences),
      ImportProvenanceRow,
      PrefetchHooks Function({bool restoreRunId})
    >;

class $DangguiDatabaseManager {
  final _$DangguiDatabase _db;
  $DangguiDatabaseManager(this._db);
  $$AppMetadataTableTableManager get appMetadata =>
      $$AppMetadataTableTableManager(_db, _db.appMetadata);
  $$AppSettingsTableTableTableManager get appSettingsTable =>
      $$AppSettingsTableTableTableManager(_db, _db.appSettingsTable);
  $$DocumentsTableTableManager get documents =>
      $$DocumentsTableTableManager(_db, _db.documents);
  $$DocumentBlocksTableTableManager get documentBlocks =>
      $$DocumentBlocksTableTableManager(_db, _db.documentBlocks);
  $$DocumentRevisionsTableTableManager get documentRevisions =>
      $$DocumentRevisionsTableTableManager(_db, _db.documentRevisions);
  $$TasksTableTableManager get tasks =>
      $$TasksTableTableManager(_db, _db.tasks);
  $$RemindersTableTableManager get reminders =>
      $$RemindersTableTableManager(_db, _db.reminders);
  $$NotificationRegistrationsTableTableManager get notificationRegistrations =>
      $$NotificationRegistrationsTableTableManager(
        _db,
        _db.notificationRegistrations,
      );
  $$PlatformJobsTableTableManager get platformJobs =>
      $$PlatformJobsTableTableManager(_db, _db.platformJobs);
  $$FoldersTableTableManager get folders =>
      $$FoldersTableTableManager(_db, _db.folders);
  $$NotesTableTableManager get notes =>
      $$NotesTableTableManager(_db, _db.notes);
  $$TrashEntriesTableTableManager get trashEntries =>
      $$TrashEntriesTableTableManager(_db, _db.trashEntries);
  $$PastEventsTableTableManager get pastEvents =>
      $$PastEventsTableTableManager(_db, _db.pastEvents);
  $$PastEventPartsTableTableManager get pastEventParts =>
      $$PastEventPartsTableTableManager(_db, _db.pastEventParts);
  $$PastAnchorLinksTableTableManager get pastAnchorLinks =>
      $$PastAnchorLinksTableTableManager(_db, _db.pastAnchorLinks);
  $$SearchRecordsTableTableManager get searchRecords =>
      $$SearchRecordsTableTableManager(_db, _db.searchRecords);
  $$BackupTargetsTableTableManager get backupTargets =>
      $$BackupTargetsTableTableManager(_db, _db.backupTargets);
  $$BackupEncryptionProfilesTableTableManager get backupEncryptionProfiles =>
      $$BackupEncryptionProfilesTableTableManager(
        _db,
        _db.backupEncryptionProfiles,
      );
  $$BackupRunsTableTableManager get backupRuns =>
      $$BackupRunsTableTableManager(_db, _db.backupRuns);
  $$RestoreRunsTableTableManager get restoreRuns =>
      $$RestoreRunsTableTableManager(_db, _db.restoreRuns);
  $$RestoreConflictsTableTableManager get restoreConflicts =>
      $$RestoreConflictsTableTableManager(_db, _db.restoreConflicts);
  $$ImportProvenanceTableTableManager get importProvenance =>
      $$ImportProvenanceTableTableManager(_db, _db.importProvenance);
}
