import 'package:_2up_visualiser/summary_page.dart';
import 'package:_2up_visualiser/token_page.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder(
        future: SharedPreferences.getInstance(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            var sf = snapshot.data;
            if (sf != null) {
              String? token_1 = sf.getString("token1");
              String? token_2 = sf.getString("token2");
              if (token_1 != null && token_2 != null) {
                return SummaryPage(token_1: token_1, token_2: token_2);
              } else {
                return const TokenPage();
              }
            } else {
              return const Text("borken");
            }
          } else {
            return const Align(
              alignment: Alignment.center,
              child: CircularProgressIndicator(),
            );
          }
        },
      ),
    );
  }
}
