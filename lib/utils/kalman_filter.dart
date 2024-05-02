
class KalmanFilter {
  bool _initialized = false;
  late double _processNoise;
  late double _measurementNoise;
  double _predictedRSSI = 0;
  double _errorCovariance = 0;

  KalmanFilter({double processNoise = 0.005, double measurementNoise = 20}) {
    _processNoise = processNoise;
    _measurementNoise = measurementNoise;
  }

  double filtering(double rssi) {
    if (!_initialized) {
      _initialized = true;
      _predictedRSSI = rssi;
      _errorCovariance = 1;
    } else {
      double priorRSSI = _predictedRSSI;
      double priorErrorCovariance = _errorCovariance + _processNoise;

      double kalmanGain =
          priorErrorCovariance / (priorErrorCovariance + _measurementNoise);
      _predictedRSSI = priorRSSI + (kalmanGain * (rssi - priorRSSI));
      _errorCovariance = (1 - kalmanGain) * priorErrorCovariance;
    }

    return _predictedRSSI;
  }
}
