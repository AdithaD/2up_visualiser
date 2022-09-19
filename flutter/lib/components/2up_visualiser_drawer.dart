import 'package:_2up_visualiser/pages/breakdown_page.dart';
import 'package:_2up_visualiser/pages/summary_page.dart';
import 'package:_2up_visualiser/pages/token_page.dart';
import 'package:flutter/material.dart';

class VisualiserDrawer extends StatelessWidget {
  const VisualiserDrawer({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
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
              leading: const Icon(Icons.table_chart),
              title: const Text("2UP Account Summary"),
              onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: ((context) => const SummaryPage()))),
            ),
            ListTile(
              leading: const Icon(Icons.pie_chart),
              title: const Text("Account Breakdown"),
              onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                      builder: ((context) => const BreakdownPage()))),
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Delete tokens & data"),
              onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: ((context) => const TokenPage()))),
            ),
          ],
        ))
      ],
    ));
  }
}
