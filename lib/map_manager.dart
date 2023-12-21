import 'package:url_launcher/url_launcher.dart';

class MapUtils {
  MapUtils._();

  static Future<void> openMap(
      double latitude, double longitude, String name) async {
    //final uri = Uri(scheme: "geo", query: "0,0");
    final uri =
        Uri.parse("geo:$latitude,$longitude?q=$name@$latitude,$longitude");
    // host: '"0,0"',  {here we can put host}
    //queryParameters: {'q': '$latitude, $longitude'});
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      print('An error occurred');
    }
  }
}
