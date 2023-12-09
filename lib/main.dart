import 'dart:io';

import 'package:diyode_tracker/point_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:influxdb_client/api.dart';
import 'package:latlong2/latlong.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';

import 'secrets.dart';

void main() async {
  runApp(const MyApp());
  ByteData data =
      await PlatformAssetBundle().load('assets/ca/lets-encrypt-r3.pem');
  SecurityContext.defaultContext
      .setTrustedCertificatesBytes(data.buffer.asUint8List());
  var client = InfluxDBClient(
      // IMPORTANT: You will need to fill these out in secrets.dart
      url: secret_url,
      token: secret_influxAPIkey,
      org: 'diyode',
      bucket: 'tracker',
      debug: true);

  var healthCheck = await client.getHealthApi().getHealth();
  print(
      'Health check: ${healthCheck.name}/${healthCheck.version} - ${healthCheck.message}');

  var queryService = client.getQueryService();
  /*var fluxQuery = '''
  from(bucket: "tracker")
  |> range(start: -1h)
  |> filter(fn: (r) => r["_measurement"] == "liams_wallet")
  |> filter(fn: (r) => r["_field"] == "lat" or r["_field"] == "lon")
  |> last()  ''';

  var count = 0;
  var recordStream = await queryService.query(fluxQuery);

  double lat = 0;
  double lon = 0;
  await recordStream.forEach((record) {
    print(
        'record: ${count++} ${record['_time']}: ${record['_field']} ${record['_value']}');
    if (record['_field'] == "lon") {
      lon = record['_value'];
    }
    if (record['_field'] == "lat") {
      lat = record['_value'];
    }
  });*/

  /*markers.add(Marker(
    point: LatLng(lat, lon),
    width: 40,
    height: 40,
    child: FlutterLogo(),
  ));*/

  var tm = TrackerManager(queryService);
  tm.addTrackers();

  //client.close();
}

List<Marker> _markers = [];
MapController mapController = MapController();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.limeAccent),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'DIYODE'),
    );
  }
}

FlutterMap getMap() {
  return (FlutterMap(
    mapController: mapController,
    options: MapOptions(
        center: LatLng(52.1326, 5.2913),
        maxZoom: 20,
        minZoom: 2,
        interactionOptions: InteractionOptions(rotationThreshold: 50)),
    children: [
      TileLayer(
        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
        userAgentPackageName: 'com.example.app',
      ),
      MarkerLayer(markers: _markers),
    ],
  ));
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  double mapWidth = 0;
  double mapHeight = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Colors.limeAccent,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(
          widget.title,
          style: GoogleFonts.bebasNeue(),
          textScaleFactor: 2,
        ),
      ),
      body: SlidingUpPanel(
        color: Theme.of(context).colorScheme.inversePrimary,
        parallaxEnabled: true,
        parallaxOffset: 0.5,
        maxHeight: 500,
        minHeight: 115,
        panel: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
                child: Container(
                    color: Colors.limeAccent,
                    child: Padding(
                        padding: EdgeInsets.all(10.0),
                        child: Text("🎒   Liam's Backpack",
                            textScaleFactor: 2,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.merriweatherSans()))))
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.battery_3_bar, color: Colors.black, size: 35.0),
            Text("100%",
                textScaleFactor: 1.25,
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 50),
            Text(
              "Last Seen: 9:23pm",
              textScaleFactor: 1.25,
            ),
          ]),
        ]),
        body: Center(
            // Center is a layout widget. It takes a single child and positions it
            // in the middle of the parent.
            child: (getMap())),
      ),

      // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
