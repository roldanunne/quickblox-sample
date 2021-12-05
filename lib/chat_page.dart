import 'dart:async';
import 'package:bubble/bubble.dart';
import 'package:chatappmedref/call_page.dart';
import 'package:chatappmedref/chat_page_message.dart';
import 'package:chatappmedref/storage_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:loading_overlay/loading_overlay.dart';
import 'package:quickblox_sdk/chat/constants.dart';
import 'package:quickblox_sdk/models/qb_dialog.dart';
import 'package:quickblox_sdk/models/qb_message.dart';
import 'package:quickblox_sdk/quickblox_sdk.dart';
import 'package:quickblox_sdk/webrtc/constants.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:date_format/date_format.dart';

class ChatPage extends StatefulWidget {
  @override
  _ChatPageState createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> with WidgetsBindingObserver {
  late List<ChatPageMessage> _messages = [];

  bool _isLoading = true;

  TextEditingController textEditingController = TextEditingController();
  ScrollController scrollController = ScrollController();

  StreamSubscription? _newMessageSubscription;
  StreamSubscription? _connectedSubscription;
  StreamSubscription? _connectionClosedSubscription;
  StreamSubscription? _reconnectionFailedSubscription;
  StreamSubscription? _reconnectionSuccessSubscription;
  StreamSubscription? _callSubscription;

  String? _dialogId = '';
  String? _sessionId= '';
  String? _username = '';
  int? _userid = 0;
  int? _opponentId = 131778195;

  bool _enableSendBtn = false;

  @override
  void initState() {
    super.initState();
    if (WidgetsBinding.instance != null) {
      WidgetsBinding.instance!.addObserver(this);
    }

    print("==>Call Default Subcriptions");
    setDefaultSubscription();

    _loadInitialized();
    print("==>initState");
  }

  @override
  void dispose() async {
    super.dispose();
    if (WidgetsBinding.instance != null) {
      WidgetsBinding.instance!.removeObserver(this);
    }

    releaseWebRTC();
    setDefaultUnsubscription();
    // await QB.auth.logout();
    print("==>dispose");
  }

  @override
  Future<void> didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.resumed:
        print("==>app in resumed");
        break;
      case AppLifecycleState.inactive:
        print("==>app in inactive");
        break;
      case AppLifecycleState.paused:
        print("==>app in paused");
        break;
      case AppLifecycleState.detached:
        print("==>app in detached");
        break;
    }
  }

  void _loadInitialized() async {
    await _handleCameraAndMic(Permission.camera);
    await _handleCameraAndMic(Permission.microphone);

    var userid = await StorageData.getIntValue('userid');
    var username = await StorageData.getStringValue('username');

    setState(() {
      _userid = userid;
      _username = username;

      print("==>Create Dialog");
      _createDialog();

      print("==>Call WebRTC Initialized");
      initWebRTC();
    });
  }

  Future<void> _handleCameraAndMic(Permission permission) async {
    final status = await permission.request();
    print("==>_handleCameraAndMic"+status.toString());

    
  // Future<void> permission() async {
  //   if (!(await requestPermission(Permission.storage))) {
  //     await permission();
  //   }
  //   if (!(await requestPermission(Permission.microphone))) {
  //     await permission();
  //   }
  //   if (!(await requestPermission(Permission.accessMediaLocation))) {
  //     await permission();
  //   }
  //   if (!(await requestPermission(Permission.camera))) {
  //     await permission();
  //   }
  // }
  }
  
  void _createDialog() async {
    List<int> opponentId = [_opponentId!];
    String dialogName = "CHAT_DIALOG_" + DateTime.now().millisecond.toString();
    try {
      QBDialog? createdDialog = await QB.chat.createDialog(opponentId, dialogName, dialogType: QBChatDialogTypes.CHAT);
      if (createdDialog != null) {
        setState(() {
          _dialogId = createdDialog.id!;
          print("==>The dialog $_dialogId was created with "+createdDialog.occupantsIds.toString());
        });
      }
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
    _getChatHistory();
  }

  void _getChatHistory() async {
    try {
      List<QBMessage?> messages = await QB.chat.getDialogMessages(_dialogId!);
      int countMessages = messages.length;

      if (countMessages > 0) {
        setState(() {
          messages.forEach((item) {
            bool isMe = false;
            if(_userid==item!.senderId) {
              isMe = true;
            }
            int? timeInMillis = item.dateSent;
            var date = DateTime.fromMillisecondsSinceEpoch(timeInMillis!);
            String dateSent = formatDate(date, [hh, ':', nn, ':', ss, ' ', am, '  ', M, ' ', dd, ', ', yyyy]);
            Map<dynamic, dynamic> properties = Map<dynamic, dynamic>.from(item.properties!);
            ChatPageMessage chatPageMessageObj = ChatPageMessage(item.body.toString(), isMe,properties["sender_initial"], properties["sender_name"], dateSent);
            _messages.add(chatPageMessageObj);
          });
        });
      }
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
    _scrollLastEntry();
    setState(() { _isLoading = false; });
  }


  void setDefaultSubscription() async {
    print("==>RECEIVED_NEW_MESSAGE Subscription");
    if (_newMessageSubscription == null) {
      try {
        _newMessageSubscription = await QB.chat.subscribeChatEvent(QBChatEvents.RECEIVED_NEW_MESSAGE, (data) {
          print("==>Subscribed: " + QBChatEvents.RECEIVED_NEW_MESSAGE);
          print("==>RECEIVED_NEW_MESSAGE: "+data.toString());

          Map<dynamic, dynamic> map = Map<dynamic, dynamic>.from(data);
          Map<dynamic, dynamic> payload = Map<dynamic, dynamic>.from(map["payload"]);
          Map<dynamic, dynamic> properties = Map<dynamic, dynamic>.from(payload["properties"]);
          int senderId = payload["senderId"]!;
          
          int? timeInMillis = payload["dateSent"];
          var date = DateTime.fromMillisecondsSinceEpoch(timeInMillis!);
          String dateSent = formatDate(date, [hh, ':', nn, ':', ss, ' ', am, '  ', M, ' ', dd, ', ', yyyy]);
          if(senderId != _userid) {
            setState(() {
              ChatPageMessage chatPageMessageObj = ChatPageMessage(payload["body"], false, properties["sender_initial"], properties["sender_name"], dateSent);
              _messages.add(chatPageMessageObj);
              _scrollLastEntry();

            });
          }
        }, onErrorMethod: (e) {
          print("==>"+e.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>CONNECTED Subscription");
    if (_connectedSubscription == null) {
      try {
        _connectedSubscription = await QB.chat.subscribeChatEvent(QBChatEvents.CONNECTED, (data) {
          print("==>Subscribed: " + QBChatEvents.CONNECTED);
          print("==>CONNECTED: "+data.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>CONNECTION_CLOSED Subscription");
    if (_connectionClosedSubscription == null) {
      try {
        _connectionClosedSubscription = await QB.chat.subscribeChatEvent(QBChatEvents.CONNECTION_CLOSED, (data) {
          print("==>Subscribed: " + QBChatEvents.CONNECTION_CLOSED);
          print("==>CONNECTION_CLOSED: "+data.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>RECONNECTION_FAILED Subscription");
    if (_reconnectionFailedSubscription == null) {
      try {
        _reconnectionFailedSubscription = await QB.chat.subscribeChatEvent(QBChatEvents.RECONNECTION_FAILED, (data) {
          print("==>Subscribed: " + QBChatEvents.RECONNECTION_FAILED);
          print("==>RECONNECTION_FAILED: "+data.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>RECONNECTION_SUCCESSFUL Subscription");
    if (_reconnectionSuccessSubscription == null) {
      try {
        _reconnectionSuccessSubscription = await QB.chat.subscribeChatEvent(QBChatEvents.RECONNECTION_SUCCESSFUL, (data) {
          print("==>Subscribed: " + QBChatEvents.RECONNECTION_SUCCESSFUL);
          print("==>RECONNECTION_SUCCESSFUL: "+data.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>QBRTCEventTypes.CALL Subscription");
    if (_callSubscription == null) {
      try {
        _callSubscription = await QB.webrtc.subscribeRTCEvent(QBRTCEventTypes.CALL, (data) {
          print("==>New Incoming Call Recieved");
          Map<dynamic, dynamic> payloadMap = Map<dynamic, dynamic>.from(data["payload"]);
          Map<dynamic, dynamic> sessionMap = Map<dynamic, dynamic>.from(payloadMap["session"]);

          setState(() {
            _sessionId = sessionMap["id"];
          });

          int initiatorId = sessionMap["initiatorId"];
          int callType = sessionMap["type"];

          onIncomingCall(initiatorId,callType);
        }, onErrorMethod: (error) {
          print(error);
        });
        print("==>Subscribed: " + QBRTCEventTypes.CALL);
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

  }

  void setDefaultUnsubscription() async {
    print("==>RECEIVED_NEW_MESSAGE Unsubscription");
    if (_newMessageSubscription != null) {
      _newMessageSubscription!.cancel();
      _newMessageSubscription = null;
      print("==>Unsubscribed: " + QBChatEvents.RECEIVED_NEW_MESSAGE);
    }

    print("==>CONNECTED Unsubscription");
    if (_connectedSubscription != null) {
      _connectedSubscription!.cancel();
      _connectedSubscription = null;
      print("==>Unsubscribed: " + QBChatEvents.CONNECTED);
    }

    print("==>CONNECTION_CLOSED Unsubscription");
    if (_connectionClosedSubscription != null) {
      _connectionClosedSubscription!.cancel();
      _connectionClosedSubscription = null;
      print("==>Unsubscribed: " + QBChatEvents.CONNECTION_CLOSED);
    }

    print("==>RECONNECTION_FAILED Unsubscription");
    if (_reconnectionFailedSubscription != null) {
      _reconnectionFailedSubscription!.cancel();
      _reconnectionFailedSubscription = null;
      print("==>Unsubscribed: " + QBChatEvents.RECONNECTION_FAILED);
    }

    print("==>RECONNECTION_SUCCESSFUL Unsubscription");
    if (_reconnectionSuccessSubscription != null) {
      _reconnectionSuccessSubscription!.cancel();
      _reconnectionSuccessSubscription = null;
      print("==>Unsubscribed: " + QBChatEvents.RECONNECTION_SUCCESSFUL);
    }
    
    print("==>QBRTCEventTypes.CALL Unsubscription");
    if (_callSubscription != null) {
      _callSubscription!.cancel();
      _callSubscription = null;
      print("==>Unsubscribed: " + QBRTCEventTypes.CALL);
    }
  }

  void _handleSendMessage() async {
    String body = textEditingController.text;
    try {
      Map<String, String> properties = Map();
      properties["sender_name"] = _username!;
      properties["sender_initial"] = _username![0].toUpperCase();

      await QB.chat.sendMessage(_dialogId!, body: body, saveToHistory: true, properties: properties);
      print("==>SENT MESSAGE: $body");
      
      var date = DateTime.now();
      String dateSent = formatDate(date, [hh, ':', nn, ':', ss, ' ', am, '  ', M, ' ', dd, ', ', yyyy]);
      setState(() {
        ChatPageMessage chatPageMessageObj = ChatPageMessage(body, true,_username![0].toUpperCase(),_username!,  dateSent);
        _messages.add(chatPageMessageObj);
        _scrollLastEntry();
      });
      textEditingController.clear();
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }
  
  void _sendIsTyping() async {
    try {
      await QB.chat.sendIsTyping(_dialogId!);
      print("==>Sent is typing for dialog: " + _dialogId!);
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  void _scrollLastEntry() {
    Future.delayed(Duration(milliseconds: 100), () {
      scrollController.animateTo(scrollController.position.maxScrollExtent,
      curve: Curves.ease, duration: Duration(milliseconds: 500));
    });
  }

  Future<void> initWebRTC() async {
    try {
      await QB.webrtc.init();
      print("==>WebRTC was initiated");
      
      await QB.rtcConfig.setAnswerTimeInterval(60);
      await QB.rtcConfig.setDialingTimeInterval(5);
      print("==>WebRTC set interval");
      
      getRTCConfigs();
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  Future<void> getRTCConfigs() async {
    try {
      int? answerInterval = await QB.rtcConfig.getAnswerTimeInterval();
      int? dialingInterval = await QB.rtcConfig.getDialingTimeInterval();
      print("==>RTCConfig was loaded success | Answer Interval: $answerInterval | Dialing Interval: $dialingInterval");
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  Future<void> releaseWebRTC() async {
    try {
      await QB.webrtc.release();
      print("==>WebRTC was released");
      _sessionId = null;
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }
  
  Future<void> onIncomingCall(initiatorId,callType) async {
    print("==>onIncomingCall");
    Navigator.push(context, 
      new MaterialPageRoute(builder: (context) => CallPage(sessionId:_sessionId!, initiatorId:initiatorId, callType:callType, isIncomingCall:true))
    );
  }

  Future<void> _handleCall(types) async {
    print("==>_handleCall");
    Navigator.push(context, 
      new MaterialPageRoute(builder: (context) => CallPage(sessionId:'', initiatorId:_opponentId!, callType:types, isIncomingCall:false))
    );
  }

  @override
  Widget build(BuildContext context) {

    var textInput = Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Color(0xFFf1f1f1),
                borderRadius: BorderRadius.circular(35.0),
                border: Border.all(color: Color(0xFFECEAEA))
              ),
              padding: const EdgeInsets.only(left:15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: textEditingController,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      decoration: InputDecoration(
                        hintText: "Aa",
                        hintStyle: TextStyle( color: Colors.black12),
                        border: InputBorder.none
                      ),
                      onChanged: (text) {
                        setState(() {
                          _enableSendBtn = text.isNotEmpty;
                        });
                        _sendIsTyping();
                      },
                    ),
                  ),
                  RawMaterialButton(
                    constraints: BoxConstraints(),
                    onPressed:(_enableSendBtn)?_handleSendMessage:null,
                    fillColor: (_enableSendBtn)?Colors.blue:Colors.black26,
                    padding: const EdgeInsets.all(5.0),
                    child: Icon(
                      Icons.send,
                      size: 25.0,
                      color: Colors.white,
                    ),
                    shape: CircleBorder(),
                  )
                ],
              ),
            ),
          ),
          SizedBox(width: 5),
          Transform.rotate(
            angle: -3.1416 / 4,
            child: IconButton(
              icon: Icon(
                Icons.attach_file,
                size: 35.0,
                color: Colors.blue,
              ),
              disabledColor: Colors.blue,
              onPressed: null,
            )
          ),
        ],
      ),
    ) ;
  
    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text("Chat Doctor"),
        actions: <Widget>[
          GestureDetector(
            onTap: () {
              _handleCall(QBRTCSessionTypes.VIDEO);
            },
            child: Container(
              padding: const EdgeInsets.only(right:10.0),
              child: Icon(Icons.video_call,
                color:Color(0xFFffffff),
                size: 45.0
              )
            )
          ),
          GestureDetector(
            onTap: () {
              _handleCall(QBRTCSessionTypes.AUDIO);
            },
            child: Container(
              padding: const EdgeInsets.only(right:10.0),
              child: Icon(Icons.call,
                color:Color(0xFFffffff),
                size: 30.0
              )
            )
          )
        ],
      ),
      body: LoadingOverlay(
        isLoading: _isLoading,
        opacity: 0.5,
        progressIndicator: CircularProgressIndicator(),
        child: Column(
          children: <Widget>[
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  var avatar = Padding(
                    padding: const EdgeInsets.only(bottom: 5.0, right: 8.0),
                    child: Container(
                      height: 30,
                      width: 30,
                      child: CircleAvatar(
                        child: Icon(
                          Icons.person,
                          size: 25.0,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  );
                  if (_messages[index].isMessageOfCurrentUser) {
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[ 
                        Padding(
                          padding: EdgeInsets.only(top:15.0, right: 40.0),
                          child: Text(_messages[index].senderName, textAlign: TextAlign.right, style: TextStyle(color: Color(0xFF7f94ea), fontSize: 10.0)),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Bubble(
                                margin: BubbleEdges.only(left: 50),
                                alignment: Alignment.topRight,
                                nipWidth: 5,
                                nipHeight: 5,
                                nip: BubbleNip.rightTop,
                                color:Color(0xFF506de2),
                                child: Padding(
                                  padding: EdgeInsets.all(5.0),
                                  child: Text(_messages[index].chatMessage, textAlign: TextAlign.right, style: TextStyle(color: Colors.white)),
                                ),
                              ),
                            ),
                            avatar,
                          ],
                        ),
                        Padding(
                          padding: EdgeInsets.only(right: 40.0),
                          child: Text(_messages[index].dateSent, textAlign: TextAlign.right, style: TextStyle(color: Color(0xFF7f94ea), fontSize: 10.0)),
                        ),
                      ],
                    );
                  } else {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        avatar,
                        Bubble(
                          margin: BubbleEdges.only(top: 10, bottom: 10),
                          alignment: Alignment.topLeft,
                          nipWidth: 5,
                          nipHeight: 10,
                          nip: BubbleNip.leftBottom,
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(_messages[index].chatMessage),
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
            ),
            Divider(height: 2.0),
            textInput,
          ],
        ),
      ),
    );


  }

}
