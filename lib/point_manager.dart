import 'dart:math';

import 'package:influxdb_client/api.dart';

class TrackerManager {
  //The query service for InfluxDB.
  late QueryService queryService;

  var trackers = <Tracker>[];

  //Update soon to be dynamic.
  int lastHoursFetched = 12;

  TrackerManager(this.queryService);

  Future<List<Tracker>> addTrackers() async {
    var fluxQuery = '''
    import "influxdata/influxdb/schema"
    schema.measurements(bucket: "tracker")
    ''';

    print("Querying Trackers...");
    var trackerList = await queryService.query(fluxQuery);
    print("Finished querying Trackers.");
    await trackerList.forEach((tracker) async {
      var tr = Tracker(tracker['_value'] as String);
      print("Found Tracker: ${tracker['_value']}");

      trackers.add(tr);
    });
    return trackers;
  }
}

class Tracker {
  var trackerPoints = <TrackerPoint>[];
  String trackerName = "";

  Tracker(this.trackerName);

  void addNewTrackerPoint(var point) {
    trackerPoints.add(point);
  }

  TrackerPoint getLastPoint() {
    return trackerPoints.last;
  }

  void safeSetTrackerPoint(var index, var value) {
    try {
      trackerPoints[index] = value;
    } catch (e) {
      var curLength = trackerPoints.length;
      trackerPoints.length = max(curLength, index + 1);
      trackerPoints[index] = value;
    }
  }

  Future<void> populatePoints(
      QueryService service, int lastHours, String trackerName) async {
    //Chill until we fetch our tracker name.
    //await Future.doWhile(() => trackerName == "");
    var fluxQuery = '''
      from(bucket: "tracker")
      |> range(start: -${lastHours}h)
      |> filter(fn: (r) => r["_measurement"] == "$trackerName")
      |> pivot(rowKey: ["_time"], columnKey: ["_field"], valueColumn: "_value")''';

    var foundPoints = await service.query(fluxQuery);
    await foundPoints.forEach((record) {
      TrackerPoint tp = TrackerPoint();
      tp.time = record["last_seen"];
      tp.address = record["address"];
      tp.lat = record["lat"];
      tp.lon = record["lon"];
      tp.alt = record["altitude"];
      tp.battery = record["battery"];
      trackerPoints.add(tp);
    });
    print(trackerPoints);
    trackerPoints.forEach((point) {
      print(
          "Tracker ${trackerName}: Address: ${point.address} (Lat: ${point.lat}, Lon: ${point.lon}), ${point.battery}% Battery, Time: ${point.time}");
    });

    print(fluxQuery);
    /*
    var foundPoints = await service.query(fluxQuery);
    var count = 0;
    var curTrackerPointIdx = -1;
    TrackerPoint curTrackerPoint = TrackerPoint();
    await foundPoints.forEach((record) {
      int tableIndex = record.tableIndex;
      print("Table Index: $tableIndex");
      if (curTrackerPointIdx != tableIndex) {
        //Add the old tracker point if we're on a new table index (and it's not the first one).
        if (curTrackerPoint.isEmpty() && curTrackerPointIdx != -1) {
          trackerPoints.add(curTrackerPoint);
        }
        //We're now reading data from a different tracker.
        curTrackerPointIdx = tableIndex;
        //Initialise a new tracker.
        curTrackerPoint = TrackerPoint();
      }
      print(
          'record: ${count++} ${record['_time']}: ${record['_field']} ${record['_value']}');
      if (record['_field'] == "lon") {
        //lon = record['_value'];
        curTrackerPoint.lon = record['_value'];
      }
      if (record['_field'] == "lat") {
        curTrackerPoint.lat = record['_value'];
      }
      if (record['_field'] == "address") {
        curTrackerPoint.address = record['_value'];
      }
      if (record['_field'] == "last_seen") {
        curTrackerPoint.time = record['_value'];
      }
    });*/
  }
}

class TrackerPoint {
  num lat = double.nan;
  num lon = double.nan;
  num alt = double.nan;
  num battery = double.nan;

  String address = "";
  num time = 0;

  //TrackerPoint(this.lat, this.lon, this.fullAddress, this.time);
  TrackerPoint();

  bool isEmpty() {
    return lat.isNaN && lon.isNaN;
  }
}
