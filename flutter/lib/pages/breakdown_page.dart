import 'package:_2up_visualiser/api/app_cache.dart';
import 'package:_2up_visualiser/api/up_api.dart';
import 'package:_2up_visualiser/pages/summary_page.dart';
import 'package:_2up_visualiser/utils/up_charts.dart';
import 'package:flutter/material.dart';
import 'package:_2up_visualiser/components/2up_visualiser_drawer.dart';

class BreakdownPage extends StatefulWidget {
  const BreakdownPage({super.key});

  @override
  State<BreakdownPage> createState() => _BreakdownPageState();
}

class _BreakdownPageState extends State<BreakdownPage> {
  List<DropdownMenuItem> getMenuItems(Map<String, AccountByPlayer>? breakdown) {
    if (breakdown != null) {
      List<DropdownMenuItem<AccountByPlayer>> items = breakdown.values
          .map((e) => DropdownMenuItem<AccountByPlayer>(
                value: e,
                child: Text(e.accountName ?? e.accountId),
              ))
          .toList();

      return items;
    } else {
      return [];
    }
  }

  Map<String, AccountByPlayer>? breakdown;

  AccountByPlayer? selected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        drawer: const VisualiserDrawer(),
        appBar: AppBar(
          title: const Text("Account Breakdown"),
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
            future: getAccountBreakdown(),
            builder: (context, snapshot) {
              var breakdown = snapshot.data;

              if (breakdown != null &&
                  snapshot.connectionState == ConnectionState.done) {
                var idToNameMap = <String, String>{};
                for (var b in breakdown.entries) {
                  var aN = b.value.accountName;
                  if (aN != null) {
                    idToNameMap.putIfAbsent(b.key, () => aN);
                  }
                }

                return LayoutBuilder(builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Give me a breakdown for: ",
                                style: Theme.of(context).textTheme.headline5,
                              ),
                              DropdownButton(
                                  value: selected,
                                  items: getMenuItems(breakdown),
                                  onChanged: (value) => setState(() {
                                        selected = value;
                                      })),
                            ],
                          ),
                          Builder(builder: (context) {
                            var selected = this.selected;
                            if (selected != null) {
                              return SizedBox(
                                height: 600,
                                child: Row(
                                  children: [
                                    Flexible(
                                      flex: 1,
                                      child: SummaryCard(
                                        title: "Inflow",
                                        child: UpFlowPieChart(
                                          player1Contribution:
                                              selected.player1Cashflow.inFlow,
                                          player2Contribution:
                                              selected.player2Cashflow.inFlow,
                                          unaccountedContribution: selected
                                              .unaccountedCashflow.inFlow,
                                          otherAccountContribution: selected
                                              .sharedCashflows
                                              .map((key, value) => MapEntry(
                                                  idToNameMap[key] ?? key,
                                                  value.inFlow)),
                                        ),
                                      ),
                                    ),
                                    Flexible(
                                      flex: 1,
                                      child: SummaryCard(
                                        title: "Outflow",
                                        child: UpFlowPieChart(
                                          player1Contribution:
                                              selected.player1Cashflow.outFlow,
                                          player2Contribution:
                                              selected.player2Cashflow.outFlow,
                                          unaccountedContribution: selected
                                              .unaccountedCashflow.outFlow,
                                          otherAccountContribution: selected
                                              .sharedCashflows
                                              .map((key, value) => MapEntry(
                                                  idToNameMap[key] ?? key,
                                                  value.outFlow)),
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                              );
                            } else {
                              return Container();
                            }
                          })
                        ],
                      ),
                    ),
                  );
                });
              } else {
                return const Center(child: CircularProgressIndicator());
              }
            }));
  }
}
