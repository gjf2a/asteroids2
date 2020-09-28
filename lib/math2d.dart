import 'dart:math';

class Point {
  double _x, _y;

  Point(this._x, this._y);

  double distance(Point other) {
    return sqrt(pow(_x - other._x, 2) + pow(_y - other._y, 2));
  }

  Point operator+(Point other) {
    return Point(_x + other._x, _y + other._y);
  }

  Point operator-(Point other) {
    return Point(_x - other._x, _y - other._y);
  }

  double directionTo(Point other) {
    Point difference = other - this;
    return atan2(difference._y, difference._x);
  }

  bool operator==(Object other) {
    return other is Point && _x == other._x && _y == other._y;
  }

  bool within(double width, double height) {
    return _within(_x, width) && _within(_y, height);
  }

  Point wrapped(double width, double height) {
    return Point(_wrap(_x, width), _wrap(_y, height));
  }

  String toString() => "Point($_x,$_y)";

  @override
  int get hashCode => toString().hashCode;

  double get x => _x;
  double get y => _y;
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

bool _within(double v, double bound) {
  return v >= 0 && v <= bound;
}

class Polar {
  double _r, _theta;

  Polar(this._r, this._theta) {
    while (_theta < 0) {_theta += 2*pi;}
    while (_theta >= 2 * pi) {_theta -= 2*pi;}
  }

  bool operator==(Object other) {
    return other is Polar && _r == other._r && _theta == other._theta;
  }

  Polar operator+(Polar other) {
    return Polar(_r + other._r, _theta + other._theta);
  }

  Point toPoint() {
    return Point(_r * cos(_theta), _r * sin(_theta));
  }

  String toString() => "Polar($_r,$_theta)";

  @override
  int get hashCode => toString().hashCode;

  double get r => _r;
  double get theta => _theta;
}