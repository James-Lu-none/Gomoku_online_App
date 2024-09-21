
import 'package:flutter/material.dart';
import 'lobby_page.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'room_page.dart';
import 'menu_page.dart';
import 'package:firebase_database/firebase_database.dart';
const firebaseConfig = {
  'apiKey': "AIzaSyALnN2QJODqY-SFX0Dyde7f9T61Xy7BQPs",
  'authDomain': "gomokuonline-1c33d.firebaseapp.com",
  'databaseURL': "https://gomokuonline-1c33d-default-rtdb.asia-southeast1.firebasedatabase.app",
  'projectId': "gomokuonline-1c33d",
  'storageBucket': "gomokuonline-1c33d.appspot.com",
  'messagingSenderId': "607528818092",
  'appId': "1:607528818092:web:5f5b55ecdc4a2528a6d609",
  'measurementId': "G-M0CEEXG81C"
};
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(App());
}


class App extends StatelessWidget{
  App({super.key});
  final Future<FirebaseApp> _init=Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform,);
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Gomoku_online',
    theme: ThemeData(
      primarySwatch: Colors.blue,
      appBarTheme: AppBarTheme(
        iconTheme: IconThemeData(color: Colors.black),
        color: Colors.deepPurpleAccent, //<-- SEE HERE
      ),
    ),
    home: FutureBuilder(
      future: _init,
      builder: (BuildContext context, AsyncSnapshot<FirebaseApp> snapshot) {
        if(snapshot.hasError){
          print("Error");
        }
        if(snapshot.connectionState==ConnectionState.done){

          return LobbyPage();
        }

        return const Center(
          child:
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(),
              )
        );

      },
    ),
  );

}