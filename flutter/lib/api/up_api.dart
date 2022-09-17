import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

const UP_API_URL = "https://api.up.com.au/api/v1";
final CURRENCY_FORMAT = intl.NumberFormat("#,##0.00", "en_US");

class Cashflow {
  int inFlow;
  int outFlow;

  operator +(Cashflow other) {
    return Cashflow(inFlow + other.inFlow, outFlow + other.outFlow);
  }

  void update(int amount) {
    if (amount > 0) {
      inFlow += amount;
    } else {
      outFlow += amount;
    }
  }

  @override
  String toString() {
    return "In: $inFlow, Out: $outFlow";
  }

  Cashflow(this.inFlow, this.outFlow);
}

class AccountByPlayer {
  final String accountId;
  final Cashflow player1Cashflow;
  final Cashflow player2Cashflow;
  final Cashflow unaccountedCashflow;
  final Map<String, Cashflow> sharedCashflows;

  const AccountByPlayer(this.accountId, this.player1Cashflow,
      this.player2Cashflow, this.unaccountedCashflow, this.sharedCashflows);
}

class PlayerAccountIds {
  final List<String> individualAccounts;
  final List<String> jointAccounts;

  const PlayerAccountIds(this.individualAccounts, this.jointAccounts);
}

Future<Map<dynamic, dynamic>> getFrom(String url, String token) async {
  var response = await http
      .get(Uri.parse(url), headers: {'Authorization': "Bearer $token"});

  var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;

  return decodedResponse;
}

Future<Map<dynamic, dynamic>> getFromApi(String endpoint, String token) async {
  var url = Uri.parse("$UP_API_URL/$endpoint");

  var response =
      await http.get(url, headers: {'Authorization': "Bearer $token"});

  var decodedResponse = jsonDecode(utf8.decode(response.bodyBytes)) as Map;

  return decodedResponse;
}

Map<String, String> mapAccountIdsToName(Map<dynamic, dynamic> accountJson) {
  List<dynamic> accounts = accountJson["data"];
  Map<String, String> idsToNames = {};

  for (var account in accounts) {
    idsToNames.putIfAbsent(
        account["id"], () => account["attributes"]["displayName"]);
  }

  return idsToNames;
}

PlayerAccountIds extractAccountIds(Map<dynamic, dynamic> accountJson) {
  List<dynamic> accounts = accountJson["data"];
  List<String> ids = [];
  List<String> jointIds = [];

  for (var account in accounts) {
    if (account["attributes"]["ownershipType"] == "JOINT") {
      jointIds.add(account["id"]);
    } else {
      ids.add(account["id"]);
    }
  }

  return PlayerAccountIds(ids, jointIds);
}

Future<Map<String, List<Map<String, dynamic>>>> getJointTransactions(
    List<String> jointAccountIds, String authToken) async {
  Map<String, List<Map<String, dynamic>>> jointTransactions = {};

  for (var id in jointAccountIds) {
    var response = await getFromApi("accounts/$id/transactions", authToken);

    List<Map<String, dynamic>> data = [...response["data"]];

    while (response["links"]["next"] != null) {
      response = await getFrom(response["links"]["next"], authToken);

      data = [...response["data"], ...data];
    }

    jointTransactions.putIfAbsent(id, () => data);
  }

  return jointTransactions;
}

AccountByPlayer getCashFlowByPlayer(
    String accountId,
    List<Map<String, dynamic>> transactions,
    PlayerAccountIds player1AccountIds,
    PlayerAccountIds player2AccountIds) {
  Cashflow player1Cashflow = Cashflow(0, 0);
  Cashflow player2Cashflow = Cashflow(0, 0);
  Map<String, Cashflow> _2upInternalCashflow = {};
  Cashflow unaccountedCashflow = Cashflow(0, 0);

  for (var jaId in player1AccountIds.jointAccounts) {
    _2upInternalCashflow.putIfAbsent(jaId, () => Cashflow(0, 0));
  }

  for (var t in transactions) {
    int valueInBaseUnits = t["attributes"]["amount"]["valueInBaseUnits"];

    Map<String, dynamic> transferAccount =
        t["relationships"]["transferAccount"];

    if (transferAccount["data"] != null) {
      String transferAccountId = transferAccount["data"]["id"];

      if (player1AccountIds.individualAccounts.contains(transferAccountId)) {
        player1Cashflow.update(valueInBaseUnits);
      } else if (player2AccountIds.individualAccounts
          .contains(transferAccountId)) {
        player2Cashflow.update(valueInBaseUnits);
      } else if (_2upInternalCashflow.keys.contains(transferAccountId)) {
        _2upInternalCashflow[transferAccountId]!.update(valueInBaseUnits);
      }
    } else {
      unaccountedCashflow.update(valueInBaseUnits);
    }
  }

  return AccountByPlayer(accountId, player1Cashflow, player2Cashflow,
      unaccountedCashflow, _2upInternalCashflow);
}

String formatCurrency(int valueInCents) {
  return CURRENCY_FORMAT.format(valueInCents / 100);
}

AccountByPlayer generateTotals(
    Map<String, List<Map<String, dynamic>>> sharedTransactionsByAccount,
    PlayerAccountIds player1AccountIds,
    PlayerAccountIds player2AccountIds) {
  var totalPlayer1Cashflow = Cashflow(0, 0);
  var totalPlayer2Cashflow = Cashflow(0, 0);
  var totalUnaccountedCashflow = Cashflow(0, 0);

  for (var st in sharedTransactionsByAccount.keys) {
    var s = sharedTransactionsByAccount[st];
    if (s != null) {
      var abp =
          getCashFlowByPlayer(st, s, player1AccountIds, player2AccountIds);
      totalPlayer1Cashflow += abp.player1Cashflow;

      totalPlayer2Cashflow += abp.player2Cashflow;
      totalUnaccountedCashflow += abp.unaccountedCashflow;
    }
  }

  return AccountByPlayer("TOTAL", totalPlayer1Cashflow, totalPlayer2Cashflow,
      totalUnaccountedCashflow, {});
}

Future<String> generateAccountSummary() async {
  List<String> outputLines = [];
  final prefs = await SharedPreferences.getInstance();

  final token1 = prefs.getString("token1");
  final token2 = prefs.getString("token2");

  if (token1 != null && token2 != null) {
    var player1AccountsJSON = await getFromApi("accounts", token1);
    var player2AccountsJSON = await getFromApi("accounts", token2);

    var player1AccountIds = extractAccountIds(player1AccountsJSON);
    var player2AccountIds = extractAccountIds(player2AccountsJSON);

    var player1AccountNameMap = mapAccountIdsToName(player1AccountsJSON);

    outputLines
        .add("Player 1 account ids: ${player1AccountIds.individualAccounts}");
    outputLines
        .add("Player 2 account ids: ${player2AccountIds.individualAccounts}");
    outputLines.add("Shared account ids: ${player1AccountIds.jointAccounts}");

    /* if (player1AccountIds.jointAccounts != player2AccountIds.jointAccounts) {
      return "Join account mismatch";
    } */

    var sharedTransactionsByAccount =
        await getJointTransactions(player1AccountIds.jointAccounts, token1);

    AccountByPlayer totalCashflows = generateTotals(
        sharedTransactionsByAccount, player1AccountIds, player2AccountIds);
    outputLines.add(
        "Totals\n${totalCashflows.player1Cashflow}\n${totalCashflows.player2Cashflow} \n${totalCashflows.unaccountedCashflow}");

    String output = "";

    for (String s in outputLines) {
      output += s;
    }
    return output;
  } else {
    return "Couldn't load tokens";
  }
}
