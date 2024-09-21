import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:gomoku_online_app/menu_page.dart';

import 'lobby_page.dart';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

class Board {
  List<Player> boardCheckState = List<Player>.filled(225, Player.blank);
  int winner = 0;
}

enum Player { O, X, blank }

class Game {
  bool p1Exist;
  bool p2Exist;
  String firstPlayer;
  String turn;
  List<int> moves;

  Game(this.p1Exist, this.p2Exist, this.firstPlayer, this.turn, this.moves);

  factory Game.fromJson(dynamic json) {
    if (json['moves'] != null) {
      return Game(
          json['p1Exist'] as bool,
          json['p2Exist'] as bool,
          json['firstPlayer'] as String,
          json['turn'] as String,
          List<int>.from(json['moves']));
    } else {
      return Game(json['p1Exist'] as bool, json['p2Exist'] as bool,
          json['firstPlayer'] as String, json['turn'] as String, []);
    }
  }

  @override
  String toString() {
    return '{${this.p1Exist},${this.p2Exist},${this.firstPlayer},${this.turn},${this.moves}';
  }
}

class RoomPage extends StatefulWidget {
  final bool isOwner;
  final String roomCode;

  const RoomPage({super.key, required this.isOwner, required this.roomCode});

  @override
  State<StatefulWidget> createState() => _RoomPage();
}

class _RoomPage extends State<RoomPage> {
  DatabaseReference rootRef = FirebaseDatabase.instance.ref();
  DatabaseReference mainRef = FirebaseDatabase.instance.ref();
  DatabaseReference gameRecordRef = FirebaseDatabase.instance.ref('gameRecord');
  DatabaseReference debugRef = FirebaseDatabase.instance.ref("debug");
  DatabaseReference roomsRef = FirebaseDatabase.instance.ref("rooms");
  DatabaseReference roomIdRef = FirebaseDatabase.instance.ref("roomId");
  Player role = Player.O;
  String code = '';
  Board board = Board();
  List<Board> savedGame = [];
  List<int> moves = [];
  int stepCounter = 0;
  bool isOwner = false;
  Game game = Game(false, false, '', '', []);

  Future<void> updateState() async {
    final snapshot = await mainRef.get();
    setState(() {
      if (snapshot.exists) {
        print("game update now");
        final data = Game.fromJson(jsonDecode(jsonEncode(snapshot.value)));
        game = data;
        if (data.p1Exist == false && data.p2Exist == true) {
          //switch Owner
          print("switching to Owner");
          mainRef.update({
            'p1Exist': true,
            'p2Exist': false,
            'firstPlayer': 'p1',
            'turn': 'O'
          });
          role = Player.O;
          isOwner = true;
        }
        if (!game.p2Exist) {
          //get back first role
          print("getting back role O");
          mainRef.update({
            'p1Exist': true,
            'p2Exist': false,
            'firstPlayer': 'p1',
            'turn': 'O'
          });
          role = Player.O;
          isOwner = true;
        }

        if (isOwner) {
          print("getting role");
          if (game.firstPlayer == "p1") {
            role = Player.O;
          } else {
            role = Player.X;
          }
        } else {
          if (game.firstPlayer == "p1") {
            role = Player.X;
          } else {
            role = Player.O;
          }
        }

        if (game.moves.isNotEmpty) {
          final lastMovePosition = game.moves.last;
          board.boardCheckState[lastMovePosition] =
              (game.turn == 'O') ? Player.X : Player.O;
          if (checkFiveInARow(
              board.boardCheckState,
              (game.turn == 'O') ? Player.X : Player.O,
              lastMovePosition ~/ 15,
              lastMovePosition % 15)) {
            //upload
            if (isOwner) {
              final newGameRecordRef = gameRecordRef.push();
              newGameRecordRef.set({'moves': game.moves});
            }

            showDialog(
              context: context,
              builder: (context) {
                return const AlertDialog(
                  content: Text("Game Over"),
                );
              },
            );
            mainRef.update({
              'firstPlayer': (game.firstPlayer == 'p1') ? 'p2' : 'p1',
              'moves': [],
              'turn': 'O'
            });
            board = Board();
            game = Game(false, false, '', '', []);
          }
        } else {
          board = Board();
        }
      }
    });
  }

  void updateListening() {
    setState(() {
      mainRef.onValue.listen((DatabaseEvent event) {
        if (event.snapshot.exists) {
          print("Game check");
          updateState();
        }
      });
    });
  }

  @override
  void initState() {
    super.initState();
    code = widget.roomCode;
    isOwner = widget.isOwner;
    mainRef = FirebaseDatabase.instance.ref(widget.roomCode);
    if (isOwner) {
      mainRef.set({
        'p1Exist': true,
        'p2Exist': false,
        'firstPlayer': 'p1',
        'turn': 'O',
        'moves': [],
      });
      role = Player.O;
    } else {
      mainRef.update({
        'p2Exist': true,
      });
      role = Player.X;
    }
    updateState();
    updateListening();

  }

  Object? getState(int index) {
    final state = board.boardCheckState[index];
    if (state == Player.blank) return null;
    if (state == Player.O) {
      return Icons.circle_outlined;
    } else {
      return Icons.close;
    }
  }

  Future<void> exit() async {
    print("exit now");
    if (!game.p2Exist) {
      final snapshot = await roomIdRef.get();
      List<String> idList = [];
      if (snapshot.exists) {
        idList = List<String>.from(jsonDecode(jsonEncode(snapshot.value)));
      }
      idList.remove(code);

      await rootRef.update({'roomId': idList});
      await mainRef.remove();
      await roomsRef.child(code).remove();
    } else {
      await mainRef.update(
          {"p2Exist": false, "turn": 'O', "firstPlayer": 'p1', "moves": []});
      await roomsRef.child(code).update({
        'nPlayer': 1,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const title = '5 in a row';
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        appBarTheme: AppBarTheme(
          iconTheme: IconThemeData(color: Colors.black),
          color: Color.fromRGBO(98, 0, 238, 1), //<-- SEE HERE
        ),
      ),
      title: title,
      home: Scaffold(
          appBar: AppBar(
            title: const Text(title),
          ),
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                      padding: EdgeInsets.only(bottom: 15),
                      width: 15,
                      height: 33,
                      color: Colors.transparent,
                      child: ElevatedButton(
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: code));
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          padding: EdgeInsets.zero,
                        ),
                        child: Ink(
                          child: const Icon(Icons.copy,
                              color: Colors.black, size: 20),
                        ),
                      )),
                  Container(
                      padding: EdgeInsets.only(left: 10),
                      width: getMinValue(
                          (MediaQuery.of(context).size.width - 30), 400),
                      height: 30,
                      child: Text(
                        "Room Code: ${code}",
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 16),
                      )
                  ),
                ],
              ),
              SizedBox(
                  width: getMinValue(
                      (MediaQuery.of(context).size.width - 30), 400),
                  height: 30,
                  child: Text(
                    "opponent: ${getOpponentState()}",
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  )
              ),
              SizedBox(
                width: getMinValue(MediaQuery.of(context).size.width - 30, 420),
                height: 40,

                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: getMinValue(
                            (MediaQuery.of(context).size.width - 30) / 2, 200),
                        height: 30,
                        child: Text(
                          "Your role: ${(role == Player.O) ? 'O' : 'X'}",
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16),
                        ),
                      ),
                      SizedBox(
                          width: getMinValue(
                              (MediaQuery.of(context).size.width - 30) / 2,
                              200),
                          height: 30,
                          child: Text(
                            "Now playing: ${(game.turn == 'O') ? 'O' : 'X'}",
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 16),
                          )),
                    ],
                  ),

              ),
              const SizedBox(
                height: 3,
              ),
              SizedBox(
                height:
                    getMinValue((MediaQuery.of(context).size.width - 30), 450),
                width:
                    getMinValue((MediaQuery.of(context).size.width - 30), 450),
                child: GridView.count(
                  crossAxisCount: 15,
                  children: List.generate(225, (index) {
                    return Center(
                        child: SizedBox(
                            height: getMinValue(
                                (MediaQuery.of(context).size.width - 30) / 15,
                                30),
                            width: getMinValue(
                                (MediaQuery.of(context).size.width - 30) / 15,
                                30),
                            child: Container(
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: highlightLastMoveColor(index),
                                    width: highlightLastMoveWidth(index),
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        padding: EdgeInsets.zero),
                                    onPressed: () async {
                                      bool isValidMove = false;
                                      setState(() {
                                        if (!game.p2Exist || !game.p2Exist) {
                                          showDialog(
                                            context: context,
                                            builder: (context) {
                                              return const AlertDialog(
                                                content: Text(
                                                    "Waiting player to join"),
                                              );
                                            },
                                          );
                                          return;
                                        }
                                        if (board.boardCheckState[index] ==
                                                Player.blank &&
                                            role ==
                                                ((game.turn == 'O')
                                                    ? Player.O
                                                    : Player.X)) {
                                          isValidMove = true;
                                          board.boardCheckState[index] =
                                              (game.turn == 'O')
                                                  ? Player.O
                                                  : Player.X;
                                          game.moves.add(index);
                                        }
                                      });
                                      if (isValidMove) {
                                        await mainRef.update({
                                          "moves": game.moves,
                                          "turn":
                                              (role == Player.O) ? 'X' : 'O',
                                        });
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(1),
                                      child: Icon(
                                        getState(index) as IconData?,
                                        color: Colors.black,
                                      ),
                                    )))));
                  }),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      height: 40,
                      width: 80,
                      child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            color: Colors.grey,
                          ),
                          child: TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.black,
                              // padding: const EdgeInsets.all(16.0),
                              textStyle: const TextStyle(fontSize: 16),
                            ),
                            onPressed: () async {
                              exit();
                              setState(() {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const LobbyPage()));
                              });
                            },
                            child: const Text("exit"),
                          ))),
                ],
              ),
            ],
          )),
    );
  }

  bool checkFiveInARow(
      List<Player> flatBoard, Player player, int row, int col) {
    List<List<Player>> board = [];
    List<Player> colBoard = [];
    int boardSize = 15;
    for (int i = 0; i < boardSize; i++) {
      for (int j = 0; j < boardSize; j++) {
        colBoard.add(flatBoard[i * 15 + j]);
      }
      board.add(colBoard);
      colBoard = [];
    }
    // Check rows
    for (int c = 0; c < (boardSize - 4); c++) {
      if (board[row][c] == player &&
          board[row][c + 1] == player &&
          board[row][c + 2] == player &&
          board[row][c + 3] == player &&
          board[row][c + 4] == player) {
        return true;
      }
    }

    // Check columns
    for (int r = 0; r < boardSize - 4; r++) {
      if (board[r][col] == player &&
          board[r + 1][col] == player &&
          board[r + 2][col] == player &&
          board[r + 3][col] == player &&
          board[r + 4][col] == player) {
        return true;
      }
    }

    // Check diagonals
    for (int i = 0; i < boardSize - 4; i++) {
      if (row - i >= 0 &&
          col - i >= 0 &&
          row - i + 4 < boardSize &&
          col - i + 4 < boardSize) {
        if (board[row - i][col - i] == player &&
            board[row - i + 1][col - i + 1] == player &&
            board[row - i + 2][col - i + 2] == player &&
            board[row - i + 3][col - i + 3] == player &&
            board[row - i + 4][col - i + 4] == player) {
          return true;
        }
      }
    }

    // Check anti-diagonals
    for (int i = 0; i < boardSize - 4; i++) {
      if (row + i < boardSize &&
          col - i >= 0 &&
          row + i - 4 >= 0 &&
          col - i + 4 < boardSize) {
        if (board[row + i][col - i] == player &&
            board[row + i - 1][col - i + 1] == player &&
            board[row + i - 2][col - i + 2] == player &&
            board[row + i - 3][col - i + 3] == player &&
            board[row + i - 4][col - i + 4] == player) {
          return true;
        }
      }
    }

    return false;
  }

  double getMinValue(double d, double i) {
    if (d > i) {
      return i;
    } else {
      return d;
    }
  }

  String getOpponentState() {
    bool isOpponentExist;
    if (isOwner) {
      isOpponentExist = game.p2Exist;
    } else {
      isOpponentExist = game.p1Exist;
    }
    if (!isOpponentExist) return 'Not Exist';
    return 'Exist';
  }

  Color highlightLastMoveColor(int index) {
    if (game.moves.isEmpty) return Colors.black;
    if (index == game.moves.last) return Colors.lightBlue;
    return Colors.black;
  }

  double highlightLastMoveWidth(int index) {
    if (game.moves.isEmpty) return 0.5;
    if (index == game.moves.last) return 2;
    return 0.5;
  }
}
