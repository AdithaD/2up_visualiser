import 'package:_2up_visualiser/api/app_cache.dart';
import 'package:_2up_visualiser/api/up_api.dart';
import 'package:flutter/material.dart';

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
          future: generateAccountSummary(),
          builder: (context, snapshot) {
            String? summary = snapshot.data;
            if (snapshot.connectionState == ConnectionState.done &&
                summary != null) {
              return Container(
                color: Colors.red,
                child: Column(children: [
                  Text(
                    widget.token_1,
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                  const SizedBox(
                    height: 40,
                  ),
                  Text(
                    widget.token_2,
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                  Text(
                    summary,
                    style: Theme.of(context).textTheme.bodyText1,
                  ),
                ]),
              );
            } else {
              return const Align(
                  alignment: Alignment.center,
                  child: CircularProgressIndicator());
            }
          }),
    );
  }
}
