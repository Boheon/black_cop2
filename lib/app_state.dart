import 'package:flutter/material.dart';

class FFAppState extends ChangeNotifier {
  static FFAppState _instance = FFAppState._internal();

  factory FFAppState() {
    return _instance;
  }

  FFAppState._internal();

  static void reset() {
    _instance = FFAppState._internal();
  }

  Future initializePersistedState() async {}

  void update(VoidCallback callback) {
    callback();
    notifyListeners();
  }

  double _optionOp = 1.0;
  double get optionOp => _optionOp;
  set optionOp(double value) {
    _optionOp = value;
  }

  int _delayTime = 0;
  int get delayTime => _delayTime;
  set delayTime(int value) {
    _delayTime = value;
  }
}
