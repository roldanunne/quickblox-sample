import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io';
import 'dart:io' show Platform;

import 'package:fluttertoast/fluttertoast.dart';


class GblFn {
  GblFn._();

  static bool isConnected = false;
  
  static loadScreen(BuildContext _context, var page) {
    return Navigator.pushReplacement(_context, MaterialPageRoute(builder: (_context) => page));
  }

  static pushScreen(BuildContext _context, var page) {
    return Navigator.push(_context, MaterialPageRoute(builder: (_context) => page));
  }

  static getPlatform() {
    // Get the operating system as a string 'ios|android|linux|macos|windows|fuchsia
    return Platform.operatingSystem;
  } 

  static showMsg(msg) { 
    Fluttertoast.showToast(
        msg: msg,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black54,
        textColor: Colors.white,
        fontSize: 16.0
    );
   }

}
