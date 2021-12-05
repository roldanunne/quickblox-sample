import 'package:chatappmedref/chat_page.dart';
import 'package:chatappmedref/gbl_fn.dart';
import 'package:chatappmedref/storage_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:quickblox_sdk/auth/module.dart';
import 'package:quickblox_sdk/models/qb_session.dart';
import 'package:quickblox_sdk/models/qb_settings.dart';
import 'package:quickblox_sdk/models/qb_user.dart';
import 'package:quickblox_sdk/quickblox_sdk.dart';
import 'package:chatappmedref/credentials.dart';

class LoginPage extends StatefulWidget {
  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {

  bool _isLoading = false;
  TextEditingController _username = TextEditingController();
  TextEditingController _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialized();
  }
  
  @override
  void dispose() async {
    super.dispose();
    await QB.auth.logout();
  }

  void _loadInitialized() async {
    try {
      await QB.settings.init(APP_ID, AUTH_KEY, AUTH_SECRET, ACCOUNT_KEY);
      print("==>Credentials loaded!");
      await QB.settings.initStreamManagement(3, autoReconnect: true);
      print("==>Stanza settings loaded!");
    } on PlatformException catch (e) {
      print(e);
    }
  }
  
  void login(username,password) async {
    setState(() { _isLoading = true; });
    try {
      QBLoginResult result = await QB.auth.login(username, password);
      print("==>Authorization success!");

      // After login get the user details
      QBSession? session = result.qbSession;
      var userId  = session!.userId;
      
      StorageData.setStringValue('username', username);
      StorageData.setStringValue('password', password);
      StorageData.setIntValue('userid', userId!);
      
      bool? connected = await QB.chat.isConnected();
      if(connected!){
        print("==>Disconnect Chat connection!");
        await QB.chat.disconnect();
      }
      
      // Chat connect login get the user details
      await QB.chat.connect(session.userId!, password!);
      await QB.settings.enableAutoReconnect(true);
      print("==>New Chat connection!");

      Navigator.push(context, new MaterialPageRoute(builder: (context) => ChatPage()));
    } on PlatformException catch (e) {
      print("==>"+e.toString());
      print("==>1"+e.toString());
    }
    setState(() { _isLoading = false; });
  }
  
  @override
  Widget build(BuildContext context) {

    Widget _handleLogin() {
      return Card(
        margin: const EdgeInsets.all(20.0),
        elevation: 2,
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Column(
            children: <Widget>[
              Column(
                crossAxisAlignment : CrossAxisAlignment.start,
                children: <Widget> [
                  Text('User Name:', style:TextStyle(color: Color(0xFF4F4D4D), fontSize:14.0, fontWeight:FontWeight.bold)),
                  TextField(
                    controller: _username,
                    decoration: new InputDecoration(
                      contentPadding: EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF0EEEE), width: 1.0)
                      ),
                    ),
                  ),
                ]
              ),
              SizedBox(height: 15.0),
              Column(
                crossAxisAlignment : CrossAxisAlignment.start,
                children: <Widget> [
                  Text('Password:', style:TextStyle(color: Color(0xFF4F4D4D), fontSize:14.0, fontWeight:FontWeight.bold)),
                  TextField(
                    controller: _password,
                    decoration: new InputDecoration(
                      contentPadding: EdgeInsets.all(10),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: Color(0xFFF0EEEE), width: 1.0)
                      ),
                    ),
                    obscureText: true,
                  ),
                ]
              ),
              SizedBox(height: 15.0), 
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(150, 48),
                  primary: Color(0xFF008029),
                  shape: new RoundedRectangleBorder(
                    borderRadius: new BorderRadius.circular(5.0),
                  ),
                ),
                child: Text("Login",style: TextStyle(color: Colors.white, fontSize: 20)),
                onPressed: () {
                  if (_username.text.isEmpty) {
                    GblFn.showMsg("Please enter username!");
                  } else if (_password.text.isEmpty) {
                    GblFn.showMsg("Please enter your password!");
                  } else {
                    login(_username.text,_password.text);
                  }
                }
              ),
            ],
          )
        )
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("Login Doctor Page"),
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        opacity: 0.5,
        progressIndicator: CircularProgressIndicator(),
        child: SingleChildScrollView(
          child: Column(
            children: <Widget>[
              _handleLogin(),
            ]
          ),
        ),
      ),
    );
  }
}
