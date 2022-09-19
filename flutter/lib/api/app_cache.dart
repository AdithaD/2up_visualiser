import 'dart:convert';
import 'dart:io';

import 'package:_2up_visualiser/api/up_api.dart';
import 'package:path_provider/path_provider.dart';

const cacheTimeout = 86400;
const cacheDirectory = "/cache/";

String getCacheDirectory() {
  return cacheDirectory;
}

String getCachePath(String appDocDirPath, String fileName) {
  return "$appDocDirPath$cacheDirectory$fileName";
}

String generateCacheFileName(String apiEndpoint, String token) {
  String fileName =
      "${token.substring(8, 13)}_${apiEndpoint.replaceAll(RegExp(r'/'), "_")}.json";
  return fileName;
}

Future<void> cacheData(String fileName, dynamic data) async {
  var cacheObject = {
    'meta': {
      'epochTime': DateTime.now().millisecondsSinceEpoch,
    },
    'cache': data,
  };

  var appDocDir = await getApplicationDocumentsDirectory();
  File cacheFile = File(getCachePath(appDocDir.path, fileName));
  cacheFile.createSync();
  cacheFile.writeAsStringSync(jsonEncode(cacheObject));
}

Future<void> clearCache() async {
  Directory appDocDir = await getApplicationDocumentsDirectory();

  Directory cacheDir = Directory(appDocDir.path + cacheDirectory);
  cacheDir.deleteSync(recursive: true);
  cacheDir.createSync();
}

Future<Map<dynamic, dynamic>> getFromCacheOrUpdate(
    String apiEndpoint, String token, int updateTimeout,
    {bool forceRefresh = false, bool shouldPaginate = true}) async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  String fileName = generateCacheFileName(apiEndpoint, token);
  print(fileName);
  File file = File(getCachePath(appDocDir.path, fileName));

  if (file.existsSync() && !forceRefresh) {
    var json = jsonDecode(file.readAsStringSync());

    int epochTimeSaved = json["meta"]["epochTime"];

    if (DateTime.now().millisecondsSinceEpoch >
        epochTimeSaved + updateTimeout) {
      var data =
          await getFromApi(apiEndpoint, token, shouldPaginate: shouldPaginate);

      file.deleteSync();
      cacheData(fileName, data);
      return data;
    } else {
      return json["cache"];
    }
  } else {
    var data =
        await getFromApi(apiEndpoint, token, shouldPaginate: shouldPaginate);

    cacheData(fileName, data);
    return data;
  }
}
