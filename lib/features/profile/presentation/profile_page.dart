import 'package:flutter/material.dart';

/// P0 佔位頁。Onboarding 與 BMI/BMR/TDEE 屬於 P1。
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('我的')),
      body: const Center(child: Text('Profile placeholder')),
    );
  }
}
