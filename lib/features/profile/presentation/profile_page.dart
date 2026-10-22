import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nutrition/energy_calculator.dart';
import '../../../core/providers.dart';
import '../domain/profile_enums.dart';
import 'profile_form.dart';
import 'weight_trend_card.dart';

/// 查看與修改基本資料。改完會重新計算建議熱量。
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider);
    final weight = ref.watch(latestMeasurementProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: switch ((profile, weight)) {
        (AsyncData(value: final p?), AsyncData(value: final w?)) =>
          _ProfileForm(profile: p, latestWeight: w),
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => Center(child: Text('讀取資料失敗：$error')),
        // 讀完了但缺資料（舊版資料庫）。重開 App 會回到 Onboarding 補完。
        (AsyncData(), AsyncData()) => const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              '找不到體重紀錄。請關閉並重新開啟 App，完成初始設定後即可使用。',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.profile, required this.latestWeight});

  final UserProfile profile;
  final BodyMeasurement latestWeight;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _height;
  late final TextEditingController _weight;
  late final TextEditingController _targetWeight;

  late BiologicalSex _sex;
  late DateTime _birthDate;
  late ActivityLevel _activity;
  late GoalType _goal;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _height = TextEditingController(text: p.heightCm.toString());
    _weight = TextEditingController(
      text: widget.latestWeight.weightKg.toString(),
    );
    _targetWeight = TextEditingController(
      text: p.targetWeightKg?.toString() ?? '',
    );
    _sex = p.biologicalSex;
    _birthDate = p.birthDate;
    _activity = p.activityLevel;
    _goal = p.goalType;
  }

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _targetWeight.dispose();
    super.dispose();
  }

  int get _age => EnergyCalculator.ageFromBirthDate(_birthDate);
  double get _heightCm => double.parse(_height.text.trim());
  double get _weightKg => double.parse(_weight.text.trim());

  int get _suggested => EnergyCalculator.dailyCalorieTarget(
    sex: _sex,
    ageYears: _age,
    heightCm: _heightCm,
    weightKg: _weightKg,
    activityLevel: _activity,
    goal: _goal,
  );

  /// 依「已儲存」的資料算建議熱量，不受表單裡還沒存的修改影響。
  int get _savedSuggested {
    final p = widget.profile;
    return EnergyCalculator.dailyCalorieTarget(
      sex: p.biologicalSex,
      ageYears: EnergyCalculator.ageFromBirthDate(p.birthDate),
      heightCm: p.heightCm,
      weightKg: widget.latestWeight.weightKg,
      activityLevel: p.activityLevel,
      goal: p.goalType,
    );
  }

  Future<void> _editTarget() async {
    final current = widget.profile.manualCalorieOverride ?? _savedSuggested;
    final result = await showDialog<double>(
      context: context,
      builder: (_) => NumberInputDialog(
        title: '自訂每日熱量目標',
        initial: '$current',
        suffix: '大卡',
        fieldKey: const Key('target_input'),
        validator: ProfileForm.validateCalorieTarget,
        decimal: false,
      ),
    );
    if (result != null) await _setManualTarget(result.round());
  }

  /// [kcal] 為 null = 取消手動目標，改回建議值。只動目標，表單其他欄位
  /// 沒存的修改不會被一起寫進去。
  Future<void> _setManualTarget(int? kcal) async {
    final p = widget.profile;
    final target = kcal ?? _savedSuggested;
    final repo = ref.read(profileRepositoryProvider);
    setState(() => _saving = true);
    try {
      await ref.read(appDatabaseProvider).transaction(() async {
        await repo.saveProfile(
          biologicalSex: p.biologicalSex,
          birthDate: p.birthDate,
          heightCm: p.heightCm,
          activityLevel: p.activityLevel,
          goalType: p.goalType,
          targetWeightKg: p.targetWeightKg,
          manualCalorieOverride: kcal,
        );
        await repo.setDailyTarget(
          effectiveFrom: DateTime.now(),
          calorieTarget: target,
          isManualOverride: kcal != null,
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('每日目標改為 $target 大卡')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 記錄體重走和表單同一個儲存流程：重算建議熱量，有手動目標時先詢問。
  /// 體重和上次一樣也會記一筆，趨勢圖才有那天的點。
  Future<void> _logWeight() async {
    final kg = await showDialog<double>(
      context: context,
      builder: (_) => const NumberInputDialog(
        title: '記錄體重',
        suffix: '公斤',
        fieldKey: Key('weigh_in_field'),
        validator: ProfileForm.validateWeight,
      ),
    );
    if (kg == null) return;
    _weight.text = kg == kg.roundToDouble() ? '${kg.toInt()}' : '$kg';
    await _save(weighIn: true);
  }

  Future<void> _save({bool weighIn = false}) async {
    if (!_formKey.currentState!.validate()) return;

    final repo = ref.read(profileRepositoryProvider);
    final override = widget.profile.manualCalorieOverride;
    final suggested = _suggested;
    var keepOverride = override != null;

    // 有手動目標且建議值變了 → 問過使用者，不默默覆蓋
    if (override != null && override != suggested) {
      final useNew = await _askAboutOverride(override, suggested);
      if (useNew == null) return; // 取消
      keepOverride = !useNew;
    }

    setState(() => _saving = true);
    try {
      final finalTarget = keepOverride ? override! : suggested;

      await repo.saveProfile(
        biologicalSex: _sex,
        birthDate: _birthDate,
        heightCm: _heightCm,
        activityLevel: _activity,
        goalType: _goal,
        targetWeightKg: double.tryParse(_targetWeight.text.trim()),
        manualCalorieOverride: keepOverride ? override : null,
      );

      if (weighIn || _weightKg != widget.latestWeight.weightKg) {
        await repo.addMeasurement(weightKg: _weightKg);
      }

      await repo.setDailyTarget(
        effectiveFrom: DateTime.now(),
        calorieTarget: finalTarget,
        isManualOverride: keepOverride,
      );

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('已儲存，每日目標 $finalTarget 大卡')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 回傳 true = 改用新的建議值，false = 保留手動目標，null = 取消
  Future<bool?> _askAboutOverride(int current, int suggested) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('要更新熱量目標嗎？'),
          content: Text(
            '你之前手動把每日目標設成 $current 大卡。\n'
            '依照新的資料，建議值是 $suggested 大卡。',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('取消'),
            ),
            TextButton(
              key: const Key('keep_override_button'),
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('保留 $current'),
            ),
            FilledButton(
              key: const Key('use_suggested_button'),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('改用 $suggested'),
            ),
          ],
        ),
      );

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate,
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: '選擇出生日期',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    final override = widget.profile.manualCalorieOverride;

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('目前狀態', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('$_age 歲 · ${ProfileForm.ageGroupLabel(_age)}'),
                  Text(
                    'BMI '
                    '${EnergyCalculator.bmi(weightKg: widget.latestWeight.weightKg, heightCm: widget.profile.heightCm).toStringAsFixed(1)}',
                  ),
                  Text(
                    override == null
                        ? '每日目標：依建議值自動計算'
                        : '每日目標：$override 大卡（手動設定）',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        key: const Key('edit_target_button'),
                        icon: const Icon(Icons.edit),
                        label: const Text('自行調整目標'),
                        onPressed: _saving ? null : _editTarget,
                      ),
                      if (override != null)
                        TextButton(
                          key: const Key('use_suggested_target_button'),
                          onPressed: _saving
                              ? null
                              : () => _setManualTarget(null),
                          child: const Text('改回建議值'),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          WeightTrendCard(
            targetKg: widget.profile.targetWeightKg,
            onLog: _saving ? null : _logWeight,
          ),
          const SizedBox(height: 16),

          const Text('生理性別'),
          const SizedBox(height: 8),
          SegmentedButton<BiologicalSex>(
            segments: [
              for (final s in BiologicalSex.values)
                ButtonSegment(value: s, label: Text(ProfileForm.sexLabel(s))),
            ],
            selected: {_sex},
            onSelectionChanged: (v) => setState(() => _sex = v.first),
          ),
          const SizedBox(height: 16),

          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('出生日期'),
            subtitle: Text(
              '${_birthDate.year}/${_birthDate.month}/${_birthDate.day}',
            ),
            trailing: const Icon(Icons.calendar_today),
            onTap: _pickBirthDate,
          ),

          TextFormField(
            key: const Key('profile_height_field'),
            controller: _height,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '身高',
              suffixText: '公分',
            ),
            validator: ProfileForm.validateHeight,
          ),
          const SizedBox(height: 16),

          TextFormField(
            key: const Key('profile_weight_field'),
            controller: _weight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '目前體重',
              suffixText: '公斤',
              helperText: '改動後會新增一筆體重紀錄',
            ),
            validator: ProfileForm.validateWeight,
          ),
          const SizedBox(height: 20),

          const Text('活動程度'),
          const SizedBox(height: 8),
          RadioGroup<ActivityLevel>(
            groupValue: _activity,
            onChanged: (v) => setState(() => _activity = v!),
            child: Column(
              children: [
                for (final a in ActivityLevel.values)
                  RadioListTile<ActivityLevel>(
                    contentPadding: EdgeInsets.zero,
                    value: a,
                    title: Text(ProfileForm.activityLabel(a)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          const Text('目標'),
          const SizedBox(height: 8),
          SegmentedButton<GoalType>(
            segments: [
              for (final g in GoalType.values)
                ButtonSegment(value: g, label: Text(ProfileForm.goalLabel(g))),
            ],
            selected: {_goal},
            onSelectionChanged: (v) => setState(() => _goal = v.first),
          ),
          const SizedBox(height: 16),

          TextFormField(
            key: const Key('profile_target_weight_field'),
            controller: _targetWeight,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: '目標體重（可不填）',
              suffixText: '公斤',
            ),
            validator: ProfileForm.validateTargetWeight,
          ),
          const SizedBox(height: 24),

          FilledButton(
            key: const Key('profile_save_button'),
            onPressed: _saving ? null : _save,
            child: const Text('儲存'),
          ),
        ],
      ),
    );
  }
}
