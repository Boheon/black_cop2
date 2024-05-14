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
  final TextEditingController _messageController = TextEditingController();
  List<String> _phoneNumbers = [];
  List<int> previousValue = [];
  //BluetoothAlarm bleAlarm = BluetoothAlarm(SECOND: 10, SIGNAL_THRESHOLD: 10);
  List<BluetoothDevice> bluetoothDevices = FlutterBluePlus.connectedDevices;
  Map<BluetoothDevice, int> rssiValues = {};
  String mobileNumber = '';
  String messageText = '';
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
    loadMessageText();

    Timer.periodic(const Duration(seconds: 10), (timer) async {
      for (BluetoothDevice device in bluetoothDevices) {
        subscribeAndReadAction(device);
        print(
            "SUBSCRIBE Action!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
        _updateAverageRssiValues(device);
        //await bleAlarm.alarm(device);
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

  // 이전에 수신된 데이터와 현재 데이터가 같은지 확인하는 함수
  bool isSameAsPrevious(List<int> value) {
    if (previousValue == value) {
      return true;
    } else {
      previousValue = value;
      return false;
    }
    // 이전에 수신된 데이터와 현재 데이터가 같은 경우가 없음
    // 현재 데이터를 이전 데이터로 저장하고 false 반환
  }

  Future<void> _loadPhoneNumbers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneNumbers = prefs.getStringList('phoneNumbers') ?? [];
    });
  }

  Future<void> loadMessageText() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      messageText = prefs.getString('messageText') ?? '';
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

  Future<void> saveMessageText(String messageText) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('messageText', messageText);
    setState(() {
      _messageController.clear();
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
          print(
              "///////////////////////////////////////////////////////////////////////////");
          print('Read value: $value');
          print(
              "///////////////////////////////////////////////////////////////////////////");
          if (value == [65, 76, 69, 82, 84]) {
            await sms.sendSMS(_phoneNumbers, mobileNumber, messageText);
            print(
                "ALERT 수신 성공!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
          } else if (value == [67]) {
            if (_phoneNumbers.isNotEmpty) {
              _callPhoneNumber(_phoneNumbers);
            }
          } else if (value == [68]) {
            await sms.sendSMS(_phoneNumbers, mobileNumber, messageText);
            if (_phoneNumbers.isNotEmpty) {
              _callPhoneNumber(_phoneNumbers);
            }
          }
        }
      });
    }
  }

  Future<void> subscribeAndReadAction(BluetoothDevice device) async {
    List<BluetoothService> services = device.servicesList;
    for (var service in services) {
      for (var characteristic in service.characteristics) {
        if (characteristic.properties.notify) {
          characteristic.setNotifyValue(true).then((_) {
            Stream<List<int>> stream = characteristic.lastValueStream;
            stream.listen((List<int> value) {
              print('Received value: $value');
              // notify된 데이터가 이전 데이터와 같은지 확인
              if (!isSameAsPrevious(value)) {
                // 서로 다른 경우에만 sendSMS 실행
                if (value[0] == 66 && value.length == 1) {
                  // 예시: 특정 값이 수신되면 SMS 전송
                  print("SMS MESSAGE SENT!");
                  sms.sendSMS(_phoneNumbers, mobileNumber, messageText);
                  print('Received ALERT message!');
                } else if (value == [67]) {
                  // 예시: 다른 특정 값이 수신되면 전화 걸기
                  if (_phoneNumbers.isNotEmpty) {
                    _callPhoneNumber(_phoneNumbers);
                  }
                } else if (value.length == 5 &&
                    value[0] == 65 &&
                    value[1] == 76 &&
                    value[2] == 69 &&
                    value[3] == 82 &&
                    value[4] == 84) {
                  // 예시: 또 다른 특정 값이 수신되면 SMS 전송 후 전화 걸기
                  sms.sendSMS(_phoneNumbers, mobileNumber, messageText);
                  if (_phoneNumbers.isNotEmpty) {
                    _callPhoneNumber(_phoneNumbers);
                  }
                }
              }
            });
          });
        }
      }
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
              await sms.sendSMS(_phoneNumbers, mobileNumber, messageText);
              if (_phoneNumbers.isNotEmpty) {
                _callPhoneNumber(_phoneNumbers);
              }
            },
            child: const Text('Emergency Call'),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _messageController,
              decoration: const InputDecoration(
                labelText: 'Enter Message Text',
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              if (_messageController.text.isNotEmpty) {
                saveMessageText(_messageController.text);
              }
            },
            child: const Text('Add Message Text'),
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
