import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class MoodScreen extends StatefulWidget {
  const MoodScreen({super.key});

  @override
  State<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends State<MoodScreen> {
  List<BluetoothDevice> bluetoothDevices = FlutterBluePlus.connectedDevices;
  //BluetoothAlarm bleAlarm = BluetoothAlarm(SECOND: 10, MESSAGE_DISTANCE: 10);
  Map<BluetoothDevice, int> rssiValues = {};

  @override
  initState() {
    super.initState();
  }

  Future<void> _updateAverageRssiValues(BluetoothDevice device) async {
    List<int> rssiList = [];
    try {
      // 1초마다 5번의 RSSI 값을 읽어들임
      for (int i = 0; i < 5; i++) {
        int rssi = await device.readRssi();
        rssiList.add(rssi);
        // 1초 대기
        await Future.delayed(const Duration(seconds: 1));
      }

      // rssiList에 측정된 값이 5개가 모이면 평균을 계산하고 상태를 업데이트함
      if (rssiList.length == 5) {
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

  //askii코드 반환
  List<int> _getBytes(String s) {
    List<int> asciiCodes = [];
    for (int i = 0; i < s.length; i++) {
      asciiCodes.add(s.codeUnitAt(i));
    }

    return asciiCodes;
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
          return ListTile(
            title: Text(device.platformName),
            onTap: () {
              //탭하면 메세지 전송
              writeData(device, 'RGB 255 0 0');
              print('write mood message');
            },
          );
        },
      ),
    );
  }
}
