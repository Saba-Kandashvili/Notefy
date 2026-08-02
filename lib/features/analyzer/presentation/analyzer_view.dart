import 'dart:math';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/theme/app_theme.dart';
import 'analyzer_controller.dart';

class AnalyzerView extends StatefulWidget {
  const AnalyzerView({super.key});

  @override
  State<AnalyzerView> createState() => _AnalyzerViewState();
}

class _AnalyzerViewState extends State<AnalyzerView> {
  late AnalyzerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnalyzerController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.transparent, // Background handled by parent scaffold usually
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            title: const Text('Frequency Response', style: TextStyle(color: AppColors.textPrimary)),
            actions: [
              if (_controller.results.isNotEmpty && !_controller.isSweeping && !_controller.isAnalyzing)
                IconButton(
                  icon: const Icon(Icons.download, color: AppColors.primaryAccent),
                  onPressed: _controller.exportCsv,
                  tooltip: 'Export CSV',
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildControls(),
                const SizedBox(height: 24),
                Expanded(child: _buildMainContent()),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text("Sweep Duration:", style: TextStyle(color: AppColors.textSecondary)),
        const SizedBox(width: 12),
        DropdownButton<double>(
          value: _controller.sweepDuration,
          dropdownColor: AppColors.drawerBackground,
          style: const TextStyle(color: AppColors.textPrimary),
          underline: Container(height: 1, color: AppColors.primaryAccent),
          items: const [
            DropdownMenuItem(value: 10.0, child: Text("10 Seconds")),
            DropdownMenuItem(value: 20.0, child: Text("20 Seconds")),
            DropdownMenuItem(value: 30.0, child: Text("30 Seconds")),
          ],
          onChanged: _controller.isSweeping || _controller.isAnalyzing 
              ? null 
              : (val) {
                  if (val != null) _controller.setDuration(val);
                },
        ),
      ],
    );
  }

  Widget _buildMainContent() {
    if (_controller.isSweeping) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.mic, size: 64, color: AppColors.primaryAccent),
            const SizedBox(height: 16),
            Text(
              "${_controller.currentSweepFreq.toStringAsFixed(0)} Hz",
              style: const TextStyle(
                color: AppColors.primaryAccent,
                fontSize: 48,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text("Listening to sweep...", style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
            const SizedBox(height: 8),
            const Text("Keep the environment quiet", style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (_controller.isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryAccent),
            SizedBox(height: 24),
            Text("Crunching numbers...", style: TextStyle(color: AppColors.textPrimary, fontSize: 18)),
            SizedBox(height: 8),
            Text("Performing high-resolution FFT analysis", style: TextStyle(color: AppColors.textMuted)),
          ],
        ),
      );
    }

    if (_controller.results.isEmpty) {
      return Center(
        child: ElevatedButton.icon(
          onPressed: _controller.isInitialized ? _controller.startAnalysis : null,
          icon: const Icon(Icons.play_arrow),
          label: const Text("Start Analysis"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          ),
        ),
      );
    }

    // Draw Chart
    return Column(
      children: [
        Expanded(child: _buildChart()),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _controller.startAnalysis,
          icon: const Icon(Icons.refresh),
          label: const Text("Run Again"),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.cardBackground,
            foregroundColor: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildChart() {
    double minDb = double.infinity;
    double maxDb = double.negativeInfinity;

    final spots = _controller.results.map((p) {
      // Log10 for X axis
      final x = log(p.frequency) / ln10;
      final y = p.magnitudeDb;
      
      if (y < minDb) minDb = y;
      if (y > maxDb) maxDb = y;
      
      return FlSpot(x, y);
    }).toList();

    if (minDb == double.infinity) minDb = -80;
    if (maxDb == double.negativeInfinity) maxDb = 0;

    // Clamp minDb to visually zoom in on the top 40 dB of the spectrum.
    // Human hearing and EQ changes are logarithmic. A 6 dB cut in bass is massively audible,
    // but on an 80 dB scale, it's visually insignificant. Clamping the bottom of the graph
    // to maxDb - 40 makes these EQ changes visually obvious!
    minDb = max(minDb, maxDb - 40.0);

    final yRange = (maxDb - minDb).abs();
    // Ensure we have at least some range
    final effectiveRange = yRange < 1 ? 10.0 : yRange;
    
    // Add 10% padding to top and bottom
    final paddedMinY = minDb - (effectiveRange * 0.1);
    final paddedMaxY = maxDb + (effectiveRange * 0.1);
    
    // Dynamically calculate grid interval (roughly 5 horizontal lines)
    final double yInterval = (paddedMaxY - paddedMinY) / 5;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryAccent.withValues(alpha: 0.2)),
      ),
      child: LineChart(
        LineChartData(
          minX: log(20) / ln10,
          maxX: log(20000) / ln10,
          minY: paddedMinY,
          maxY: paddedMaxY,
          clipData: const FlClipData.all(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (List<LineBarSpot> touchedSpots) {
                return touchedSpots.map((spot) {
                  final freq = pow(10, spot.x);
                  return LineTooltipItem(
                    '${freq.toInt()} Hz\n${spot.y.toStringAsFixed(1)} dB',
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: yInterval > 0 ? yInterval : 10,
            getDrawingHorizontalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1),
            getDrawingVerticalLine: (value) => const FlLine(color: Colors.white12, strokeWidth: 1),
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  final freq = pow(10, value);
                  if ((freq - 20).abs() < 5 || (freq - 100).abs() < 20 || (freq - 1000).abs() < 200 || (freq - 10000).abs() < 2000) {
                    String text = '';
                    if (freq < 50) text = '20';
                    else if (freq < 200) text = '100';
                    else if (freq < 2000) text = '1k';
                    else text = '10k';
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(text, style: const TextStyle(color: AppColors.textMuted, fontSize: 10)),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (value, meta) {
                  return Text('${value.toInt()} dB', style: const TextStyle(color: AppColors.textMuted, fontSize: 10));
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              color: AppColors.primaryAccent,
              barWidth: 2,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: AppColors.primaryAccent.withValues(alpha: 0.1),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
