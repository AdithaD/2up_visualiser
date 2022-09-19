import 'package:_2up_visualiser/api/app_cache.dart';
import 'package:_2up_visualiser/api/up_api.dart';
import 'package:_2up_visualiser/utils/up_charts.dart';
import 'package:flutter/material.dart';

import '../components/2up_visualiser_drawer.dart';

class SummaryPage extends StatefulWidget {
  const SummaryPage({
    Key? key,
  }) : super(key: key);

  @override
  State<SummaryPage> createState() => _SummaryPageState();
}

class _SummaryPageState extends State<SummaryPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const VisualiserDrawer(),
      appBar: AppBar(
        title: const Text("2UP Account Summary"),
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
              var inflowChartCard = SummaryCard(
                  title: "Total inflow",
                  child: UpFlowPieChart(
                    player1Contribution: totalCashflow.player1Cashflow.inFlow,
                    player2Contribution: totalCashflow.player2Cashflow.inFlow,
                    unaccountedContribution:
                        totalCashflow.unaccountedCashflow.inFlow,
                  ));
              var outflowChartCard = SummaryCard(
                  title: "Total outflow",
                  child: UpFlowPieChart(
                    player1Contribution:
                        totalCashflow.player1Cashflow.outFlow.abs(),
                    player2Contribution:
                        totalCashflow.player2Cashflow.outFlow.abs(),
                    unaccountedContribution:
                        totalCashflow.unaccountedCashflow.outFlow.abs(),
                  ));
              var netContributionChartCard = SummaryCard(
                title: "Net Contribution",
                child: UpFlowBarChart(
                  player1Contribution: totalCashflow.player1Cashflow.netFlow,
                  player2Contribution: totalCashflow.player2Cashflow.netFlow,
                  unaccountedContribution:
                      totalCashflow.unaccountedCashflow.netFlow,
                ),
              );

              return LayoutBuilder(builder: (context, constraints) {
                if (constraints.maxWidth < 800) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          SizedBox(
                              height: constraints.maxHeight * 0.5,
                              child: inflowChartCard),
                          SizedBox(
                            height: constraints.maxHeight * 0.5,
                            child: outflowChartCard,
                          ),
                          SizedBox(
                            height: constraints.maxHeight * 0.8,
                            child: netContributionChartCard,
                          ),
                        ],
                      ),
                    ),
                  );
                } else {
                  return SizedBox(
                    width: constraints.maxWidth,
                    height: constraints.maxHeight,
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
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
                                    child: inflowChartCard,
                                  ),
                                  Flexible(
                                    flex: 1,
                                    child: outflowChartCard,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Flexible(
                            flex: 1,
                            child: netContributionChartCard,
                          )
                        ],
                      ),
                    ),
                  );
                }
              });
            } else if (snapshot.hasError) {
              Object e = snapshot.error!;
              if (e is APIException) {
                return Center(
                  child: Text(e.getErrorMessage()),
                );
              } else {
                return const Center(child: Text("An error occured :("));
              }
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
