import 'package:shared_preferences/shared_preferences.dart';

class StorageData {
    
    static Future<String?> getStringValue(String key) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    }

    static Future<bool> setStringValue(String key, String value) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setString(key, value);
    }

    static Future<int?> getIntValue(String key) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getInt(key);
    }

    static Future<bool> setIntValue(String key, int value) async {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.setInt(key, value);
    }

    static Future<bool> clearAll() async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.clear();
    }

    static Future<bool> removeKey(String keyname) async {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      return await prefs.remove(keyname);
    }
}