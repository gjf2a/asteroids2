import 'dart:async';

import 'package:flutter/material.dart';

import 'asteroids.dart';
import 'math2d.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Game _game = Game();

  _MyHomePageState() {
    Timer.periodic(Duration(milliseconds: 50), _timeHandler);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child:
        LayoutBuilder(
            builder: (_, constraints) => Container(
                width: constraints.widthConstraints().maxWidth,
                height: constraints.heightConstraints().maxHeight,
                color: Colors.black,
                child: CustomPaint(painter: AsteroidsGame(_game, _handler)))
        ),
      ),
    );
  }

  void _handler() {
    setState(() {});
  }

  void _timeHandler(Timer t) {
    setState(() {
      _game.tick();
    });
  }
}

// How to use the CustomPainter/Canvas:
// https://codewithandrea.com/videos/2020-01-27-flutter-custom-painting-do-not-fear-canvas/
class AsteroidsGame extends CustomPainter {
  Game _game;
  void Function() _handler;

  AsteroidsGame(Game game, void Function() handler) {
    _game = game;
    _handler = handler;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _game.setBoundaries(size.width, size.height);
    _game.paint(canvas);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

  @override
  bool hitTest(Offset position) {
    if (_game.live) {
      _game.rotateShip(Point(position.dx, position.dy));
      _game.fire();
      _handler();
    } else {
      _game.restart();
    }
    return true;
  }
}