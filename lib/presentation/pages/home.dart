import 'package:flutter/material.dart';

import 'evaluations_page.dart';
import 'history_page.dart';
import 'settings_page.dart';

// Adapted from flutter_easy_refresh v4 example: page/home.dart
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _pageController = PageController();
  int _pageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        controller: _pageController,
        children: const [EvaluationsPage(), HistoryPage(), SettingsPage()],
        onPageChanged: (index) => setState(() => _pageIndex = index),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _pageIndex,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        onTap: (index) => _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 200),
          curve: Curves.linear,
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.rocket_launch),
            label: 'Inicio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history),
            label: 'Historial',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Ajustes'),
        ],
      ),
    );
  }
}
