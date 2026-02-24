// lib/widgets/performance_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class PerformancePieChart extends StatelessWidget {
  final int passed;
  final int failed;

  const PerformancePieChart({super.key, required this.passed, required this.failed});

  @override
  Widget build(BuildContext context) {
    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 40, // Makes it a "Donut" chart
        sections: [
          PieChartSectionData(
            value: passed.toDouble(),
            title: 'Passed',
            color: Colors.greenAccent,
            radius: 50,
            titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          PieChartSectionData(
            value: failed.toDouble(),
            title: 'Failed',
            color: Colors.redAccent,
            radius: 50,
            titleStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
        ],
      ),
    );
  }
}