// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
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
  late final GeneratedColumnWithTypeConverter<BiologicalSex, String>
  biologicalSex = GeneratedColumn<String>(
    'biological_sex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<BiologicalSex>($UserProfilesTable.$converterbiologicalSex);
  static const VerificationMeta _birthDateMeta = const VerificationMeta(
    'birthDate',
  );
  @override
  late final GeneratedColumn<DateTime> birthDate = GeneratedColumn<DateTime>(
    'birth_date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightCmMeta = const VerificationMeta(
    'heightCm',
  );
  @override
  late final GeneratedColumn<double> heightCm = GeneratedColumn<double>(
    'height_cm',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  @override
  late final GeneratedColumnWithTypeConverter<ActivityLevel, String>
  activityLevel = GeneratedColumn<String>(
    'activity_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  ).withConverter<ActivityLevel>($UserProfilesTable.$converteractivityLevel);
  @override
  late final GeneratedColumnWithTypeConverter<GoalType, String> goalType =
      GeneratedColumn<String>(
        'goal_type',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      ).withConverter<GoalType>($UserProfilesTable.$convertergoalType);
  static const VerificationMeta _targetWeightKgMeta = const VerificationMeta(
    'targetWeightKg',
  );
  @override
  late final GeneratedColumn<double> targetWeightKg = GeneratedColumn<double>(
    'target_weight_kg',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _manualCalorieOverrideMeta =
      const VerificationMeta('manualCalorieOverride');
  @override
  late final GeneratedColumn<int> manualCalorieOverride = GeneratedColumn<int>(
    'manual_calorie_override',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    biologicalSex,
    birthDate,
    heightCm,
    activityLevel,
    goalType,
    targetWeightKg,
    manualCalorieOverride,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('birth_date')) {
      context.handle(
        _birthDateMeta,
        birthDate.isAcceptableOrUnknown(data['birth_date']!, _birthDateMeta),
      );
    } else if (isInserting) {
      context.missing(_birthDateMeta);
    }
    if (data.containsKey('height_cm')) {
      context.handle(
        _heightCmMeta,
        heightCm.isAcceptableOrUnknown(data['height_cm']!, _heightCmMeta),
      );
    } else if (isInserting) {
      context.missing(_heightCmMeta);
    }
    if (data.containsKey('target_weight_kg')) {
      context.handle(
        _targetWeightKgMeta,
        targetWeightKg.isAcceptableOrUnknown(
          data['target_weight_kg']!,
          _targetWeightKgMeta,
        ),
      );
    }
    if (data.containsKey('manual_calorie_override')) {
      context.handle(
        _manualCalorieOverrideMeta,
        manualCalorieOverride.isAcceptableOrUnknown(
          data['manual_calorie_override']!,
          _manualCalorieOverrideMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      biologicalSex: $UserProfilesTable.$converterbiologicalSex.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}biological_sex'],
        )!,
      ),
      birthDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}birth_date'],
      )!,
      heightCm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height_cm'],
      )!,
      activityLevel: $UserProfilesTable.$converteractivityLevel.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}activity_level'],
        )!,
      ),
      goalType: $UserProfilesTable.$convertergoalType.fromSql(
        attachedDatabase.typeMapping.read(
          DriftSqlType.string,
          data['${effectivePrefix}goal_type'],
        )!,
      ),
      targetWeightKg: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_weight_kg'],
      ),
      manualCalorieOverride: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}manual_calorie_override'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }

  static JsonTypeConverter2<BiologicalSex, String, String>
  $converterbiologicalSex = const EnumNameConverter<BiologicalSex>(
    BiologicalSex.values,
  );
  static JsonTypeConverter2<ActivityLevel, String, String>
  $converteractivityLevel = const EnumNameConverter<ActivityLevel>(
    ActivityLevel.values,
  );
  static JsonTypeConverter2<GoalType, String, String> $convertergoalType =
      const EnumNameConverter<GoalType>(GoalType.values);
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;
  final BiologicalSex biologicalSex;
  final DateTime birthDate;
  final double heightCm;
  final ActivityLevel activityLevel;
  final GoalType goalType;
  final double? targetWeightKg;

  /// 使用者手動覆寫的每日熱量目標。null = 用計算值。
  final int? manualCalorieOverride;
  final DateTime createdAt;
  final DateTime updatedAt;
  const UserProfile({
    required this.id,
    required this.biologicalSex,
    required this.birthDate,
    required this.heightCm,
    required this.activityLevel,
    required this.goalType,
    this.targetWeightKg,
    this.manualCalorieOverride,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    {
      map['biological_sex'] = Variable<String>(
        $UserProfilesTable.$converterbiologicalSex.toSql(biologicalSex),
      );
    }
    map['birth_date'] = Variable<DateTime>(birthDate);
    map['height_cm'] = Variable<double>(heightCm);
    {
      map['activity_level'] = Variable<String>(
        $UserProfilesTable.$converteractivityLevel.toSql(activityLevel),
      );
    }
    {
      map['goal_type'] = Variable<String>(
        $UserProfilesTable.$convertergoalType.toSql(goalType),
      );
    }
    if (!nullToAbsent || targetWeightKg != null) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg);
    }
    if (!nullToAbsent || manualCalorieOverride != null) {
      map['manual_calorie_override'] = Variable<int>(manualCalorieOverride);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      biologicalSex: Value(biologicalSex),
      birthDate: Value(birthDate),
      heightCm: Value(heightCm),
      activityLevel: Value(activityLevel),
      goalType: Value(goalType),
      targetWeightKg: targetWeightKg == null && nullToAbsent
          ? const Value.absent()
          : Value(targetWeightKg),
      manualCalorieOverride: manualCalorieOverride == null && nullToAbsent
          ? const Value.absent()
          : Value(manualCalorieOverride),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      biologicalSex: $UserProfilesTable.$converterbiologicalSex.fromJson(
        serializer.fromJson<String>(json['biologicalSex']),
      ),
      birthDate: serializer.fromJson<DateTime>(json['birthDate']),
      heightCm: serializer.fromJson<double>(json['heightCm']),
      activityLevel: $UserProfilesTable.$converteractivityLevel.fromJson(
        serializer.fromJson<String>(json['activityLevel']),
      ),
      goalType: $UserProfilesTable.$convertergoalType.fromJson(
        serializer.fromJson<String>(json['goalType']),
      ),
      targetWeightKg: serializer.fromJson<double?>(json['targetWeightKg']),
      manualCalorieOverride: serializer.fromJson<int?>(
        json['manualCalorieOverride'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'biologicalSex': serializer.toJson<String>(
        $UserProfilesTable.$converterbiologicalSex.toJson(biologicalSex),
      ),
      'birthDate': serializer.toJson<DateTime>(birthDate),
      'heightCm': serializer.toJson<double>(heightCm),
      'activityLevel': serializer.toJson<String>(
        $UserProfilesTable.$converteractivityLevel.toJson(activityLevel),
      ),
      'goalType': serializer.toJson<String>(
        $UserProfilesTable.$convertergoalType.toJson(goalType),
      ),
      'targetWeightKg': serializer.toJson<double?>(targetWeightKg),
      'manualCalorieOverride': serializer.toJson<int?>(manualCalorieOverride),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  UserProfile copyWith({
    int? id,
    BiologicalSex? biologicalSex,
    DateTime? birthDate,
    double? heightCm,
    ActivityLevel? activityLevel,
    GoalType? goalType,
    Value<double?> targetWeightKg = const Value.absent(),
    Value<int?> manualCalorieOverride = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => UserProfile(
    id: id ?? this.id,
    biologicalSex: biologicalSex ?? this.biologicalSex,
    birthDate: birthDate ?? this.birthDate,
    heightCm: heightCm ?? this.heightCm,
    activityLevel: activityLevel ?? this.activityLevel,
    goalType: goalType ?? this.goalType,
    targetWeightKg: targetWeightKg.present
        ? targetWeightKg.value
        : this.targetWeightKg,
    manualCalorieOverride: manualCalorieOverride.present
        ? manualCalorieOverride.value
        : this.manualCalorieOverride,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      biologicalSex: data.biologicalSex.present
          ? data.biologicalSex.value
          : this.biologicalSex,
      birthDate: data.birthDate.present ? data.birthDate.value : this.birthDate,
      heightCm: data.heightCm.present ? data.heightCm.value : this.heightCm,
      activityLevel: data.activityLevel.present
          ? data.activityLevel.value
          : this.activityLevel,
      goalType: data.goalType.present ? data.goalType.value : this.goalType,
      targetWeightKg: data.targetWeightKg.present
          ? data.targetWeightKg.value
          : this.targetWeightKg,
      manualCalorieOverride: data.manualCalorieOverride.present
          ? data.manualCalorieOverride.value
          : this.manualCalorieOverride,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('biologicalSex: $biologicalSex, ')
          ..write('birthDate: $birthDate, ')
          ..write('heightCm: $heightCm, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goalType: $goalType, ')
          ..write('targetWeightKg: $targetWeightKg, ')
          ..write('manualCalorieOverride: $manualCalorieOverride, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    biologicalSex,
    birthDate,
    heightCm,
    activityLevel,
    goalType,
    targetWeightKg,
    manualCalorieOverride,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.biologicalSex == this.biologicalSex &&
          other.birthDate == this.birthDate &&
          other.heightCm == this.heightCm &&
          other.activityLevel == this.activityLevel &&
          other.goalType == this.goalType &&
          other.targetWeightKg == this.targetWeightKg &&
          other.manualCalorieOverride == this.manualCalorieOverride &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<BiologicalSex> biologicalSex;
  final Value<DateTime> birthDate;
  final Value<double> heightCm;
  final Value<ActivityLevel> activityLevel;
  final Value<GoalType> goalType;
  final Value<double?> targetWeightKg;
  final Value<int?> manualCalorieOverride;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.biologicalSex = const Value.absent(),
    this.birthDate = const Value.absent(),
    this.heightCm = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.goalType = const Value.absent(),
    this.targetWeightKg = const Value.absent(),
    this.manualCalorieOverride = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    required BiologicalSex biologicalSex,
    required DateTime birthDate,
    required double heightCm,
    required ActivityLevel activityLevel,
    required GoalType goalType,
    this.targetWeightKg = const Value.absent(),
    this.manualCalorieOverride = const Value.absent(),
    required DateTime createdAt,
    required DateTime updatedAt,
  }) : biologicalSex = Value(biologicalSex),
       birthDate = Value(birthDate),
       heightCm = Value(heightCm),
       activityLevel = Value(activityLevel),
       goalType = Value(goalType),
       createdAt = Value(createdAt),
       updatedAt = Value(updatedAt);
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<String>? biologicalSex,
    Expression<DateTime>? birthDate,
    Expression<double>? heightCm,
    Expression<String>? activityLevel,
    Expression<String>? goalType,
    Expression<double>? targetWeightKg,
    Expression<int>? manualCalorieOverride,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (biologicalSex != null) 'biological_sex': biologicalSex,
      if (birthDate != null) 'birth_date': birthDate,
      if (heightCm != null) 'height_cm': heightCm,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (goalType != null) 'goal_type': goalType,
      if (targetWeightKg != null) 'target_weight_kg': targetWeightKg,
      if (manualCalorieOverride != null)
        'manual_calorie_override': manualCalorieOverride,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  UserProfilesCompanion copyWith({
    Value<int>? id,
    Value<BiologicalSex>? biologicalSex,
    Value<DateTime>? birthDate,
    Value<double>? heightCm,
    Value<ActivityLevel>? activityLevel,
    Value<GoalType>? goalType,
    Value<double?>? targetWeightKg,
    Value<int?>? manualCalorieOverride,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      biologicalSex: biologicalSex ?? this.biologicalSex,
      birthDate: birthDate ?? this.birthDate,
      heightCm: heightCm ?? this.heightCm,
      activityLevel: activityLevel ?? this.activityLevel,
      goalType: goalType ?? this.goalType,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      manualCalorieOverride:
          manualCalorieOverride ?? this.manualCalorieOverride,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (biologicalSex.present) {
      map['biological_sex'] = Variable<String>(
        $UserProfilesTable.$converterbiologicalSex.toSql(biologicalSex.value),
      );
    }
    if (birthDate.present) {
      map['birth_date'] = Variable<DateTime>(birthDate.value);
    }
    if (heightCm.present) {
      map['height_cm'] = Variable<double>(heightCm.value);
    }
    if (activityLevel.present) {
      map['activity_level'] = Variable<String>(
        $UserProfilesTable.$converteractivityLevel.toSql(activityLevel.value),
      );
    }
    if (goalType.present) {
      map['goal_type'] = Variable<String>(
        $UserProfilesTable.$convertergoalType.toSql(goalType.value),
      );
    }
    if (targetWeightKg.present) {
      map['target_weight_kg'] = Variable<double>(targetWeightKg.value);
    }
    if (manualCalorieOverride.present) {
      map['manual_calorie_override'] = Variable<int>(
        manualCalorieOverride.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('biologicalSex: $biologicalSex, ')
          ..write('birthDate: $birthDate, ')
          ..write('heightCm: $heightCm, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('goalType: $goalType, ')
          ..write('targetWeightKg: $targetWeightKg, ')
          ..write('manualCalorieOverride: $manualCalorieOverride, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [userProfiles];
}

typedef $$UserProfilesTableCreateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      required BiologicalSex biologicalSex,
      required DateTime birthDate,
      required double heightCm,
      required ActivityLevel activityLevel,
      required GoalType goalType,
      Value<double?> targetWeightKg,
      Value<int?> manualCalorieOverride,
      required DateTime createdAt,
      required DateTime updatedAt,
    });
typedef $$UserProfilesTableUpdateCompanionBuilder =
    UserProfilesCompanion Function({
      Value<int> id,
      Value<BiologicalSex> biologicalSex,
      Value<DateTime> birthDate,
      Value<double> heightCm,
      Value<ActivityLevel> activityLevel,
      Value<GoalType> goalType,
      Value<double?> targetWeightKg,
      Value<int?> manualCalorieOverride,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
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

  ColumnWithTypeConverterFilters<BiologicalSex, BiologicalSex, String>
  get biologicalSex => $composableBuilder(
    column: $table.biologicalSex,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnFilters<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnWithTypeConverterFilters<ActivityLevel, ActivityLevel, String>
  get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnWithTypeConverterFilters(column),
  );

  ColumnWithTypeConverterFilters<GoalType, GoalType, String> get goalType =>
      $composableBuilder(
        column: $table.goalType,
        builder: (column) => ColumnWithTypeConverterFilters(column),
      );

  ColumnFilters<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get manualCalorieOverride => $composableBuilder(
    column: $table.manualCalorieOverride,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
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

  ColumnOrderings<String> get biologicalSex => $composableBuilder(
    column: $table.biologicalSex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get birthDate => $composableBuilder(
    column: $table.birthDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get heightCm => $composableBuilder(
    column: $table.heightCm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get goalType => $composableBuilder(
    column: $table.goalType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get manualCalorieOverride => $composableBuilder(
    column: $table.manualCalorieOverride,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumnWithTypeConverter<BiologicalSex, String> get biologicalSex =>
      $composableBuilder(
        column: $table.biologicalSex,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get birthDate =>
      $composableBuilder(column: $table.birthDate, builder: (column) => column);

  GeneratedColumn<double> get heightCm =>
      $composableBuilder(column: $table.heightCm, builder: (column) => column);

  GeneratedColumnWithTypeConverter<ActivityLevel, String> get activityLevel =>
      $composableBuilder(
        column: $table.activityLevel,
        builder: (column) => column,
      );

  GeneratedColumnWithTypeConverter<GoalType, String> get goalType =>
      $composableBuilder(column: $table.goalType, builder: (column) => column);

  GeneratedColumn<double> get targetWeightKg => $composableBuilder(
    column: $table.targetWeightKg,
    builder: (column) => column,
  );

  GeneratedColumn<int> get manualCalorieOverride => $composableBuilder(
    column: $table.manualCalorieOverride,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$UserProfilesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfilesTable,
          UserProfile,
          $$UserProfilesTableFilterComposer,
          $$UserProfilesTableOrderingComposer,
          $$UserProfilesTableAnnotationComposer,
          $$UserProfilesTableCreateCompanionBuilder,
          $$UserProfilesTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<BiologicalSex> biologicalSex = const Value.absent(),
                Value<DateTime> birthDate = const Value.absent(),
                Value<double> heightCm = const Value.absent(),
                Value<ActivityLevel> activityLevel = const Value.absent(),
                Value<GoalType> goalType = const Value.absent(),
                Value<double?> targetWeightKg = const Value.absent(),
                Value<int?> manualCalorieOverride = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => UserProfilesCompanion(
                id: id,
                biologicalSex: biologicalSex,
                birthDate: birthDate,
                heightCm: heightCm,
                activityLevel: activityLevel,
                goalType: goalType,
                targetWeightKg: targetWeightKg,
                manualCalorieOverride: manualCalorieOverride,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required BiologicalSex biologicalSex,
                required DateTime birthDate,
                required double heightCm,
                required ActivityLevel activityLevel,
                required GoalType goalType,
                Value<double?> targetWeightKg = const Value.absent(),
                Value<int?> manualCalorieOverride = const Value.absent(),
                required DateTime createdAt,
                required DateTime updatedAt,
              }) => UserProfilesCompanion.insert(
                id: id,
                biologicalSex: biologicalSex,
                birthDate: birthDate,
                heightCm: heightCm,
                activityLevel: activityLevel,
                goalType: goalType,
                targetWeightKg: targetWeightKg,
                manualCalorieOverride: manualCalorieOverride,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserProfilesTable, UserProfile>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UserProfilesTable,
                    UserProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfilesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfilesTable,
      UserProfile,
      $$UserProfilesTableFilterComposer,
      $$UserProfilesTableOrderingComposer,
      $$UserProfilesTableAnnotationComposer,
      $$UserProfilesTableCreateCompanionBuilder,
      $$UserProfilesTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
}
