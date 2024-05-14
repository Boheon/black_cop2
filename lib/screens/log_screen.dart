import 'dart:async';
import 'package:black_cops/utils/bluetooth_alarm.dart';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class LogScreen extends StatefulWidget {
  const LogScreen({super.key});

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  List<BluetoothDevice> bluetoothDevices = FlutterBluePlus.connectedDevices;
  Map<BluetoothDevice, int> rssiValues = {};
  BluetoothAlarm bleAlarm =
      BluetoothAlarm(SECOND: 200, SIGNAL_THRESHOLD: -1000);
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    //10초마다 자동으로 RSSI값을 업데이트
    Timer.periodic(Duration(seconds: bleAlarm.SECOND), (timer) async {
      for (BluetoothDevice device in bluetoothDevices) {
        print(
            "@22222222222222222222222222222222222222222222222222222222222222222222222222");
        _updateAverageRssiValues(device);
        print(
            "111111111111111111111111111111111111111111111111111111111111111111111111111");
        await bleAlarm.alarm(device);
      }
    });
  }

  Future<void> _updateAverageRssiValues(BluetoothDevice device) async {
    List<int> rssiList = [];
    try {
      // 1초마다 10번의 RSSI 값을 읽어들임
      for (int i = 0; i < 10; i++) {
        int rssi = await device.readRssi();
        rssiList.add(rssi);
        // 1초 대기
        await Future.delayed(const Duration(seconds: 1));
      }

      // rssiList에 측정된 값이 5개가 모이면 평균을 계산하고 상태를 업데이트함
      if (rssiList.length == 10) {
        // 읽어들인 RSSI 값들의 평균 계산
        int sum = rssiList.reduce((value, element) => value + element);
        int averageRssi = sum ~/ rssiList.length; // 평균 계산

        // 상태 업데이트
        setState(() {
          rssiValues[device] = averageRssi;
        });
      }
    } catch (e) {
      print('Failed to read RSSI: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected Bluetooth Devices'),
      ),
      body: ListView.builder(
          itemCount: bluetoothDevices.length,
          itemBuilder: (context, index) {
            final device = bluetoothDevices[index];
            final rssi = rssiValues[device];

            return ListTile(
              title: Text(device.platformName),
              subtitle: Text(
                  '${rssiValues[device] != null ? rssi : 'N/A'} meters away'),
              onTap: () async {
                _updateAverageRssiValues(device);
                //device.readRssi();
              },
            );
          }),
    );
  }
}
