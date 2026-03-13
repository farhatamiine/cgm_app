import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/colors.dart';
import 'home_screen.dart';
import 'log_hub_screen.dart';
import 'statistics_screen.dart';
import 'ai_insights_screen.dart';
import 'profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const LogHubScreen(),
    const StatisticsScreen(),
    const AiInsightsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgCard,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowColorDark,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                _navItem(0, Icons.home_rounded, 'HOME'),
                _navItem(1, Icons.add_circle_outline_rounded, 'LOG'),
                _navItem(2, Icons.bar_chart_rounded, 'STATS'),
                _navItem(3, Icons.auto_awesome_rounded, 'AI'),
                _navItem(4, Icons.person_outline_rounded, 'PROFILE'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _navItem(int index, IconData icon, String label) {
    final isActive = _currentIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _currentIndex = index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.accentGreen : AppColors.navInactive,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.outfit(
                fontSize: 9,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: isActive ? AppColors.accentGreen : AppColors.navInactive,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
