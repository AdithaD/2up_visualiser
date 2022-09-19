import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

class UpFlowPieChart extends StatelessWidget {
  UpFlowPieChart({
    Key? key,
    required this.player1Contribution,
    required this.player2Contribution,
    required this.unaccountedContribution,
    this.otherAccountContribution,
  }) : super(key: key);

  final int player1Contribution;
  final int player2Contribution;
  final int unaccountedContribution;

  final Map<String, int>? otherAccountContribution;

  int get total {
    var otherAccountTotalContribution = 0;
    if (otherAccountContribution != null) {
      for (var i in otherAccountContribution!.entries) {
        otherAccountTotalContribution += i.value;
      }
    }
    return player1Contribution +
        player2Contribution +
        unaccountedContribution +
        otherAccountTotalContribution;
  }

  @override
  Widget build(BuildContext context) {
    var titleStyle = Theme.of(context)
        .textTheme
        .bodyMedium!
        .copyWith(fontWeight: FontWeight.bold, color: Colors.white);

    var otherSections = getOtherAccountSections(titleStyle);

    Map<String, Color> otherIndicators =
        otherSections.map((key, value) => MapEntry(key, value.color));

    return Column(
      children: [
        Flexible(
          flex: 4,
          child: PieChart(PieChartData(sections: [
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
                titleStyle: titleStyle),
            ...otherSections.values
          ])),
        ),
        Flexible(
          flex: 1,
          child: Center(
            child: UpChartIndicators(
              otherKeys: otherIndicators,
            ),
          ),
        ),
      ],
    );
  }

  List<Color> otherColors = [
    Colors.indigo,
    Colors.teal,
    Colors.orange,
    Colors.brown,
  ];

  Map<String, PieChartSectionData> getOtherAccountSections(
      TextStyle titleStyle) {
    var otherAccountContribution = this.otherAccountContribution;

    Map<String, PieChartSectionData> otherSections = {};
    if (otherAccountContribution != null) {
      var index = 0;
      for (var oAccount in otherAccountContribution.entries) {
        otherSections.putIfAbsent(
            oAccount.key,
            () => PieChartSectionData(
                value: oAccount.value / total,
                color: otherColors[index % otherColors.length],
                title: "${oAccount.value / 100}",
                titleStyle: titleStyle));
        index++;
      }
    }

    return otherSections;
  }
}

class UpChartIndicators extends StatelessWidget {
  final Map<String, Color>? otherKeys;

  const UpChartIndicators({
    this.otherKeys,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      var otherKeys = getOtherKeys(constraints);
      return Table(
        children: generateRows(otherKeys, constraints, 3),
      );
    });
  }

  List<Widget> getOtherKeys(BoxConstraints constraints) {
    List<Widget> otherWidgets = [];
    var otherKeys = this.otherKeys;
    if (otherKeys != null) {
      for (var o in otherKeys.entries) {
        otherWidgets.add(Indicator(color: o.value, label: o.key));
      }
    }

    return otherWidgets;
  }

  List<TableRow> generateRows(
      List<Widget> otherKeys, BoxConstraints constraints, int rowSize) {
    var indicators = [
      Indicator(
        color: Colors.pink,
        label: constraints.maxWidth < 300 ? 'P1' : 'Player 1',
      ),
      Indicator(
        color: Colors.purple,
        label: constraints.maxWidth < 300 ? 'P2' : 'Player 2',
      ),
      Indicator(
        color: Colors.grey,
        label: constraints.maxWidth < 300 ? 'Unacc.' : 'Unaccounted',
      ),
      ...otherKeys
    ];

    List<TableRow> rows = [];
    for (var i = 0; i < otherKeys.length + 3; i += rowSize) {
      int endIndex = min(i + rowSize, otherKeys.length + 3);
      var rowChildren = indicators.sublist(i, endIndex);
      while (rowChildren.length < rowSize) {
        rowChildren.add(Container());
      }
      rows.add(TableRow(children: rowChildren));
    }

    print(rows);
    return rows;
  }
}

class Indicator extends StatelessWidget {
  const Indicator({
    super.key,
    required this.label,
    this.color = Colors.red,
    this.textColor = Colors.white,
  });

  final Color color;
  final Color textColor;
  final String label;
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      height: 30,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 20, width: 20, child: Container(color: color)),
          const SizedBox(
            width: 5,
          ),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodyText2!
                .copyWith(color: textColor),
          )
        ],
      ),
    );
  }
}
