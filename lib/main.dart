import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'dart:async';
import 'dart:math';

void main() {
  runApp(AquariumApp());
}

class AquariumApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Virtual Aquarium',
      home: AquariumScreen(),
    );
  }
}

class AquariumScreen extends StatefulWidget {
  @override
  _AquariumScreenState createState() => _AquariumScreenState();
}


class _AquariumScreenState extends State<AquariumScreen> {
  List<Fish> fishList = [];
  double speed = 100.0;
  Color fishColor = Colors.blue;
  final Random random = Random();
  late Timer _timer;

  final DatabaseHelper dbHelper = DatabaseHelper();
  
  //Add fish 
  void addFish() {
    if (fishList.length < 10) {
      setState(() {
        fishList.add(Fish(
          color: fishColor,
          speed: speed,
          position: Offset(random.nextDouble() * 280, random.nextDouble() * 280),
          direction: random.nextDouble() * 2 * pi,
        ));
      });
    }
  }
  
  //Remove last fish added
  void removeLastFish() {
    setState(() {
      if (fishList.isNotEmpty) {
        fishList.removeLast();
      }
    });
  }

  //Save and load functions
  void saveSettings() async {
    await dbHelper.saveSettings(fishList.length, speed, fishColor.value);
  }

  void loadSettings() async {
    final settings = await dbHelper.loadSettings();
    if (settings != null) {
      setState(() {
        int count = settings['fish_count'];
        speed = settings['speed'] ?? speed;
        fishColor = Color(settings['color']);
        fishList.clear();
        for (int i = 0; i < count; i++) {
          fishList.add(Fish(
            color: fishColor,
            speed: speed,
            position: Offset(random.nextDouble() * 280, random.nextDouble() * 280),
            direction: random.nextDouble() * 2 * pi,
          ));
        }
      });
    }
  }

  //Controls how the fish moves
  void moveFish() {
    setState(() {
      for (var fish in fishList) {
        double newX = fish.position.dx + cos(fish.direction) * (speed / 100);
        double newY = fish.position.dy + sin(fish.direction) * (speed / 100);

        if (newX <= 0 || newX >= 280) {
          fish.direction = pi - fish.direction;
          newX = newX < 0 ? 0 : 280;
        }
        if (newY <= 0 || newY >= 280) {
          fish.direction = -fish.direction;
          newY = newY < 0 ? 0 : 280;
        }

        fish.position = Offset(newX, newY);

        if (random.nextDouble() < 0.1) {
          fish.direction += random.nextDouble() * 2 * pi / 5 - (pi / 5);
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    loadSettings();
    _timer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      moveFish();
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Virtual Aquarium')),
      body: Column(
        children: [
          Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              color: Colors.lightBlue[50],
              border: Border.all(color: Colors.blue, width: 2),
            ),
            child: Stack(
              children: fishList.map((fish) => Positioned(
                left: fish.position.dx,
                top: fish.position.dy,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: fish.color,
                    shape: BoxShape.circle,
                  ),
                ),
              )).toList(),
            ),
          ),
          Row(
            children: [
              ElevatedButton(onPressed: addFish, child: Text('Add Fish')),
              ElevatedButton(onPressed: removeLastFish, child: Text('Remove Last Fish')),
              ElevatedButton(onPressed: saveSettings, child: Text('Save Settings')),
            ],
          ),
          Row(
            children: [
              Text('Speed:'),
              Slider(
                value: speed,
                min: 50,
                max: 200,
                onChanged: (value) {
                  setState(() {
                    speed = value;
                  });
                },
              ),
            ],
          ),
          Row(
            children: [
              Text('Fish Color:'),
              DropdownButton<Color>(
                value: fishColor,
                items: [
                  Colors.blue,
                  Colors.red,
                  Colors.green,
                  Colors.yellow,
                ].map((color) {
                  return DropdownMenuItem(
                    value: color,
                    child: Container(
                      width: 20,
                      height: 20,
                      color: color,
                    ),
                  );
                }).toList(),
                onChanged: (color) {
                  setState(() {
                    fishColor = color!;
                  });
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

//Classes and helpers
class Fish {
  Color color;
  double speed;
  Offset position;
  double direction;

  Fish({required this.color, required this.speed, required this.position, required this.direction});
}

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() {
    return _instance;
  }

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'aquarium.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE settings(id INTEGER PRIMARY KEY, fish_count INTEGER, speed REAL, color INTEGER)',
        );
      },
    );
  }

  Future<void> saveSettings(int fishCount, double speed, int color) async {
    final db = await database;
    await db.insert(
      'settings',
      {
        'fish_count': fishCount,
        'speed': speed,
        'color': color,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> loadSettings() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('settings');
    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }
}
