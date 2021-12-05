import 'dart:async';
import 'package:chatappmedref/storage_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quickblox_sdk/models/qb_rtc_session.dart';
import 'package:quickblox_sdk/quickblox_sdk.dart';
import 'package:quickblox_sdk/webrtc/constants.dart';
import 'package:quickblox_sdk/webrtc/rtc_video_view.dart';
import 'package:simple_animations/stateless_animation/custom_animation.dart';
import 'package:simple_animations/stateless_animation/loop_animation.dart';

class CallPage extends StatefulWidget {
  final String sessionId;
  final int initiatorId;
  final int callType;
  final bool isIncomingCall;
  const CallPage({Key? key, required this.sessionId, required this.initiatorId, required this.callType, required this.isIncomingCall}) : super(key: key);

  @override
  _CallPageState createState() => _CallPageState();
}

class _CallPageState extends State<CallPage> {
  
  StreamSubscription? _callSubscription;
  StreamSubscription? _callEndSubscription;
  StreamSubscription? _rejectSubscription;
  StreamSubscription? _acceptSubscription;
  StreamSubscription? _hangUpSubscription;
  StreamSubscription? _videoTrackSubscription;
  StreamSubscription? _notAnswerSubscription;
  StreamSubscription? _peerConnectionSubscription;

  RTCVideoViewController? _localVideoViewController;
  RTCVideoViewController? _remoteVideoViewController;

  String? _sessionId;
  bool _muteCall = false;
  bool _videoState = false;
  bool _callState = false;
  bool _isCallConnected = false;
  int _endState = 0;

  List<int> opponent_ids = [];

  String? _username = '';
  String? _password = '';
  int? _userid = 0;

  late AudioPlayer player1;
  late AudioPlayer player2;

  CustomAnimationControl controlAnimate = CustomAnimationControl.mirror; 
      
  @override
  void initState() {
    super.initState(); 
    player1 = AudioPlayer();
    player2 = AudioPlayer();
    _loadInitialized();
  }

  @override
  void dispose() { 
    super.dispose();
    player1.dispose();
    player2.dispose();
    releaseVideoViews();
    setDefaultUnsubscription();
  }

  void _loadInitialized() async {
    print("==>Reload chat page.");
    var userid = await StorageData.getIntValue('userid');
    var username = await StorageData.getStringValue('username');
    var password = await StorageData.getStringValue('password');
    
    await setDefaultSubscription();
    setState(() {
      _userid = userid;
      _username = username;
      _password = password;

      print("==>Set opponent ids");
      opponent_ids = [_userid!,widget.initiatorId];

      if(widget.isIncomingCall){
        _sessionId = widget.sessionId;
        print("==>IncomingCall");
        player1.setAsset('assets/audios/ringtone.mp3');
      } else {
        callWebRTC();
        print("==>NotIncomingCall");        
        player1.setAsset('assets/audios/calling.mp3');
      } 
      player1.setLoopMode(LoopMode.one); 
      player1.play();
      print("==>player1.play");
    });
  }
 
  String parseState(int state) {
    String parsedState = "";
    switch (state) {
      case QBRTCPeerConnectionStates.NEW:
        parsedState = "NEW";
        break;
      case QBRTCPeerConnectionStates.FAILED:
        parsedState = "FAILED";
        break;
      case QBRTCPeerConnectionStates.DISCONNECTED:
        parsedState = "DISCONNECTED";
        break;
      case QBRTCPeerConnectionStates.CLOSED:
        parsedState = "CLOSED";
        break;
      case QBRTCPeerConnectionStates.CONNECTED:
        parsedState = "CONNECTED";
        break;
    }
    return parsedState;
  }

  Future<void> setDefaultSubscription() async {
    print("==>CALL_END Subscription");
    if (_callEndSubscription == null) {
      try {
        _callEndSubscription = await QB.webrtc.subscribeRTCEvent(QBRTCEventTypes.CALL_END, (data) {
          print("==>Subscribed: " + QBRTCEventTypes.CALL_END);
          print("==>CALL_END: "+data.toString());
          Map<dynamic, dynamic> payload = Map<dynamic, dynamic>.from(data["payload"]);
          Map<dynamic, dynamic> session = Map<dynamic, dynamic>.from(payload["session"]);
          setState(() {
            _sessionId = session["id"];
          });
          print("==>The call with sessionId $_sessionId was ended");
          closeCallPage();
        }, onErrorMethod: (e) {
          print("==>"+e.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>NOT_ANSWER Subscription");
    if (_notAnswerSubscription == null) {
      try {
        _notAnswerSubscription =await QB.webrtc.subscribeRTCEvent(QBRTCEventTypes.NOT_ANSWER, (data) {
          print("==>Subscribed: " + QBRTCEventTypes.NOT_ANSWER);
          print("==>NOT_ANSWER: "+data.toString());
          int userId = data["payload"]["userId"];
          print("==>The user $userId did not answer");
          if(!_isCallConnected){
            closeCallPage();
          }
        }, onErrorMethod: (e) {
          print("==>"+e.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>REJECT Subscription");
    if (_rejectSubscription == null) {
      try {
        _rejectSubscription = await QB.webrtc.subscribeRTCEvent(QBRTCEventTypes.REJECT, (data) {
          print("==>Subscribed: " + QBRTCEventTypes.REJECT);
          print("==>REJECT: "+data.toString());
          int userId = data["payload"]["userId"];
          print("==>The user $userId was rejected your call");
          closeCallPage();
        }, onErrorMethod: (e) {
          print("==>"+e.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>ACCEPT Subscription");
    if (_acceptSubscription == null) {
      try {
        _acceptSubscription = await QB.webrtc.subscribeRTCEvent(QBRTCEventTypes.ACCEPT, (data) {
          print("==>Subscribed: " + QBRTCEventTypes.ACCEPT);
          print("==>ACCEPT: "+data.toString());
          int userId = data["payload"]["userId"];
          print("==>The user $userId was accepted your call");
        }, onErrorMethod: (e) {
          print("==>"+e.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>HANG_UP Subscription");
    if (_hangUpSubscription == null) {
      try {
        _hangUpSubscription = await QB.webrtc.subscribeRTCEvent(QBRTCEventTypes.HANG_UP, (data) {
          print("==>Subscribed: " + QBRTCEventTypes.HANG_UP);
          print("==>HANG_UP: "+data.toString());
          int userId = data["payload"]["userId"];
          print("==>The user $userId is hang up!");
          closeCallPage();
        }, onErrorMethod: (e) {
          print("==>"+e.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>PEER_CONNECTION_STATE_CHANGED Subscription");
    if (_peerConnectionSubscription == null) {
      try {
      _peerConnectionSubscription = await QB.webrtc.subscribeRTCEvent(QBRTCEventTypes.PEER_CONNECTION_STATE_CHANGED, (data) {
          print("==>Subscribed: " + QBRTCEventTypes.PEER_CONNECTION_STATE_CHANGED);
          print("==>PEER_CONNECTION_STATE_CHANGED: "+data.toString());
          
          int state = data["payload"]["state"];
          String parsedState = parseState(state);
          print("==>PeerConnection state: $parsedState");

          if(parsedState=='DISCONNECTED' || parsedState=='CLOSED'){
            closeCallPage();
          }
          
          if(parsedState=='CONNECTED'){
            player1.stop();
            print("==>player1.stop");
            
            setState(() {
              _isCallConnected = true;
            });

          }
        }, onErrorMethod: (e) {
          print("==>"+e.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

    print("==>RECEIVED_VIDEO_TRACK Subscription");
    if (_videoTrackSubscription == null) {
      try {
        _videoTrackSubscription = await QB.webrtc.subscribeRTCEvent(QBRTCEventTypes.RECEIVED_VIDEO_TRACK, (data) {
          print("==>Subscribed: " + QBRTCEventTypes.RECEIVED_VIDEO_TRACK);
          print("==>RECEIVED_VIDEO_TRACK: "+data.toString());
          int opponentId = data["payload"]["userId"];
          
          if (opponentId == _userid) {
            startRenderingLocal();
          } else {
            startRenderingRemote(opponentId);
          }
          
          print("==>The user $opponentId was start rendering call");
        }, onErrorMethod: (e) {
          print("==>"+e.toString());
        });
      } on PlatformException catch (e) {
        print("==>"+e.toString());
      }
    }

  }

  Future<void> setDefaultUnsubscription() async {
    print("==>CALL_END Unsubscription");
    if (_callEndSubscription != null) {
      _callEndSubscription!.cancel();
      _callEndSubscription = null;
      print("==>Unsubscribed: " + QBRTCEventTypes.CALL_END);
    }

    print("==>REJECT Unsubscription");
    if (_rejectSubscription != null) {
      _rejectSubscription!.cancel();
      _rejectSubscription = null;
      print("==>Unsubscribed: " + QBRTCEventTypes.REJECT);
    }

    print("==>ACCEPT Unsubscription");
    if (_acceptSubscription != null) {
      _acceptSubscription!.cancel();
      _acceptSubscription = null;
      print("==>Unsubscribed: " + QBRTCEventTypes.ACCEPT);
    }

    print("==>HANG_UP Unsubscription");
    if (_hangUpSubscription != null) {
      _hangUpSubscription!.cancel();
      _hangUpSubscription = null;
      print("==>Unsubscribed: " + QBRTCEventTypes.HANG_UP);
    }

    print("==>RECEIVED_VIDEO_TRACK Unsubscription");
    if (_videoTrackSubscription != null) {
      _videoTrackSubscription!.cancel();
      _videoTrackSubscription = null;
      print("==>Unsubscribed: " + QBRTCEventTypes.RECEIVED_VIDEO_TRACK);
    }
    
    print("==>QBRTCEventTypes.NOT_ANSWER Unsubscription");
    if (_notAnswerSubscription != null) {
      _notAnswerSubscription!.cancel();
      _notAnswerSubscription = null;
      print("==>Unsubscribed: " + QBRTCEventTypes.NOT_ANSWER);
    }
    
    print("==>QBRTCEventTypes.PEER_CONNECTION_STATE_CHANGED Unsubscription");
    if (_peerConnectionSubscription != null) {
      _peerConnectionSubscription!.cancel();
      _peerConnectionSubscription = null;
      print("==>Unsubscribed: " + QBRTCEventTypes.PEER_CONNECTION_STATE_CHANGED);
    }

  }


  Future<void> getSessionWebRTC() async {
    try {
      QBRTCSession? session = await QB.webrtc.getSession(_sessionId!);
      _sessionId = session!.id;
      print("==>The session : "+session.toString());
      print("==>The session with id $_sessionId was loaded");
    } on PlatformException catch (e) {
        print("==>"+e.toString());
    }
  }
  
  Future<void> startRenderingLocal() async {
    try {
      await _localVideoViewController!.play(_sessionId!, _userid!);
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  Future<void> startRenderingRemote(int opponentId) async {
    try {
      await _remoteVideoViewController!.play(_sessionId!, opponentId);
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  Future<void> callWebRTC() async {
    try {
      QBRTCSession? session = await QB.webrtc.call(opponent_ids, widget.callType);
      _sessionId = session!.id;
      print("==>The call was initiated for session id: $_sessionId");
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }
  
  Future<void> acceptWebRTC() async {
    try {
      QBRTCSession? session = await QB.webrtc.accept(widget.sessionId);
      String? receivedSessionId = session!.id;
      print("==>Session with id: $receivedSessionId was accepted");
    } on PlatformException catch (e) {
      print("==>Session accepted "+e.toString());
    }
  }

  Future<void> rejectWebRTC() async {
    try {
      QBRTCSession? session = await QB.webrtc.reject(widget.sessionId);
      String? id = session!.id;
      print("==>Session with id: $id was rejected");
      closeCallPage();
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  Future<void> hangUpWebRTC() async {
    try {
      QBRTCSession? session = await QB.webrtc.hangUp(_sessionId!);
      String? id = session!.id;
      print("==>Session with id: $id was hang up");
      closeCallPage();
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }
  

  Future<void> enableVideo() async {
    try {
      setState(() {
        _videoState = !_videoState;
      });
      await QB.webrtc.enableVideo(_sessionId!, enable: _videoState, userId: _userid!.toDouble());
      print("==>The video was enable $_videoState");
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
    
  }

  Future<void> enableAudio() async {
    try {
      setState(() {
        _muteCall = !_muteCall;
      });
      await QB.webrtc.enableAudio(_sessionId!, enable: _muteCall);
      print("==>The audio was enable $_muteCall");
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  Future<void> switchCamera() async {
    try {
      await QB.webrtc.switchCamera(_sessionId!);
      print("==>Camera was switched");
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  Future<void> mirrorCamera() async {
    try {
      await QB.webrtc.mirrorCamera(_userid!, true);
      print("==>Camera was mirrored");
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  Future<void> switchAudioOutput(int output) async {
    try {
      await QB.webrtc.switchAudioOutput(output);
      print("==>Audio was switched");
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  Future<void> releaseVideoViews() async {
    try {
      await _localVideoViewController!.release();
      await _remoteVideoViewController!.release();
      print("==>Video Views were released");
    } on PlatformException catch (e) {
      print("==>"+e.toString());
    }
  }

  void closeCallPage() async {
    player1.stop();
    setState(() {
      _endState++;
    });
    
    
    if(_endState==1) {

      // await player2.setAsset('assets/audios/end_of_call.mp3');
      // await player2.play();
      Navigator.pop(context);
    }
  }

  
  Widget _floatingBar() {
    return Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: <Widget>[
          if(!_callState && widget.isIncomingCall)
           LoopAnimation<double>(
            tween: Tween(begin: 0.9, end: 1.0),
            duration: const Duration(seconds: 2),
            curve: Curves.easeOut,
            builder: (context, child, value) {
              return Transform.scale(
                scale: value,
                child: child,
              );
            },
            child: RawMaterialButton(
              onPressed: () { 
                acceptWebRTC();
                setState(() {
                  print("==>widget.sessionId: " + widget.sessionId);
                  _callState = true;
                });
              },
              child: Icon(Icons.call,
                color: Colors.white,
                size: 45.0,
              ),
              shape: CircleBorder(
                side: BorderSide(
                  color: Colors.black38,
                  width: 5,
                  style: BorderStyle.solid
                ),
              ),
              fillColor:Colors.blueAccent,
              padding: const EdgeInsets.all(15.0),
            ),
          ),
          // RawMaterialButton(
          //   onPressed: () { 
          //     acceptWebRTC();
          //     setState(() {
          //       print("==>widget.sessionId: " + widget.sessionId);
          //       _callState = true;
          //     });
          //   },
          //   child: Icon(Icons.call,
          //     color: Colors.white,
          //     size: 45.0,
          //   ),
          //   shape: CircleBorder(
          //     side: BorderSide(
          //       color: Colors.black38,
          //       width: 5,
          //       style: BorderStyle.solid
          //     ),
          //   ),
          //   fillColor:Colors.blueAccent,
          //   padding: const EdgeInsets.all(15.0),
          // ),
          if(!_callState && widget.isIncomingCall)
            SizedBox(width: 10.0),
          if(!_callState && widget.isIncomingCall)
          RawMaterialButton(
            onPressed: () => rejectWebRTC(),
            child: Icon(Icons.call_end,
              color: Colors.white,
              size: 45.0,
            ),
            shape: CircleBorder(
              side: BorderSide(
                color: Colors.black38,
                width: 5,
                style: BorderStyle.solid
              ),
            ),
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
          ),
          if(_callState || !widget.isIncomingCall)
          RawMaterialButton(
            onPressed: () => enableAudio(),
            child: Icon(
              _muteCall? Icons.mic : Icons.mic_off,
              color: _muteCall? Colors.blueAccent : Colors.white,
              size: 30.0,
            ),
            shape: CircleBorder(
              side: BorderSide(
                color: Colors.black38,
                width: 3,
                style: BorderStyle.solid
              ),
            ),
            fillColor: _muteCall ? Colors.white : Colors.blueAccent,
            padding: const EdgeInsets.all(12.0),
          ),
          if(_callState || !widget.isIncomingCall)
          RawMaterialButton(
            onPressed: () => hangUpWebRTC(),
            child: Icon(Icons.call_end,
              color: Colors.white,
              size: 45.0,
            ),
            shape: CircleBorder(
              side: BorderSide(
                color: Colors.black38,
                width: 5,
                style: BorderStyle.solid
              ),
            ),
            fillColor: Colors.redAccent,
            padding: const EdgeInsets.all(15.0),
          ),
          if(_callState || !widget.isIncomingCall)
          RawMaterialButton(
            onPressed: () => enableVideo(),
            child: Icon(
              _videoState? Icons.videocam : Icons.videocam_off_outlined ,
              color: _videoState? Colors.blueAccent : Colors.white,
              size: 30.0,
            ),
            shape: CircleBorder(
              side: BorderSide(
                color: Colors.black38,
                width: 3,
                style: BorderStyle.solid
              ),
            ),
            fillColor: _videoState ? Colors.white : Colors.blueAccent,
            padding: const EdgeInsets.all(12.0),
          )
        ],
      );
  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Video Calling'),
      ),
      backgroundColor: Colors.black,
      body: OrientationBuilder(builder: (context, orientation) {
        return Container(
          child: Stack(
            children: <Widget> [
              Positioned(
                left: 0.0,
                right: 0.0,
                top: 0.0,
                bottom: 0.0,
                child: Container(
                  margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: RTCVideoView(onVideoViewCreated: _onRemoteVideoViewCreated),
                  decoration: BoxDecoration(color: Colors.black54),
                )
              ),
              Positioned(
                right: 20.0,
                top: 20.0,
                child: Container( 
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container( 
                        width: orientation == Orientation.portrait ? 100.0 : 135.0,
                        height: orientation == Orientation.portrait ? 135.0 : 100.0,
                        child: RTCVideoView(onVideoViewCreated: _onLocalVideoViewCreated),
                        decoration: BoxDecoration(color: Colors.red),
                      ),
                    ),
                  ),
              ),
              if (!_isCallConnected)
              Positioned(
                right: 20.0,
                top: 20.0,
                child: Container( 
                  padding: EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(10)
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Container( 
                        width: orientation == Orientation.portrait ? 100.0 : 135.0,
                        height: orientation == Orientation.portrait ? 135.0 : 100.0,
                        child: Container(
                            margin: EdgeInsets.fromLTRB(0.0, 0.0, 0.0, 0.0),
                            height: MediaQuery.of(context).size.height,
                              decoration: BoxDecoration(
                                image: DecorationImage(
                                  image: AssetImage("assets/0.jpg"),
                                  fit: BoxFit.cover,
                                ),
                              ),
                          ),
                        decoration: BoxDecoration(color: Colors.black54),
                      ),
                    ),
                  ),
              ),
            ]
          ),
        );
      }),      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: _floatingBar()
    );
  }

  void _onLocalVideoViewCreated(RTCVideoViewController controller) {
    _localVideoViewController = controller;
  }

  void _onRemoteVideoViewCreated(RTCVideoViewController controller) {
    _remoteVideoViewController = controller;
  }


}
