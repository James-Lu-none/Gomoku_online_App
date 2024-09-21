import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:gomoku_online_app/room_page.dart';
import "dart:async";



class RootData {
  List<dynamic> roomId;
  dynamic rooms;

  RootData(this.roomId, this.rooms);

  factory RootData.fromJson(dynamic json) {
    return RootData(json['roomId'] as List<dynamic>, json['rooms'] as dynamic);
  }

  @override
  String toString() {
    return '{${this.roomId},${this.rooms}';
  }
}

class Room {
  dynamic id;
  dynamic nPlayer;

  Room(this.id, this.nPlayer);
}

class LobbyPage extends StatefulWidget {
  const LobbyPage({super.key});

  @override
  State<StatefulWidget> createState() => _LobbyPage();
}

class _LobbyPage extends State<LobbyPage> {
  FirebaseDatabase database = FirebaseDatabase.instance;

  DatabaseReference debugRef = FirebaseDatabase.instance.ref("debug");
  DatabaseReference roomsRef = FirebaseDatabase.instance.ref("rooms");
  DatabaseReference roomIdRef = FirebaseDatabase.instance.ref("roomId");
  final double buttonWidth = 150;
  List<Room> rooms = [];

  TextEditingController codeInputController = TextEditingController();

  @override
  void dispose() {
    codeInputController.dispose();
    super.dispose();
  }

  Future<void> getNplayer() async {
    if (rooms.isNotEmpty) {
      for (int i = 0; i < rooms.length; i++) {
        final snapshot = await roomsRef.child('${rooms[i].id}/nPlayer').get();
        setState(() {
          if (snapshot.exists) {
            rooms[i].nPlayer = snapshot.value.toString();
          }
        });
      }
    }
  }

  Future<void> initRoomChecking() async {
    final snapshot = await roomIdRef.get();
    setState(() {
      if (snapshot.exists) {
        print("ids: ${snapshot.value}");
        final idList =
            List<String>.from(jsonDecode(jsonEncode(snapshot.value)));
        for (int i = 0; i < idList.length; i++) {
          rooms = idList.map((id) => Room(id, 0)).toList();
        }
        getNplayer();
      }
    });
  }

  void updateListening() {
    setState(() {
      bool check=false;
      debugRef.onValue.listen((DatabaseEvent event)
      {
        if(event.snapshot.exists || event.snapshot.value == null){
          print("lobby check");
          initRoomChecking();
        }
      });
      roomIdRef.onValue.listen((DatabaseEvent event)
      {
        if(event.snapshot.exists || event.snapshot.value == null){
          print("lobby check");
          initRoomChecking();
        }

      });
      roomsRef.onValue.listen((DatabaseEvent event) {
        if(event.snapshot.exists || event.snapshot.value == null){
          print("nPlayer check");
          getNplayer();
        }
      }
      );
    });
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();

    initRoomChecking();
    updateListening();
  }

  @override
  Widget build(BuildContext context) {
    const title = '5 in a row';

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: title,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          iconTheme: IconThemeData(color: Colors.black),
          color: Color.fromRGBO(98, 0, 238, 1), //<-- SEE HERE
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text(title),
        ),
        body: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Column(
              children: [
                Container(
                  padding: EdgeInsets.only(top: 50),
                  height: 150,
                  child: const Text(
                    "Lobby",
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 30),
                  ),
                ),
                SizedBox(
                    height: 50,
                    width: MediaQuery.of(context).size.width/1.5,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.black,
                        // padding: const EdgeInsets.all(16.0),
                        textStyle: const TextStyle(fontSize: 28),
                      ),
                      onPressed: () {
                        setState(() {
                          final String code = getRandomString(8);
                          rooms.add(Room(code, 1));
                          database.ref().update({
                            "roomId": rooms.map((room) => room.id).toList()
                          });
                          roomsRef.child(code).set({
                            'nPlayer': 1,
                          });
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    RoomPage(isOwner: true, roomCode: code)),
                          );
                        });
                      },
                      child: const Text("create room"),
                    )),
                const SizedBox(
                  height: 30,
                ),
                SizedBox(
                  width: MediaQuery.of(context).size.width/1.2,
                  height: 300,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: rooms.length,
                    itemBuilder: (BuildContext context, int index) {
                      return SizedBox(
                        height: 30,
                        child: Center(
                          child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                SizedBox(
                                  width: MediaQuery.of(context).size.width/1.2-50,
                                  child: Row(children: [
                                    Expanded(
                                      child: Text('Room: ${rooms[index].id}'),
                                    ),
                                    Expanded(
                                      child: Text(
                                          'player(s): ${rooms[index].nPlayer}'),
                                    ),
                                  ]),
                                ),
                                Container(
                                  width: 20,
                                  height: 20,
                                  color: Colors.transparent,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (rooms[index].nPlayer == '2') {
                                        showDialog(
                                          context: context,
                                          builder: (context) {
                                            return const AlertDialog(
                                              content:
                                                  Text("This room is full"),
                                            );
                                          },
                                        );
                                      } else {
                                        roomsRef.child(rooms[index].id).set({
                                          'nPlayer': 2,
                                        });
                                        Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                                builder: (context) => RoomPage(
                                                    isOwner: false,
                                                    roomCode:
                                                        rooms[index].id)));
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      padding: EdgeInsets.zero,
                                      shape: const RoundedRectangleBorder(
                                        side: BorderSide.none,
                                      ),
                                    ),
                                    child: const Icon(
                                          Icons.door_back_door_outlined,
                                          color: Colors.black,),

                                  ),
                                ),
                              ]),
                        ),
                      );
                    },
                    separatorBuilder: (BuildContext context, int index) =>
                        const Divider(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
