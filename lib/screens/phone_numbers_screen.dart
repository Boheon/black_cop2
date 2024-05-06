import 'dart:async';
import 'dart:io';
import 'package:black_cops/utils/bluetooth_alarm.dart';
import 'package:black_cops/utils/naver_cloud_sms.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:mobile_number/mobile_number.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';

class PhoneNumbersScreen extends StatefulWidget {
  const PhoneNumbersScreen({super.key});

  @override
  _PhoneNumbersScreenState createState() => _PhoneNumbersScreenState();
}

class _PhoneNumbersScreenState extends State<PhoneNumbersScreen> {
  NaverCloudSms sms = NaverCloudSms();
  final TextEditingController _controller = TextEditingController();
  List<String> _phoneNumbers = [];
  BluetoothAlarm bleAlarm = BluetoothAlarm(SECOND: 10, MESSAGE_DISTANCE: 10);
  List<BluetoothDevice> bluetoothDevices = FlutterBluePlus.connectedDevices;
  Map<BluetoothDevice, int> rssiValues = {};
  String mobileNumber = '';
  List<SimCard> simCards = <SimCard>[];

  @override
  void initState() {
    super.initState();
    MobileNumber.listenPhonePermission((isPermissionGranted) {
      if (isPermissionGranted) {
        initMobileNumberState();
      } else {}
    });

    initMobileNumberState();
    _loadPhoneNumbers();
    Timer.periodic(Duration(seconds: bleAlarm.SECOND), (timer) async {
      for (BluetoothDevice device in bluetoothDevices) {
        _updateAverageRssiValues(device);
        await bleAlarm.alarm(device);
      }
    });
  }

  Future<void> initMobileNumberState() async {
    if (!await MobileNumber.hasPhonePermission) {
      await MobileNumber.requestPhonePermission;
      return;
    }
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      mobileNumber = (await MobileNumber.mobileNumber)!;
      simCards = (await MobileNumber.getSimCards)!;
    } on PlatformException catch (e) {
      debugPrint("Failed to get mobile number because of '${e.message}'");
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {});
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _updateAverageRssiValues(BluetoothDevice device) async {
    List<int> rssiList = [];
    try {
      // 1초마다 5번의 RSSI 값을 읽어들임
      for (int i = 0; i < 5; i++) {
        int rssi = await device.readRssi();
        readAction(device);
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

  Future<void> _loadPhoneNumbers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneNumbers = prefs.getStringList('phoneNumbers') ?? [];
    });
  }

  Future<void> _savePhoneNumber(String phoneNumber) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _phoneNumbers.add(phoneNumber);
    await prefs.setStringList('phoneNumbers', _phoneNumbers);
    setState(() {
      _controller.clear();
    });
  }

  Future<void> _removePhoneNumber(String phoneNumber) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    _phoneNumbers.remove(phoneNumber);
    await prefs.setStringList('phoneNumbers', _phoneNumbers);
    setState(() {});
  }

  Future<void> readAction(BluetoothDevice device) async {
    List<BluetoothService> services = device.servicesList;
    for (var service in services) {
      service.characteristics.forEach((characteristic) async {
        if (characteristic.properties.read) {
          List<int> value = await characteristic.read();
          print('Read value: $value');
          if (value == [66]) {
            await sms.sendSMS(_phoneNumbers, mobileNumber);
          } else if (value == [67]) {
            if (_phoneNumbers.isNotEmpty) {
              _callPhoneNumber(_phoneNumbers);
            }
          } else if (value == [68]) {
            await sms.sendSMS(_phoneNumbers, mobileNumber);
            if (_phoneNumbers.isNotEmpty) {
              _callPhoneNumber(_phoneNumbers);
            }
          }
        }
      });
    }
  }

  Future<void> _callPhoneNumber(List<String> phoneNumbers) async {
    for (String phoneNumber in phoneNumbers) {
      bool? res = await FlutterPhoneDirectCaller.callNumber(phoneNumber);
      sleep(const Duration(seconds: 10));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Number Manager'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Enter Phone Number',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_phoneNumbers.length < 5 && _controller.text.isNotEmpty) {
                _savePhoneNumber(_controller.text);
              }
            },
            child: const Text('Add Phone Number'),
          ),
          ElevatedButton(
            onPressed: () async {
              await sms.sendSMS(_phoneNumbers, mobileNumber);
              if (_phoneNumbers.isNotEmpty) {
                _callPhoneNumber(_phoneNumbers);
              }
            },
            child: const Text('Emergency Call'),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _phoneNumbers.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_phoneNumbers[index]),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          _removePhoneNumber(_phoneNumbers[index]);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone),
                        onPressed: () async {
                          await FlutterPhoneDirectCaller.callNumber(
                              _phoneNumbers[index]);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
