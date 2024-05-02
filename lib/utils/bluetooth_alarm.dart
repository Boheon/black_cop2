import 'dart:math';

import 'package:black_cops/utils/kalman_filter.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BluetoothAlarm {
  final int SECOND;
  final int MESSAGE_DISTANCE;
  KalmanFilter kalman = KalmanFilter();
  //late FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  BluetoothAlarm({required this.SECOND, required this.MESSAGE_DISTANCE}) {
    //flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    //_initailizeNotifications();
  }

  // void _initailizeNotifications() {
  //   const AndroidInitializationSettings initializationSettingsAndroid =
  //       AndroidInitializationSettings('app_icon');
  //   const InitializationSettings initializationSettings =
  //       InitializationSettings(android: initializationSettingsAndroid);
  //   //flutterLocalNotificationsPlugin.initialize(initializationSettings);
  // }

  Future alarm(BluetoothDevice device) async {
    //평균 rssi값 계산
    int avgRssi = await _calculateAverageRssi(device);

    //평균으로 거리계산
    num distance = calculateDistance(-59, avgRssi);

    if (distance > MESSAGE_DISTANCE) {
      await writeData(device, "M");
      _showNotification();
    } else {
      print("------------------------------------------------");
    }
  }

  List<int> _getBytes(String s) {
    List<int> asciiCodes = [];
    for (int i = 0; i < s.length; i++) {
      asciiCodes.add(s.codeUnitAt(i));
    }

    return asciiCodes;
  }

  Future<int> _calculateAverageRssi(BluetoothDevice device) async {
    List<int> rssiList = [];
    try {
      for (int i = 0; i < 5; i++) {
        int rssi = await device.readRssi();
        rssiList.add(rssi);
        await Future.delayed(const Duration(seconds: 1));
      }

      int sum = rssiList.reduce((value, element) => value + element);
      return sum ~/ rssiList.length; //average
    } catch (e) {
      print('Failed to read RSSI: $e');
      return 0;
    }
  }

  Future writeData(BluetoothDevice device, String s) async {
    try {
      List<BluetoothService> services = device.servicesList;
      for (var service in services) {
        service.characteristics.forEach((characteristic) async {
          if (characteristic.properties.write) {
            await characteristic.write(_getBytes(s),
                withoutResponse:
                    characteristic.properties.writeWithoutResponse);
            print('data write 완료');
          }
        });
      }
    } catch (e) {
      print('데이터 쓰기 실패: $e');
    }
  }

  num calculateDistance(int txPower, int average) {
    return pow(
        10, ((txPower - kalman.filtering(average.toDouble())) / (10 * 2.0)));
  }

  Future<void> _showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
            'alarm_notification_channel', 'Alarm Notification Channel',
            channelDescription: 'Channel for alarm notification',
            importance: Importance.max,
            priority: Priority.high);
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // await flutterLocalNotificationsPlugin.show(
    //     0, 'Bluetooth Alarm', '기기가 멀리 떨어졌습니다!', platformChannelSpecifics,
    //     payload: 'alarm_notification');
  }
}
