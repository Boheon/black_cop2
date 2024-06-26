import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

class NaverCloudSms {
  final String ACCESS_KEY = dotenv.get('ACCESS_KEY');
  final String SERVICE_ID = dotenv.get('SERVICE_ID');
  final String SECRET_KEY = dotenv.get('SECRET_KEY');
  // final String ACCESS_ID = 'av67jMzkJA1UADyNKG9';
  // final String SERVICE_ID = 'ncp:sms:kr:331509974752:blackcops';
  // final String SECRET_KEY = 'HZtpWfiutctmuvh6Qca4TLbUzTyOBX60mEpZT4pw';
  String timestamp = (DateTime.now().millisecondsSinceEpoch).toString();
  Future<void> sendSMS(
      List<String> phoneNumbers, String myNumber, String message) async {
    print(
        "------------------------------------------------------------------------------------");
    print('timeStamp = $timestamp');
    print('accessKey = $ACCESS_KEY');
    print('serviceID = $SERVICE_ID');
    print('secretKey = $SECRET_KEY');
    print('signatureKey = ${getSignature()}');
    print(
        "------------------------------------------------------------------------------------");
    String location = await getCurrentLocation();
    final url = Uri.parse(
        'https://sens.apigw.ntruss.com/sms/v2/services/$SERVICE_ID/messages');
    final response = await http.post(
      url,
      headers: {
        'Content-type': 'application/json; charset=utf-8',
        'x-ncp-apigw-timestamp': timestamp,
        'x-ncp-iam-access-key': ACCESS_KEY,
        'x-ncp-apigw-signature-v2': getSignature(),
      },
      body: json.encode({
        'type': 'LMS',
        'contentType': 'COMM',
        'countryCode': '82',
        'from': '01046317403',
        'subject': 'black cop 알림',
        'content': "도와주세요! 번호 : $myNumber, 현재위치 : $location 내용: $message",
        'messages': phoneNumbers.map((phoneNumber) {
          return {
            "to": phoneNumber,
            "subject": "도와주세요!!!",
            "content": "도와주세요! 번호 : $myNumber, 현재위치 : $location \n $message",
          };
        }).toList(),
        'files': []
      }),
    );

    if (response.statusCode == 200) {
      print('SMS sent successfully to $phoneNumbers');
    } else {
      print('Failed to send SMS : ${response.body}');
    }
    print(
        "------------------------------------------------------------------------------------");
    print("Status code : ${response.statusCode}");
    print("Status body : ${response.body}");
    print(
        "------------------------------------------------------------------------------------");
  }

  Future<String> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    //위치 서비스 활성화 여부 확인
    serviceEnabled = await Geolocator.isLocationServiceEnabled();

    //활성화x 시 알림
    if (!serviceEnabled) {
      print('Location service is disabled');
      return 'Location service is disabled';
    }

    //위치 권한 확인
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      //재신청해도 거부될경우
      if (permission == LocationPermission.denied) {
        print('Location permission is denied');
        return 'Location permission is denied';
      }
    }

    //권한이 영구 거부일 경우
    if (permission == LocationPermission.deniedForever) {
      print(
          'Location permissions are permanently denied, we cannot request permissions.');
      return 'Location permissions are permanently denied, we cannot request permissions.';
    }

    //위치정보 가져오기
    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);

    return 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
  }

  String getSignature() {
    var space = " "; // one space
    var newLine = "\n"; // new line
    var method = "POST"; // method
    var url = "/sms/v2/services/$SERVICE_ID/messages";

    var buffer = StringBuffer();
    buffer.write(method);
    buffer.write(space);
    buffer.write(url);
    buffer.write(newLine);
    buffer.write(timestamp);
    buffer.write(newLine);
    buffer.write(ACCESS_KEY);
    print(buffer.toString());

    /// signing key
    var key = utf8.encode(SECRET_KEY);
    var signingKey = Hmac(sha256, key);

    var bytes = utf8.encode(buffer.toString());
    var digest = signingKey.convert(bytes);

    String signatureKey = base64.encode(digest.bytes);
    return signatureKey;
  }
}
