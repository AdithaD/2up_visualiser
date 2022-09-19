import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart' as intl;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:_2up_visualiser/api/app_cache.dart';

const upApiUrl = "https://api.up.com.au/api/v1";
final currencyFormat = intl.NumberFormat("#,##0.00", "en_US");

enum APIExceptionType { NOT_FOUND, NOT_AUTHORISED, OTHER }

APIExceptionType extractType(http.Response res) {
  switch (res.statusCode) {
    case 404:
      return APIExceptionType.NOT_FOUND;
    case 401:
      return APIExceptionType.NOT_AUTHORISED;
    default:
      return APIExceptionType.NOT_FOUND;
  }
}

class APIException implements Exception {
  final APIExceptionType type;

  String getErrorMessage() {
    switch (type) {
      case APIExceptionType.NOT_FOUND:
        return "A resource could not be found.";
      case APIExceptionType.NOT_AUTHORISED:
        return "Your tokens are not authorised.";
      default:
        return "Network error";
    }
  }

  APIException(http.Response res) : type = extractType(res);
}

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

  int get netFlow {
    return inFlow + outFlow;
  }

  @override
  String toString() {
    return "In: $inFlow, Out: $outFlow";
  }

  Cashflow(this.inFlow, this.outFlow);
}

class AccountByPlayer {
  final String accountId;
  final String? accountName;
  final Cashflow player1Cashflow;
  final Cashflow player2Cashflow;
  final Cashflow unaccountedCashflow;
  final Map<String, Cashflow> sharedCashflows;

  const AccountByPlayer(this.accountId, this.player1Cashflow,
      this.player2Cashflow, this.unaccountedCashflow, this.sharedCashflows,
      {this.accountName});
  bool operator ==(dynamic other) =>
      other != null && other is AccountByPlayer && accountId == other.accountId;

  @override
  int get hashCode => Object.hashAllUnordered([accountId]);
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

  if (response.statusCode != 200) throw APIException(response);

  return decodedResponse;
}

Future<Map<dynamic, dynamic>> getFromApi(String endpoint, String token,
    {shouldPaginate = true}) async {
  var url = Uri.parse("$upApiUrl/$endpoint");

  var body = await getFrom(url.toString(), token);

  List<Map<String, dynamic>> data = [...body["data"]];

  while (body["links"]["next"] != null && shouldPaginate) {
    body = await getFrom(body["links"]["next"], token);

    data = [...body["data"], ...data];
  }
  return {"data": data};
}

// Filename is first 5 characters of token _ endpoint

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
    print("loading $id");
    var data = await getFromCacheOrUpdate(
        "accounts/$id/transactions", authToken, 86400 * 1000);

    jointTransactions.putIfAbsent(id, () => [...data["data"]]);
    print("end load $id");
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
  return currencyFormat.format(valueInCents / 100);
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

Future<AccountByPlayer?> generateTotalCashflow() async {
  final prefs = await SharedPreferences.getInstance();

  final token1 = prefs.getString("token1");
  final token2 = prefs.getString("token2");

  if (token1 != null && token2 != null) {
    var player1AccountsJSON =
        await getFromCacheOrUpdate("accounts", token1, cacheTimeout);
    var player2AccountsJSON =
        await getFromCacheOrUpdate("accounts", token2, cacheTimeout);

    var player1AccountIds = extractAccountIds(player1AccountsJSON);
    var player2AccountIds = extractAccountIds(player2AccountsJSON);

    var sharedTransactionsByAccount =
        await getJointTransactions(player1AccountIds.jointAccounts, token1);

    AccountByPlayer totalCashflows = generateTotals(
        sharedTransactionsByAccount, player1AccountIds, player2AccountIds);

    return totalCashflows;
  } else {
    return null;
  }
}

Future<Map<String, AccountByPlayer>?> getAccountBreakdown() async {
  final prefs = await SharedPreferences.getInstance();

  final token1 = prefs.getString("token1");
  final token2 = prefs.getString("token2");

  if (token1 != null && token2 != null) {
    var player1AccountsJSON =
        await getFromCacheOrUpdate("accounts", token1, cacheTimeout);
    var player2AccountsJSON =
        await getFromCacheOrUpdate("accounts", token2, cacheTimeout);

    var player1AccountIds = extractAccountIds(player1AccountsJSON);
    var player2AccountIds = extractAccountIds(player2AccountsJSON);

    var player1AccountNameMap = mapAccountIdsToName(player1AccountsJSON);

    var sharedTransactionsByAccount =
        await getJointTransactions(player1AccountIds.jointAccounts, token1);

    Map<String, AccountByPlayer> breakdown = {};

    for (var st in sharedTransactionsByAccount.keys) {
      var accountName = player1AccountNameMap[st];
      var transactions = sharedTransactionsByAccount[st];

      var generatedAbp = getCashFlowByPlayer(
          st, transactions ?? [], player1AccountIds, player2AccountIds);

      breakdown.putIfAbsent(
          st,
          () => AccountByPlayer(
              generatedAbp.accountId,
              generatedAbp.player1Cashflow,
              generatedAbp.player2Cashflow,
              generatedAbp.unaccountedCashflow,
              generatedAbp.sharedCashflows,
              accountName: accountName));
    }
    return breakdown;
  } else {
    return null;
  }
}

Future<String> generateAccountSummary() async {
  List<String> outputLines = [];
  final prefs = await SharedPreferences.getInstance();

  final token1 = prefs.getString("token1");
  final token2 = prefs.getString("token2");

  if (token1 != null && token2 != null) {
    var player1AccountsJSON =
        await getFromCacheOrUpdate("accounts", token1, cacheTimeout);
    var player2AccountsJSON =
        await getFromCacheOrUpdate("accounts", token2, cacheTimeout);

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
