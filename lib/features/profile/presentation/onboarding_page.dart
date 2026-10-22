import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/nutrition/energy_calculator.dart';
import '../../../core/providers.dart';
import '../domain/profile_enums.dart';
import 'profile_form.dart';

/// 第一次啟動時填基本資料。填完就能看到自己的建議熱量。
class OnboardingPage extends ConsumerStatefulWidget {
  const OnboardingPage({super.key});

  @override
  ConsumerState<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends ConsumerState<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  final _height = TextEditingController();
  final _weight = TextEditingController();
  final _targetWeight = TextEditingController();

  BiologicalSex _sex = BiologicalSex.female;
  DateTime? _birthDate;
  ActivityLevel _activity = ActivityLevel.light;
  GoalType _goal = GoalType.maintain;

  bool _showResult = false;
  bool _saving = false;
  int? _calorieOverride;

  @override
  void dispose() {
    _height.dispose();
    _weight.dispose();
    _targetWeight.dispose();
    super.dispose();
  }

  double get _heightCm => double.parse(_height.text.trim());
  double get _weightKg => double.parse(_weight.text.trim());
  int get _age => EnergyCalculator.ageFromBirthDate(_birthDate!);

  void _calculate() {
    if (_birthDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇出生日期')));
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _showResult = true;
      _calorieOverride = null;
    });
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: '選擇出生日期',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _showResult = false;
      });
    }
  }

  Future<void> _save(int calorieTarget, int suggested) async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(profileRepositoryProvider);
      final isOverride = calorieTarget != suggested;

      await repo.saveProfile(
        biologicalSex: _sex,
        birthDate: _birthDate!,
        heightCm: _heightCm,
        activityLevel: _activity,
        goalType: _goal,
        targetWeightKg: double.tryParse(_targetWeight.text.trim()),
        manualCalorieOverride: isOverride ? calorieTarget : null,
      );
      await repo.addMeasurement(weightKg: _weightKg);
      await repo.setDailyTarget(
        effectiveFrom: DateTime.now(),
        calorieTarget: calorieTarget,
        isManualOverride: isOverride,
      );

      // 觸發 router 離開 Onboarding
      ref.read(onboardingStateProvider).value = true;
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('建立你的資料')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text('這些資料只存在你的手機裡，用來計算每日熱量目標。'),
            const SizedBox(height: 20),

            const Text('生理性別'),
            const SizedBox(height: 8),
            SegmentedButton<BiologicalSex>(
              segments: [
                for (final s in BiologicalSex.values)
                  ButtonSegment(value: s, label: Text(ProfileForm.sexLabel(s))),
              ],
              selected: {_sex},
              onSelectionChanged: (v) => setState(() {
                _sex = v.first;
                _showResult = false;
              }),
            ),
            const SizedBox(height: 20),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('出生日期'),
              subtitle: Text(
                _birthDate == null
                    ? '尚未選擇'
                    : '${_birthDate!.year}/${_birthDate!.month}/${_birthDate!.day}'
                          '（${EnergyCalculator.ageFromBirthDate(_birthDate!)} 歲 · '
                          '${ProfileForm.ageGroupLabel(EnergyCalculator.ageFromBirthDate(_birthDate!))}）',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickBirthDate,
            ),
            const SizedBox(height: 8),

            TextFormField(
              key: const Key('height_field'),
              controller: _height,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '身高',
                suffixText: '公分',
              ),
              validator: ProfileForm.validateHeight,
              onChanged: (_) => setState(() => _showResult = false),
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('weight_field'),
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '目前體重',
                suffixText: '公斤',
              ),
              validator: ProfileForm.validateWeight,
              onChanged: (_) => setState(() => _showResult = false),
            ),
            const SizedBox(height: 20),

            const Text('活動程度'),
            const SizedBox(height: 8),
            RadioGroup<ActivityLevel>(
              groupValue: _activity,
              onChanged: (v) => setState(() {
                _activity = v!;
                _showResult = false;
              }),
              child: Column(
                children: [
                  for (final a in ActivityLevel.values)
                    RadioListTile<ActivityLevel>(
                      contentPadding: EdgeInsets.zero,
                      value: a,
                      title: Text(ProfileForm.activityLabel(a)),
                      subtitle: Text(ProfileForm.activityHint(a)),
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
                  ButtonSegment(
                    value: g,
                    label: Text(ProfileForm.goalLabel(g)),
                  ),
              ],
              selected: {_goal},
              onSelectionChanged: (v) => setState(() {
                _goal = v.first;
                _showResult = false;
              }),
            ),
            const SizedBox(height: 16),

            TextFormField(
              key: const Key('target_weight_field'),
              controller: _targetWeight,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: '目標體重（可不填）',
                suffixText: '公斤',
              ),
              validator: ProfileForm.validateTargetWeight,
            ),
            const SizedBox(height: 24),

            FilledButton(
              key: const Key('calculate_button'),
              onPressed: _saving ? null : _calculate,
              child: const Text('計算我的每日熱量'),
            ),
            const SizedBox(height: 24),

            if (_showResult) _buildResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    final bmi = EnergyCalculator.bmi(weightKg: _weightKg, heightCm: _heightCm);
    final bmr = EnergyCalculator.bmr(
      sex: _sex,
      ageYears: _age,
      heightCm: _heightCm,
      weightKg: _weightKg,
    );
    final tdee = EnergyCalculator.tdee(
      sex: _sex,
      ageYears: _age,
      heightCm: _heightCm,
      weightKg: _weightKg,
      activityLevel: _activity,
    );
    final suggested = EnergyCalculator.dailyCalorieTarget(
      sex: _sex,
      ageYears: _age,
      heightCm: _heightCm,
      weightKg: _weightKg,
      activityLevel: _activity,
      goal: _goal,
    );
    final target = _calorieOverride ?? suggested;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('計算結果', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _row(
              'BMI',
              '${bmi.toStringAsFixed(1)}（${ProfileForm.bmiLabel(bmi)}）',
            ),
            _row('基礎代謝率 BMR', '${bmr.round()} 大卡'),
            _row('每日總消耗 TDEE', '${tdee.round()} 大卡'),
            const Divider(height: 24),
            _row('建議每日攝取', '$suggested 大卡'),
            const SizedBox(height: 8),
            Text(
              key: const Key('final_target_text'),
              '目前設定的目標：$target 大卡',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              key: const Key('edit_target_button'),
              icon: const Icon(Icons.edit),
              label: const Text('自行調整目標'),
              onPressed: () => _editTarget(target),
            ),
            const SizedBox(height: 8),
            Text(
              'BMI 與熱量僅供一般參考，不是醫療建議。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const Key('save_profile_button'),
              onPressed: _saving ? null : () => _save(target, suggested),
              child: _saving
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('開始使用'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTarget(int current) async {
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
    if (result != null) setState(() => _calorieOverride = result.round());
  }

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child: Text(label)),
        Text(value),
      ],
    ),
  );
}
