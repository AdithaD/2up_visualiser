import 'dart:math';

import 'package:_2up_visualiser/api/app_cache.dart';
import 'package:_2up_visualiser/api/up_api.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({
    Key? key,
    required this.token_1,
    required this.token_2,
  }) : super(key: key);

  final String token_1;
  final String token_2;

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
          child: Column(
        children: [
          DrawerHeader(
            child: Container(
                color: Theme.of(context).colorScheme.primary,
                child: const Center(child: Text("2UP Visualiser"))),
          ),
          Expanded(
              child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Text("Delete tokens & data"),
                onTap: () {},
              )
            ],
          ))
        ],
      )),
      appBar: AppBar(
        title: const Text("Account Summary"),
        actions: [
          IconButton(
              onPressed: () {
                clearCache();
                setState(() {});
              },
              icon: const Icon(Icons.refresh))
        ],
      ),
      body: FutureBuilder(
          future: generateTotalCashflow(),
          builder: (context, snapshot) {
            var totalCashflow = snapshot.data;

            if (snapshot.connectionState == ConnectionState.done &&
                totalCashflow != null) {
              return LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 500) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      child: Column(
                        children: [
                          SizedBox(
                            height: constraints.maxHeight * 0.5,
                            child: SummaryCard(
                                title: "Total inflow",
                                child: UpFlowPieChart(
                                  player1Contribution:
                                      totalCashflow.player1Cashflow.inFlow,
                                  player2Contribution:
                                      totalCashflow.player2Cashflow.inFlow,
                                  unaccountedContribution:
                                      totalCashflow.unaccountedCashflow.inFlow,
                                )),
                          ),
                          SizedBox(
                              height: constraints.maxHeight * 0.5,
                              child: SummaryCard(
                                  title: "Total outflow",
                                  child: UpFlowPieChart(
                                    player1Contribution: totalCashflow
                                        .player1Cashflow.outFlow
                                        .abs(),
                                    player2Contribution: totalCashflow
                                        .player2Cashflow.outFlow
                                        .abs(),
                                    unaccountedContribution: totalCashflow
                                        .unaccountedCashflow.outFlow
                                        .abs(),
                                  ))),
                          SizedBox(
                              height: constraints.maxHeight * 0.8,
                              child: SummaryCard(
                                title: "Total contribution",
                                child: UpFlowBarChart(
                                  player1Contribution:
                                      totalCashflow.player1Cashflow.netFlow,
                                  player2Contribution:
                                      totalCashflow.player2Cashflow.netFlow,
                                  unaccountedContribution:
                                      totalCashflow.unaccountedCashflow.netFlow,
                                ),
                              )),
                        ],
                      ),
                    ),
                  );
                } else {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8.0, horizontal: 16.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Flexible(
                            flex: 1,
                            child: SizedBox(
                              height: constraints.maxHeight,
                              child: Column(
                                children: [
                                  Flexible(
                                    flex: 1,
                                    child: SummaryCard(
                                        title: "Total inflow",
                                        child: UpFlowPieChart(
                                          player1Contribution: totalCashflow
                                              .player1Cashflow.inFlow,
                                          player2Contribution: totalCashflow
                                              .player2Cashflow.inFlow,
                                          unaccountedContribution: totalCashflow
                                              .unaccountedCashflow.inFlow,
                                        )),
                                  ),
                                  Flexible(
                                    flex: 1,
                                    child: SummaryCard(
                                        title: "Total outflow",
                                        child: UpFlowPieChart(
                                          player1Contribution: totalCashflow
                                              .player1Cashflow.outFlow
                                              .abs(),
                                          player2Contribution: totalCashflow
                                              .player2Cashflow.outFlow
                                              .abs(),
                                          unaccountedContribution: totalCashflow
                                              .unaccountedCashflow.outFlow
                                              .abs(),
                                        )),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Flexible(
                            flex: 1,
                            child: SummaryCard(
                              title: "Total contribution",
                              child: UpFlowBarChart(
                                player1Contribution:
                                    totalCashflow.player1Cashflow.netFlow,
                                player2Contribution:
                                    totalCashflow.player2Cashflow.netFlow,
                                unaccountedContribution:
                                    totalCashflow.unaccountedCashflow.netFlow,
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  );
                }
              });
            } else {
              return Align(
                  alignment: Alignment.center,
                  child: SizedBox(
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        CircularProgressIndicator(),
                        Text("Loading your data")
                      ],
                    ),
                  ));
            }
          }),
    );
  }
}

class UpFlowBarChart extends StatelessWidget {
  const UpFlowBarChart({
    Key? key,
    required this.player1Contribution,
    required this.player2Contribution,
    required this.unaccountedContribution,
  }) : super(key: key);

  final int player1Contribution;
  final int player2Contribution;
  final int unaccountedContribution;

  @override
  Widget build(BuildContext context) {
    return BarChart(BarChartData(
        gridData: FlGridData(show: true),
        maxY: (max(
                max(player1Contribution.toDouble(),
                    player2Contribution.toDouble()),
                unaccountedContribution.toDouble()) *
            1.5 /
            100),
        minY: min(
            min(
                    min(player1Contribution.toDouble(),
                        player2Contribution.toDouble()),
                    unaccountedContribution.toDouble()) *
                1.5 /
                100,
            0),
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: player1Contribution.toDouble() / 100),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: player2Contribution.toDouble() / 100),
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(toY: unaccountedContribution.toDouble() / 100),
          ])
        ],
        titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: leftTitles,
                reservedSize: 42,
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: bottomTitles,
                reservedSize: 42,
              ),
            ),
            rightTitles: AxisTitles(),
            topTitles: AxisTitles())));
  }

  Widget leftTitles(double value, TitleMeta meta) {
    const style = TextStyle(
      color: Color(0xff7589a2),
      fontWeight: FontWeight.bold,
      fontSize: 14,
    );

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 0,
      child: double.parse(value.toStringAsFixed(2)) == value
          ? Text(NumberFormat.compact().format(value), style: style)
          : Container(),
    );
  }

  Widget bottomTitles(double value, TitleMeta meta) {
    List<String> titles = ["Player 1", "Player 2", "Unaccounted"];

    Widget text = Text(
      titles[value.toInt()],
      style: const TextStyle(
        color: Color(0xff7589a2),
        fontWeight: FontWeight.bold,
        fontSize: 14,
      ),
    );

    return SideTitleWidget(
      axisSide: meta.axisSide,
      space: 16, //margin top
      child: text,
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({Key? key, required this.child, this.title = ""})
      : super(key: key);

  final Widget child;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xff2c4260),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(children: [
          Text(
            title,
            textAlign: TextAlign.left,
            style: Theme.of(context)
                .textTheme
                .titleLarge!
                .copyWith(color: Colors.white),
          ),
          const SizedBox(
            height: 40,
          ),
          Expanded(
            child: Center(
              child: child,
            ),
          )
        ]),
      ),
    );
  }
}

class UpFlowPieChart extends StatelessWidget {
  const UpFlowPieChart({
    Key? key,
    required this.player1Contribution,
    required this.player2Contribution,
    required this.unaccountedContribution,
  }) : super(key: key);

  final int player1Contribution;
  final int player2Contribution;
  final int unaccountedContribution;

  int get total {
    return player1Contribution + player2Contribution + unaccountedContribution;
  }

  @override
  Widget build(BuildContext context) {
    var titleStyle = Theme.of(context)
        .textTheme
        .bodyMedium!
        .copyWith(fontWeight: FontWeight.bold, color: Colors.white);

    return PieChart(PieChartData(sections: [
      PieChartSectionData(
          value: player1Contribution / total,
          color: Colors.pink,
          title: "\$${player1Contribution / 100}",
          titleStyle: titleStyle),
      PieChartSectionData(
        value: player1Contribution / total,
        color: Colors.purple,
        title: "\$${player2Contribution / 100}",
        titleStyle: titleStyle,
      ),
      PieChartSectionData(
          value: unaccountedContribution / total,
          color: Colors.grey,
          title: "\$${unaccountedContribution / 100}",
          titleStyle: titleStyle)
    ]));
  }
}
