import 'dart:async';
import 'dart:io';

import 'package:black_cops/screens/log_screen.dart';
import 'package:black_cops/screens/mood_screen.dart';
import 'package:black_cops/screens/phone_numbers_screen.dart';
import 'package:black_cops/screens/scan_screen.dart';
import 'package:black_cops/utils/bluetooth_alarm.dart';
import 'package:black_cops/utils/naver_cloud_sms.dart';
import 'package:flutter/services.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_phone_direct_caller/flutter_phone_direct_caller.dart';
import 'package:mobile_number/mobile_number.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/flutter_flow_widgets.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import 'home_page_model.dart';
export 'home_page_model.dart';

class HomePageWidget extends StatefulWidget {
  const HomePageWidget({super.key});

  @override
  State<HomePageWidget> createState() => _HomePageWidgetState();
}

class _HomePageWidgetState extends State<HomePageWidget> {
  late HomePageModel _model;
  List<BluetoothDevice> devices = FlutterBluePlus.connectedDevices;
  final scaffoldKey = GlobalKey<ScaffoldState>();
  BluetoothAlarm bleAlarm = BluetoothAlarm(SECOND: 10, MESSAGE_DISTANCE: 10);
  List<String> _phoneNumbers = [];
  Map<BluetoothDevice, int> rssiValues = {};
  NaverCloudSms sms = NaverCloudSms();
  String _mobileNumber = '';

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => HomePageModel());
    WidgetsBinding.instance.addPostFrameCallback((_) => setState(() {}));

    _loadPhoneNumbers();

    MobileNumber.listenPhonePermission((isPermissionGranted) {
      if (isPermissionGranted) {
        initMobileNumberState();
      } else {}
    });

    initMobileNumberState();

    Timer.periodic(Duration(seconds: bleAlarm.SECOND), (timer) async {
      for (BluetoothDevice device in devices) {
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
      _mobileNumber = (await MobileNumber.mobileNumber)!;
    } on PlatformException catch (e) {
      debugPrint("Failed to get mobile number because of '${e.message}'");
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {});
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

  Future<void> readAction(BluetoothDevice device) async {
    List<BluetoothService> services = device.servicesList;
    for (var service in services) {
      service.characteristics.forEach((characteristic) async {
        if (characteristic.properties.read) {
          List<int> value = await characteristic.read();
          print('Read value: $value');
          if (value == [66]) {
            await sms.sendSMS(_phoneNumbers, _mobileNumber);
          } else if (value == [67]) {
            if (_phoneNumbers.isNotEmpty) {
              _callPhoneNumber(_phoneNumbers);
            }
          } else if (value == [68]) {
            await sms.sendSMS(_phoneNumbers, _mobileNumber);
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

  Future<void> _loadPhoneNumbers() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _phoneNumbers = prefs.getStringList('phoneNumbers') ?? [];
    });
  }

  @override
  void dispose() {
    _model.dispose();

    super.dispose();
  }

  List<int> _getBytes(String s) {
    List<int> asciiCodes = [];
    for (int i = 0; i < s.length; i++) {
      asciiCodes.add(s.codeUnitAt(i));
    }

    return asciiCodes;
  }

  void onRegisterPressed() {
    MaterialPageRoute route = MaterialPageRoute(
      builder: (context) => const ScanScreen(),
      settings: const RouteSettings(name: '/ScanScreen'),
    );
    Navigator.of(context).push(route);
  }

  void onMoodPressed() async {
    MaterialPageRoute route = MaterialPageRoute(
      builder: (context) => const MoodScreen(),
      settings: const RouteSettings(name: '/MoodScreen'),
    );
    Navigator.of(context).push(route);
  }

  void onAddressPressed() {
    MaterialPageRoute route = MaterialPageRoute(
      builder: (context) => const PhoneNumbersScreen(),
      settings: const RouteSettings(name: '/PhoneNumberScreen'),
    );
    Navigator.of(context).push(route);
  }

  void onLogPressed() {
    MaterialPageRoute route = MaterialPageRoute(
      builder: (context) => const LogScreen(),
      settings: const RouteSettings(name: '/LogScreen'),
    );
    Navigator.of(context).push(route);
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

    return GestureDetector(
      onTap: () => _model.unfocusNode.canRequestFocus
          ? FocusScope.of(context).requestFocus(_model.unfocusNode)
          : FocusScope.of(context).unfocus(),
      child: Scaffold(
        key: scaffoldKey,
        backgroundColor: const Color(0xFF646464),
        appBar: AppBar(
          backgroundColor: const Color(0xFF393939),
          automaticallyImplyLeading: false,
          title: Align(
            alignment: const AlignmentDirectional(0.0, 0.0),
            child: Padding(
              padding:
                  const EdgeInsetsDirectional.fromSTEB(0.0, 20.0, 0.0, 20.0),
              child: Text(
                '블랙캅스',
                style: FlutterFlowTheme.of(context).headlineMedium.override(
                      fontFamily: 'Outfit',
                      color: Colors.white,
                      fontSize: 24.0,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
          actions: const [],
          centerTitle: false,
          elevation: 3.0,
        ),
        body: SafeArea(
          top: true,
          child: Align(
            alignment: const AlignmentDirectional(0.0, 0.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.asset(
                    'assets/images/BlackCops6.png',
                    width: 134.0,
                    height: 132.0,
                    fit: BoxFit.cover,
                  ),
                ),
                Opacity(
                  opacity: FFAppState().optionOp,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        0.0, 10.0, 0.0, 0.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.elasticOut,
                      width: 300.0,
                      height: 76.0,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          fit: BoxFit.fill,
                          image: Image.asset(
                            'assets/images/scan.png',
                          ).image,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 4.0,
                            color: Color(0x33000000),
                            offset: Offset(
                              0.0,
                              2.0,
                            ),
                          )
                        ],
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).primaryText,
                            FlutterFlowTheme.of(context).secondaryText
                          ],
                          stops: const [0.0, 1.0],
                          begin: const AlignmentDirectional(0.0, -1.0),
                          end: const AlignmentDirectional(0, 1.0),
                        ),
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                      child: Opacity(
                        opacity: 0.1,
                        child: FFButtonWidget(
                          onPressed: onRegisterPressed,
                          text: '',
                          options: FFButtonOptions(
                            height: 40.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                24.0, 0.0, 24.0, 0.0),
                            iconPadding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: FlutterFlowTheme.of(context).primary,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  fontFamily: 'Readex Pro',
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                ),
                            elevation: 3.0,
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                            hoverColor:
                                FlutterFlowTheme.of(context).primaryText,
                            hoverElevation: 10.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: FFAppState().optionOp,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        0.0, 30.0, 0.0, 0.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.elasticOut,
                      width: 300.0,
                      height: 76.0,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          fit: BoxFit.fill,
                          image: Image.asset(
                            'assets/images/molight.png',
                          ).image,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 4.0,
                            color: Color(0x33000000),
                            offset: Offset(
                              0.0,
                              2.0,
                            ),
                          )
                        ],
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).primaryText,
                            FlutterFlowTheme.of(context).secondaryText
                          ],
                          stops: const [0.0, 1.0],
                          begin: const AlignmentDirectional(0.0, -1.0),
                          end: const AlignmentDirectional(0, 1.0),
                        ),
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                      child: Opacity(
                        opacity: 0.1,
                        child: FFButtonWidget(
                          onPressed: onMoodPressed,
                          text: '',
                          options: FFButtonOptions(
                            height: 40.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                24.0, 0.0, 24.0, 0.0),
                            iconPadding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: FlutterFlowTheme.of(context).primary,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  fontFamily: 'Readex Pro',
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                ),
                            elevation: 3.0,
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                            hoverColor:
                                FlutterFlowTheme.of(context).primaryText,
                            hoverElevation: 10.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: FFAppState().optionOp,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        0.0, 30.0, 0.0, 0.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.elasticOut,
                      width: 300.0,
                      height: 76.0,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          fit: BoxFit.fill,
                          image: Image.asset(
                            'assets/images/address.png',
                          ).image,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 4.0,
                            color: Color(0x33000000),
                            offset: Offset(
                              0.0,
                              2.0,
                            ),
                          )
                        ],
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).primaryText,
                            FlutterFlowTheme.of(context).secondaryText
                          ],
                          stops: const [0.0, 1.0],
                          begin: const AlignmentDirectional(0.0, -1.0),
                          end: const AlignmentDirectional(0, 1.0),
                        ),
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                      child: Opacity(
                        opacity: 0.1,
                        child: FFButtonWidget(
                          onPressed: onAddressPressed,
                          text: '',
                          options: FFButtonOptions(
                            height: 40.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                24.0, 0.0, 24.0, 0.0),
                            iconPadding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: FlutterFlowTheme.of(context).primary,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  fontFamily: 'Readex Pro',
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                ),
                            elevation: 3.0,
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                            hoverColor:
                                FlutterFlowTheme.of(context).primaryText,
                            hoverElevation: 10.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Opacity(
                  opacity: FFAppState().optionOp,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        0.0, 30.0, 0.0, 0.0),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      curve: Curves.elasticOut,
                      width: 300.0,
                      height: 76.0,
                      decoration: BoxDecoration(
                        image: DecorationImage(
                          fit: BoxFit.fill,
                          image: Image.asset(
                            'assets/images/log.png',
                          ).image,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            blurRadius: 4.0,
                            color: Color(0x33000000),
                            offset: Offset(
                              0.0,
                              2.0,
                            ),
                          )
                        ],
                        gradient: LinearGradient(
                          colors: [
                            FlutterFlowTheme.of(context).primaryText,
                            FlutterFlowTheme.of(context).secondaryText
                          ],
                          stops: const [0.0, 1.0],
                          begin: const AlignmentDirectional(0.0, -1.0),
                          end: const AlignmentDirectional(0, 1.0),
                        ),
                        borderRadius: BorderRadius.circular(0.0),
                      ),
                      child: Opacity(
                        opacity: 0.1,
                        child: FFButtonWidget(
                          onPressed: onLogPressed,
                          text: '',
                          options: FFButtonOptions(
                            height: 40.0,
                            padding: const EdgeInsetsDirectional.fromSTEB(
                                24.0, 0.0, 24.0, 0.0),
                            iconPadding: const EdgeInsetsDirectional.fromSTEB(
                                0.0, 0.0, 0.0, 0.0),
                            color: FlutterFlowTheme.of(context).primary,
                            textStyle: FlutterFlowTheme.of(context)
                                .titleSmall
                                .override(
                                  fontFamily: 'Readex Pro',
                                  color: Colors.white,
                                  letterSpacing: 0.0,
                                ),
                            elevation: 3.0,
                            borderSide: const BorderSide(
                              color: Colors.transparent,
                              width: 1.0,
                            ),
                            borderRadius: BorderRadius.circular(8.0),
                            hoverColor:
                                FlutterFlowTheme.of(context).primaryText,
                            hoverElevation: 10.0,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Lottie.asset(
                  'assets/lottie_animations/Animation_-_1712716148778.json',
                  width: 180.0,
                  height: 160.0,
                  fit: BoxFit.cover,
                  animate: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PhoneNumberScreen {
  const PhoneNumberScreen();
}
