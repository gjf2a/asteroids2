import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'math2d.dart';

// Design inspired by:
// http://cowboyprogramming.com/2007/01/05/evolve-your-heirachy

const double speedIncrement = 0.5;
const double shipScale = 1/20;
const double missileSpeed = 10;
const int numAsteroids = 12;

class Game {
  bool _isSetUp = false;
  double _width, _height;
  TagMaker _tagger = TagMaker();
  double _asteroidSpeed = speedIncrement;

  int _playerTag;

  Map<int,Position> _positions = Map();
  Map<int,Circle> _circles = Map();
  Map<int,Ship> _ships = Map();
  Map<int,Orientation> _wrapMoves = Map();
  Map<int,Orientation> _escapeMoves = Map();
  Map<int,CircleCollider> _asteroidColliders = Map();
  Map<int,CircleCollider> _missileColliders = Map();
  Map<int,ShipCollider> _shipColliders = Map();
  Map<int,Renderer> _renderers = Map();
  Map<int,LifeTracker> _trackers = Map();

  List<Map> _allMaps;

  double get width => _width;
  double get height => _height;

  Game() {
    _allMaps = [_positions, _circles, _ships, _wrapMoves, _escapeMoves,
      _asteroidColliders, _missileColliders, _shipColliders, _renderers, _trackers];
  }

  void paint(Canvas canvas) {
    if (_isSetUp) {
      _renderers.values.forEach((Renderer r) {
        r.render(canvas);
      });
    }
  }

  void restart() {
    _asteroidSpeed = speedIncrement;
    _clearAllTags();
    _setupShip();
    _setupAsteroids();
  }

  void setBoundaries(double width, double height) {
    if (_isSetUp) {
      double xScale = width / _width;
      double yScale = height / _height;
      _width = width;
      _height = height;
      _rescaleAll(xScale, yScale);
    } else {
      _width = width;
      _height = height;
      _setupShip();
      _setupAsteroids();
      _isSetUp = true;
    }
  }

  void _setupShip() {
    _playerTag = _tagger.getNextTag();
    _positions[_playerTag] = Position(_playerTag, this, Point(_width/2, _height/2));
    _wrapMoves[_playerTag] = Orientation(_playerTag, this, Polar(0, 0));
    _ships[_playerTag] = Ship(_playerTag, this, _height*shipScale, _width*shipScale);
    _shipColliders[_playerTag] = ShipCollider(_playerTag, this);
    _renderers[_playerTag] = ShipRenderer(_playerTag, this);
  }

  void _setupAsteroids() {
    _asteroidSpeed += speedIncrement;
    for (int i = 0; i < numAsteroids; i++) {
      _setupAsteroid(Polar(_asteroidSpeed, i * 2*pi/numAsteroids), (_height + _width)/20);
    }
  }

  void _setupAsteroid(Polar velocity, double radius) {
    int asteroidTag = _tagger.getNextTag();
    _createAsteroid(asteroidTag, Point(0, 0), velocity, radius, LifeTracker(asteroidTag, this, 2));
  }

  void _createAsteroid(int asteroidTag, Point position, Polar velocity, double radius, LifeTracker tracker) {
    _positions[asteroidTag] = Position(asteroidTag, this, position);
    _wrapMoves[asteroidTag] = Orientation(asteroidTag, this, velocity);
    _circles[asteroidTag] = Circle(asteroidTag, this, radius);
    _asteroidColliders[asteroidTag] = CircleCollider(asteroidTag, this);
    _renderers[asteroidTag] = CircleRenderer(asteroidTag, this);
    _trackers[asteroidTag] = tracker;
  }

  bool get live => _ships.length > 0;

  void fire() {
    int missileTag = _tagger.getNextTag();
    _positions[missileTag] = Position(missileTag, this, _ships[_playerTag].tip);
    Polar velocity = Polar(missileSpeed, _ships[_playerTag].heading);
    _escapeMoves[missileTag] = Orientation(missileTag, this, velocity);
    _circles[missileTag] = Circle(missileTag, this, 2);
    _missileColliders[missileTag] = CircleCollider(missileTag, this);
    _renderers[missileTag] = CircleRenderer(missileTag, this);
  }

  void rotateShip(Point touched) {
    _wrapMoves[_playerTag].reorient(_positions[_playerTag].position.directionTo(touched));
  }

  void tick() {
    if (_asteroidColliders.length == 0) {
      _setupAsteroids();
    }

    _moveEscape();
    _moveWrap();
    _resolveCollisions();
  }

  void _moveEscape() {
    List<int> escaped = List();
    for (MapEntry<int,Orientation> escaper in _escapeMoves.entries) {
      _positions[escaper.key].move(escaper.value.orientation);
      if (!within(_positions[escaper.key].position)) {
        escaped.add(escaper.key);
      }
    }
    _killAll(escaped);
  }

  void _moveWrap() {
    for (MapEntry<int,Orientation> wrapper in _wrapMoves.entries) {
      _positions[wrapper.key].wrapMove(wrapper.value.orientation);
    }
  }

  void _resolveCollisions() {
    Set<int> destroyed = Set();
    for (MapEntry<int,CircleCollider> ast in _asteroidColliders.entries) {
      if (live && _shipColliders[_playerTag].collidesWith(ast.value)) {
        destroyed.add(_playerTag);
        destroyed.add(ast.key);
      } else {
        for (MapEntry<int,CircleCollider> missile in _missileColliders.entries) {
          if (ast.value.collidesWith(missile.value)) {
            destroyed.add(ast.key);
            destroyed.add(missile.key);
          }
        }
      }
    }

    _spawnNewAsteroids(destroyed);
    _killAll(destroyed);
  }

  bool within(Point p) {
    return _withinRange(p.x, 0, _width) && _withinRange(p.y, 0, _height);
  }

  void _kill(int id) {
    for (Map map in _allMaps) {
      map.remove(id);
    }
  }

  void _killAll(Iterable<int> toBeDestroyed) {
    for (int id in toBeDestroyed) {
      _kill(id);
    }
  }

  void _clearAllTags() {
    _killAll(_findAllTags());
  }

  Set<int> _findAllTags() {
    Set<int> allTags = Set();
    for (Map map in _allMaps) {
      allTags.addAll(map.keys);
    }
    return allTags;
  }

  void _spawnNewAsteroids(Set<int> destroyed) {
    for (int blownUp in destroyed) {
      _spawnAsteroids(blownUp);
    }
  }

  void _spawnAsteroids(int dyingAsteroidTag) {
    if (_trackers.containsKey(dyingAsteroidTag) && _trackers[dyingAsteroidTag].hasMoreLives) {
      _spawnSuccessor(dyingAsteroidTag, pi/2);
      _spawnSuccessor(dyingAsteroidTag, -pi/2);
    }
  }

  void _spawnSuccessor(int dyingAsteroidTag, double headingOffset) {
    int newTag = _tagger.getNextTag();
    _createAsteroid(newTag,
        _positions[dyingAsteroidTag].position,
        _successorVelocity(_wrapMoves[dyingAsteroidTag].orientation, headingOffset),
        _circles[dyingAsteroidTag].radius / 2,
        _trackers[dyingAsteroidTag].successor(newTag));
  }

  void _rescaleAll(double xScale, double yScale) {
    for (Position p in _positions.values) {
      p.rescale(xScale, yScale);
    }
  }
}

Polar _successorVelocity(Polar velocity, double headingOffset)
  => Polar(velocity.r * 2, velocity.theta + headingOffset);

bool _withinRange(double value, double min, double max) => value >= min && value <= max;

class TagMaker {
  int _tag = 0;

  int getNextTag() {
    _tag += 1;
    return _tag;
  }
}

class GameDatum {
  int _tag;
  Game _game;

  GameDatum(this._tag, this._game);

  int get tag => _tag;
  Game get game => _game;
}

class Position extends GameDatum {
  Point _position;

  Position(int tag, Game game, this._position) : super(tag, game);

  Point get position => _position;

  void move(Polar movement) {
    _position += movement.toPoint();
  }

  void rescale(double xScale, double yScale) {
    _position = Point(xScale * _position.x, yScale * _position.y);
  }

  void wrapMove(Polar movement) {
    Point updated = _position + movement.toPoint();
    _position = Point(_wrap(updated.x, game.width), _wrap(updated.y, game.height));
  }
}

double _wrap(double v, double bound) {
  if (v < 0) {
    return v + bound;
  } else if (v > bound) {
    return v - bound;
  } else {
    return v;
  }
}

class Orientation extends GameDatum {
  Polar _orientation;

  Orientation(int tag, Game game, this._orientation) : super(tag, game);

  Polar get orientation => _orientation;

  void reorient(double updatedAngle) {
    _orientation = Polar(_orientation.r, updatedAngle);
  }
}

class Circle extends GameDatum {
  double _radius;

  Circle(int tag, Game game, this._radius) : super(tag, game);

  double get radius => _radius;
  Point get position => game._positions[tag].position;

  double distance(Circle other) => position.distance(other.position);

  bool contains(Point p) => position.distance(p) <= _radius;
}

class Ship extends GameDatum {
  double _height, _width;

  Ship(int tag, Game game, this._height, this._width) : super(tag, game);

  Point _offset(double distance, double angleOffset) =>
    position + Polar(distance, orientation.theta + angleOffset).toPoint();

  Point get position => game._positions[tag].position;
  Polar get orientation => game._wrapMoves[tag].orientation;
  Point get tip => _offset(_height, 0);
  Point get left => _offset(_width/2, -pi/2);
  Point get right => _offset(_width/2, pi/2);
  double get heading => game._wrapMoves[tag].orientation.theta;
}

abstract class Collider extends GameDatum {
  Collider(int tag, Game game) : super(tag, game);

  bool collidesWith(CircleCollider other);
}

class CircleCollider extends Collider {
  CircleCollider(int tag, Game game) : super(tag, game);

  Circle get circle => game._circles[tag];

  @override
  bool collidesWith(CircleCollider other) =>
      circle.distance(other.circle) <= circle.radius + other.circle.radius;
}

class ShipCollider extends Collider {

  ShipCollider(int tag, Game game) : super(tag, game);

  Ship get ship => game._ships[tag];

  @override
  bool collidesWith(CircleCollider other) =>
      other.circle.contains(ship.tip) ||
      other.circle.contains(ship.left) ||
      other.circle.contains(ship.right);
}

abstract class Renderer extends GameDatum {
  Renderer(int tag, Game game) : super(tag, game);

  void render(Canvas canvas);
}

class CircleRenderer extends Renderer {
  CircleRenderer(int tag, Game game) : super(tag, game);

  Circle get circle => game._circles[tag];

  @override
  void render(Canvas canvas) {
    Paint p = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.blue;
    canvas.drawCircle(Offset(circle.position.x, circle.position.y), circle.radius, p);
  }
}

class ShipRenderer extends Renderer {
  ShipRenderer(int tag, Game game) : super(tag, game);

  Ship get ship => game._ships[tag];

  @override
  void render(Canvas canvas) {
    Paint p = Paint()
      ..style = PaintingStyle.fill
      ..color = Colors.deepPurple;
    Path path = Path()
      ..moveTo(ship.tip.x, ship.tip.y)
      ..lineTo(ship.left.x, ship.left.y)
      ..lineTo(ship.right.x, ship.right.y)
      ..lineTo(ship.tip.x, ship.tip.y)
      ..close();
    canvas.drawPath(path, p);
  }
}

class LifeTracker extends GameDatum {
  int _countdown;

  LifeTracker(int tag, Game game, this._countdown) : super(tag, game);

  bool get hasMoreLives => _countdown > 0;

  LifeTracker successor(int tag) => LifeTracker(tag, game, _countdown - 1);
}