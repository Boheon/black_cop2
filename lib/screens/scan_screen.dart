import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'device_screen.dart';
import '../screens/phone_numbers_screen.dart';
import '../utils/snackbar.dart';
import '../widgets/system_device_tile.dart';
import '../widgets/scan_result_tile.dart';
import '../utils/extra.dart';

List<String> searchTexts = ['BLKCOPS', 'PRX'];

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final List<BluetoothDevice> _systemDevices = [];
  List<ScanResult> _scanResults = [];
  List<ScanResult> _scannedDevicesByKeywords = [];
  List<ScanResult> _scannedDevicesByIds = [];
  List<String> _savedDeviceIds = [];
  bool _isScanning = false;
  late StreamSubscription<List<ScanResult>> _scanResultsSubscription;
  late StreamSubscription<bool> _isScanningSubscription;
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _scanResultsSubscription = FlutterBluePlus.scanResults.listen((results) {
      _scanResults = results;
      if (mounted) {
        setState(() {});
      }
      print('Number of devices found during scan : ${results.length}');
    }, onError: (e) {
      Snackbar.show(ABC.b, prettyException("Scan Error:", e), success: false);
    });

    _isScanningSubscription = FlutterBluePlus.isScanning.listen((state) {
      _isScanning = state;
      if (mounted) {
        setState(() {});
      }
    });

    _initConnectSavedDevices();
  }

  @override
  void dispose() {
    _scanResultsSubscription.cancel();
    _isScanningSubscription.cancel();
    super.dispose();
  }

  Future<void> _initConnectSavedDevices() async {
    await _loadSavedDeviceID();
    await onScanPressedById();
    await _autoConnectSavedDevices();
  }

  Future<void> _loadSavedDeviceID() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _savedDeviceIds = _prefs?.getStringList('savedDeviceIds') ?? [];
    });
    print("1. load Saved Device Ids: $_savedDeviceIds");
  }

  Future<void> _autoConnectSavedDevices() async {
    print(
        "-----------------------------------------------------------------------------------------");
    print("2.auto Saved Device Ids: $_savedDeviceIds");
    print(
        "-----------------------------------------------------------------------------------------");

    for (String _savedDeviceId in _savedDeviceIds) {
      try {
        if (_scanResults.isEmpty) {
          print('No scan results available.');
          return;
        }
        ScanResult? result = _scanResults.firstWhere(
          (r) => r.device.remoteId.toString() == _savedDeviceId,
        );

        BluetoothDevice device = result.device;
        await device.connectAndUpdateStream();
        _systemDevices.add(device);
        setState(() {});
      } catch (e) {
        print("Auto connect error : $e");
      }
    }
  }

  void printDeviceIds(List<ScanResult> results) {
    for (ScanResult result in results) {
      print("Device Id: ${result.device.remoteId}");
    }
  }

  Future<void> _saveConnectedDeviceId(String deviceId) async {
    List<String> savedDeviceIds = _prefs!.getStringList('savedDeviceIds') ?? [];
    print(
        "-----------------------------------------------------------------------------------------");
    print(" button Saved Device Ids: $savedDeviceIds");
    print(
        "-----------------------------------------------------------------------------------------");
    if (!savedDeviceIds.contains(deviceId)) {
      savedDeviceIds.add(deviceId);
      await _prefs!.setStringList('savedDeviceIds', savedDeviceIds);
    }
  }

  Future<void> _removeConnectedDeviceId(String deviceId) async {
    List<String> savedDeviceIds = _prefs!.getStringList('savedDeviceIds') ?? [];
    savedDeviceIds.remove(deviceId);
    await _prefs!.setStringList('savedDeviceIds', savedDeviceIds);
  }

  Future<void> _clearConnectedDeviceIds() async {
    await _prefs!.remove('savedDeviceIds');
  }

  Future onScanPressed() async {
    try {
      print('Starting scan....');
      await FlutterBluePlus.startScan(
          withKeywords: searchTexts, timeout: const Duration(seconds: 15));
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Start Scan Error:", e),
          success: false);
    }

    // 스캔 결과를 기다렸다가 처리
    await Future.delayed(const Duration(seconds: 15));
    _scannedDevicesByKeywords = _scanResults;
    print('Devices found with keywords: ${_scannedDevicesByKeywords.length}');
    printDeviceIds(_scannedDevicesByKeywords);

    if (mounted) {
      setState(() {});
    }
  }

  Future onScanPressedById() async {
    try {
      print('Starting scan with saved device IDs...');
      await FlutterBluePlus.startScan(
          withRemoteIds: _savedDeviceIds, timeout: const Duration(seconds: 15));
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Start Scan Error:", e),
          success: false);
    }

    await Future.delayed(const Duration(seconds: 15));
    _scannedDevicesByIds = _scanResults;
    print(
        'Devices found with saved device IDs: ${_scannedDevicesByIds.length}');
    printDeviceIds(_scannedDevicesByIds);

    if (mounted) {
      setState(() {});
    }
  }

  Future onStopPressed() async {
    try {
      FlutterBluePlus.stopScan();
      print('Scan stopped.');
    } catch (e) {
      Snackbar.show(ABC.b, prettyException("Stop Scan Error:", e),
          success: false);
    }
  }

  void onConnectPressed(BluetoothDevice device) async {
    try {
      device.connectAndUpdateStream();
      _systemDevices.add(device);
      await _saveConnectedDeviceId(device.remoteId.toString());
      setState(() {});
    } catch (e) {
      Snackbar.show(ABC.c, prettyException("Connect Error:", e),
          success: false);
    }

    MaterialPageRoute route = MaterialPageRoute(
        builder: (context) => DeviceScreen(device: device),
        settings: const RouteSettings(name: '/DeviceScreen'));
    Navigator.of(context).push(route);
  }

  void onRegisterPressed() {
    MaterialPageRoute route = MaterialPageRoute(
      builder: (context) => const PhoneNumbersScreen(),
      settings: const RouteSettings(name: '/PhoneNumberScreen'),
    );
    Navigator.of(context).push(route);
  }

  Future onRefresh() {
    if (_isScanning == false) {
      FlutterBluePlus.startScan(timeout: const Duration(seconds: 15));
    }
    if (mounted) {
      setState(() {});
    }
    return Future.delayed(const Duration(milliseconds: 500));
  }

  Widget buildScanButton(BuildContext context) {
    if (FlutterBluePlus.isScanningNow) {
      return FloatingActionButton(
        onPressed: onStopPressed,
        backgroundColor: Colors.red,
        child: const Icon(Icons.stop),
      );
    } else {
      return FloatingActionButton(
          onPressed: onScanPressed, child: const Text("SCAN"));
    }
  }

  List<Widget> _buildSystemDeviceTiles(BuildContext context) {
    return _systemDevices
        .map(
          (d) => SystemDeviceTile(
            device: d,
            onOpen: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => DeviceScreen(device: d),
                settings: const RouteSettings(name: '/DeviceScreen'),
              ),
            ),
            onConnect: () => onConnectPressed(d),
          ),
        )
        .toList();
  }

  List<Widget> _buildScanResultTiles(BuildContext context) {
    return _scanResults
        .map(
          (r) => ScanResultTile(
            result: r,
            onTap: () => onConnectPressed(r.device),
          ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: Snackbar.snackBarKeyB,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Find Devices'),
        ),
        body: Column(
          children: <Widget>[
            Expanded(
              child: RefreshIndicator(
                onRefresh: onRefresh,
                child: ListView(
                  children: <Widget>[
                    ..._buildSystemDeviceTiles(context),
                    ..._buildScanResultTiles(context),
                  ],
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: buildScanButton(context),
      ),
    );
  }
}
