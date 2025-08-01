import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'token.dart';

// Future<String> getToken() async {

//     final directory = await getApplicationDocumentsDirectory();

//     var _localPath =  directory.path;
    
//     final path = await _localPath;
//     File _localFile = File('$path/logodevtoken.txt');

//   try {
//     // Read the file
//     final contents = await _localFile.readAsString();
//     print('Token read from file: $contents');
//     return contents.trim();
//   } catch (e) {
//     // If encountering an error, return 0
//     return "";
//   }
// }

class LogoManager {
  static final Dio _dio = Dio();
  static const String _baseUrl = 'https://img.logo.dev/ticker';

  Future<String> fetchLogoPath(String symbol) async {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/logos';
    final file = File('$path/$symbol.png');

    // final response = await _dio.get('$_baseUrl/$symbol?token=$token');

    // If already downloaded, return local path (to not waste any Api daily requests)
    if (await file.exists()) {
      return file.path;
    }

    // If not downloaded, download and save
    try {
      final token = await getLogoToken(); // get token properly>
      await Directory(path).create(recursive: true);
      final response = await _dio.get(
        '$_baseUrl/$symbol?',
        queryParameters: {'token': token,'format':'jpg', 'theme': 'dark'},
        options: Options(responseType: ResponseType.bytes),
      );
      await file.writeAsBytes(response.data);
      return file.path;
    } catch (e) {
      throw Exception('Failed to load logo: $e');
    }

  }
}