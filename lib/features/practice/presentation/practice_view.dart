import 'package:flutter/material.dart';
import '../../tuner/presentation/tuner_controller.dart';
import '../../../core/theme/app_theme.dart';
import 'tabs/bends_practice_tab.dart';
import 'tabs/placeholder_tab.dart';
import 'tabs/fretboard_practice_tab.dart';

class PracticeView extends StatefulWidget {
  final TunerController controller;

  const PracticeView({super.key, required this.controller});

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primaryAccent,
          labelColor: AppColors.primaryAccent,
          unselectedLabelColor: AppColors.textSecondary,
          tabs: const [
            Tab(text: "Bends"),
            Tab(text: "Chords"),
            Tab(text: "Fretboard"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              BendsPracticeTab(controller: widget.controller),
              const PlaceholderTab(
                title: "Chords Practice",
                message: "To be implemented",
                icon: Icons.grid_on,
              ),
              FretboardPracticeTab(controller: widget.controller),
            ],
          ),
        ),
      ],
    );
  }
}
