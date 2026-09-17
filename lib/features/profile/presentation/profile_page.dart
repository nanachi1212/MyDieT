import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/nutrition/energy_calculator.dart';
import '../../../core/providers.dart';
import '../domain/profile_enums.dart';
import 'profile_form.dart';

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

  Future<void> _save() async {
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

      if (_weightKg != widget.latestWeight.weightKg) {
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
                ],
              ),
            ),
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
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '身高',
              suffixText: '公分',
              border: OutlineInputBorder(),
            ),
            validator: ProfileForm.validateHeight,
          ),
          const SizedBox(height: 16),

          TextFormField(
            key: const Key('profile_weight_field'),
            controller: _weight,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '目前體重',
              suffixText: '公斤',
              helperText: '改動後會新增一筆體重紀錄',
              border: OutlineInputBorder(),
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
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '目標體重（可不填）',
              suffixText: '公斤',
              border: OutlineInputBorder(),
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
