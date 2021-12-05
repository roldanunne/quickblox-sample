class ChatPageMessage {
  String chatMessage;
  bool isMessageOfCurrentUser;
  String senderInitial;
  String senderName;
  String dateSent;

  ChatPageMessage(this.chatMessage, this.isMessageOfCurrentUser, this.senderInitial, this.senderName, this.dateSent);

  dynamic get getChatMessage {
    return chatMessage;
  }

  bool get checkMessageOfCurrentUser {
    return isMessageOfCurrentUser;
  }

  dynamic get getSenderInitial {
    return senderInitial;
  }

  dynamic get getSenderName {
    return senderName;
  }

  dynamic get getDateSent {
    return dateSent;
  }
}