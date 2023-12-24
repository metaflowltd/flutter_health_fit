import 'dart:io';

import 'package:flutter_health_fit/flutter_health_fit.dart';

class WorkoutSample {
  final String id;
  final WorkoutSampleType type;
  final DateTime start;
  final DateTime end;
  final int duration;
  final int? steps;
  final double? energy; // kilo-Calories
  final double? distance; // meters
  final String source;

  WorkoutSample({
    required this.id,
    required this.type,
    required this.start,
    required this.end,
    required this.duration,
    required this.steps,
    required this.energy,
    required this.distance,
    required this.source,
  });

  @override
  String toString() {
    return 'WorkoutSample{id: $id, '
        'type: $type, '
        'start: $start, '
        'end: $end, '
        'duration: $duration, '
        'energy: $energy, '
        'distance: $distance, '
        'source: $source, '
        'steps: $steps}';
  }

  WorkoutSample.fromMap(Map<String, dynamic> map)
      : id = map["id"].toString(),
        type = _typeFromPlatformValue(map["type"]),
        start = DateTime.fromMillisecondsSinceEpoch(map["start"]),
        end = DateTime.fromMillisecondsSinceEpoch(map["end"]),
        duration = calcDuration(map),
        energy = map["energy"],
        distance = map["distance"],
        steps = map["steps"],
        source = map["source"];

  static int calcDuration(Map<String, dynamic> map) {
    final duration = map["duration"];
    // we expect duration to be a number so both int and double are valid
    if (duration is int) {
      return duration;
    } else if (duration is double) {
      return duration.round();
    }

    return DateTime.fromMillisecondsSinceEpoch(map["end"])
        .difference(DateTime.fromMillisecondsSinceEpoch(map["start"]))
        .inMinutes;
  }

  static WorkoutSampleType _typeFromPlatformValue(dynamic input) {
    if (Platform.isAndroid) {
      // On Android the workout type type is different for workout samples and sessions:
      // for workouts - int
      // for sessions - String
      if (input is int) {
        return _androidTypeFromInt(input);
      } else {
        return _androidTypeFromString(input);
      }
    } else {
      // ios
      return _iosTypeFromInt(input.toInt());
    }
  }

  static WorkoutSampleType _iosTypeFromInt(int input) {
    switch (input) {
      case 1:
        return WorkoutSampleType.americanFootball;
      case 2:
        return WorkoutSampleType.archery;
      case 3:
        return WorkoutSampleType.australianFootball;
      case 4:
        return WorkoutSampleType.badminton;
      case 5:
        return WorkoutSampleType.baseball;
      case 6:
        return WorkoutSampleType.basketball;
      case 7:
        return WorkoutSampleType.bowling;
      case 8:
        return WorkoutSampleType.boxing;
      case 9:
        return WorkoutSampleType.climbing;
      case 10:
        return WorkoutSampleType.cricket;
      case 11:
        return WorkoutSampleType.crossTraining;
      case 12:
        return WorkoutSampleType.curling;
      case 13:
        return WorkoutSampleType.cycling;
      case 14:
        return WorkoutSampleType.dance;
      case 15:
        return WorkoutSampleType.danceInspiredTraining;
      case 16:
        return WorkoutSampleType.elliptical;
      case 17:
        return WorkoutSampleType.equestrianSports;
      case 18:
        return WorkoutSampleType.fencing;
      case 19:
        return WorkoutSampleType.fishing;
      case 20:
        return WorkoutSampleType.functionalStrengthTraining;
      case 21:
        return WorkoutSampleType.golf;
      case 22:
        return WorkoutSampleType.gymnastics;
      case 23:
        return WorkoutSampleType.handball;
      case 24:
        return WorkoutSampleType.hiking;
      case 25:
        return WorkoutSampleType.hockey;
      case 26:
        return WorkoutSampleType.hunting;
      case 27:
        return WorkoutSampleType.lacrosse;
      case 28:
        return WorkoutSampleType.martialArts;
      case 29:
        return WorkoutSampleType.mindAndBody;
      case 30:
        return WorkoutSampleType.mixedMetabolicCardioTraining;
      case 31:
        return WorkoutSampleType.paddleSports;
      case 32:
        return WorkoutSampleType.play;
      case 33:
        return WorkoutSampleType.preparationAndRecovery;
      case 34:
        return WorkoutSampleType.racquetball;
      case 35:
        return WorkoutSampleType.rowing;
      case 36:
        return WorkoutSampleType.rugby;
      case 37:
        return WorkoutSampleType.running;
      case 38:
        return WorkoutSampleType.sailing;
      case 39:
        return WorkoutSampleType.skatingSports;
      case 40:
        return WorkoutSampleType.snowSports;
      case 41:
        return WorkoutSampleType.soccer;
      case 42:
        return WorkoutSampleType.softball;
      case 43:
        return WorkoutSampleType.squash;
      case 44:
        return WorkoutSampleType.stairClimbing;
      case 45:
        return WorkoutSampleType.surfingSports;
      case 46:
        return WorkoutSampleType.swimming;
      case 47:
        return WorkoutSampleType.tableTennis;
      case 48:
        return WorkoutSampleType.tennis;
      case 49:
        return WorkoutSampleType.trackAndField;
      case 50:
        return WorkoutSampleType.traditionalStrengthTraining;
      case 51:
        return WorkoutSampleType.volleyball;
      case 52:
        return WorkoutSampleType.walking;
      case 53:
        return WorkoutSampleType.waterFitness;
      case 54:
        return WorkoutSampleType.waterPolo;
      case 55:
        return WorkoutSampleType.waterSports;
      case 56:
        return WorkoutSampleType.wrestling;
      case 57:
        return WorkoutSampleType.yoga;
      case 58:
        return WorkoutSampleType.barre;
      case 59:
        return WorkoutSampleType.coreTraining;
      case 60:
        return WorkoutSampleType.crossCountrySkiing;
      case 61:
        return WorkoutSampleType.downhillSkiing;
      case 62:
        return WorkoutSampleType.flexibility;
      case 63:
        return WorkoutSampleType.highIntensityIntervalTraining;
      case 64:
        return WorkoutSampleType.jumpRope;
      case 65:
        return WorkoutSampleType.kickboxing;
      case 66:
        return WorkoutSampleType.pilates;
      case 67:
        return WorkoutSampleType.snowboarding;
      case 68:
        return WorkoutSampleType.stairs;
      case 69:
        return WorkoutSampleType.stepTraining;
      case 70:
        return WorkoutSampleType.wheelchairWalkPace;
      case 71:
        return WorkoutSampleType.wheelchairRunPace;
      case 72:
        return WorkoutSampleType.taiChi;
      case 73:
        return WorkoutSampleType.mixedCardio;
      case 74:
        return WorkoutSampleType.handCycling;
      case 75:
        return WorkoutSampleType.discSports;
      case 76:
        return WorkoutSampleType.fitnessGaming;
      case 77:
        return WorkoutSampleType.cardioDance;
      case 78:
        return WorkoutSampleType.socialDance;
      case 79:
        return WorkoutSampleType.pickleball;
      case 80:
        return WorkoutSampleType.cooldown;
      case 3000:
        return WorkoutSampleType.other;
      default:
        print("ERROR unable to detect workout type");
        return WorkoutSampleType.other;
    }
  }

  static WorkoutSampleType _androidTypeFromString(String input) {
    // values are mapped according to FitnessActivities
    // https://developers.google.com/android/reference/com/google/android/gms/fitness/FitnessActivities
    switch (input) {
      case "walking":
        return WorkoutSampleType.walking;
      case "aerobics":
        return WorkoutSampleType.aerobics;
      case "archery":
        return WorkoutSampleType.archery;
      case "baseball":
        return WorkoutSampleType.baseball;
      case "basketball":
        return WorkoutSampleType.basketball;
      case "biathlon":
        return WorkoutSampleType.biathlon;
      case "biking":
      case "biking.hand":
      case "biking.mountain":
      case "biking.road":
      case "biking.spinning":
      case "biking.stationary":
      case "biking.utility":
        return WorkoutSampleType.cycling;
      case "boxing":
        return WorkoutSampleType.boxing;
      case "calisthenics":
        return WorkoutSampleType.calisthenics;
      case "circuit_training":
        return WorkoutSampleType.circuitTraining;
      case "cricket":
        return WorkoutSampleType.cricket;
      case "crossfit":
        return WorkoutSampleType.crossTraining;
      case "curling":
        return WorkoutSampleType.curling;
      case "dancing":
        return WorkoutSampleType.dance;
      case "diving":
        return WorkoutSampleType.diving;
      case "elevator":
        return WorkoutSampleType.elevator;
      case "elliptical":
        return WorkoutSampleType.elliptical;
      case "ergometer":
        return WorkoutSampleType.ergometer;
      case "escalator":
        return WorkoutSampleType.escalator;
      case "fencing":
        return WorkoutSampleType.fencing;
      case "football.american":
        return WorkoutSampleType.americanFootball;
      case "football.australian":
        return WorkoutSampleType.australianFootball;
      case "football.soccer":
        return WorkoutSampleType.soccer;
      case "frisbee_disc":
        return WorkoutSampleType.frisbee;
      case "gardening":
        return WorkoutSampleType.gardening;
      case "golf":
        return WorkoutSampleType.golf;
      case "guided_breathing":
        return WorkoutSampleType.guidedBreathing;
      case "gymnastics":
        return WorkoutSampleType.gymnastics;
      case "handball":
        return WorkoutSampleType.handball;
      case "interval_training":
      case "interval_training.high_intensity":
        return WorkoutSampleType.intervalTraining;
      case "hiking":
        return WorkoutSampleType.hiking;
      case "hockey":
        return WorkoutSampleType.hockey;
      case "horseback_riding":
        return WorkoutSampleType.horsebackRiding;
      case "housework":
        return WorkoutSampleType.housework;
      case "ice_skating":
        return WorkoutSampleType.iceSkating;
      case "jump_rope":
        return WorkoutSampleType.jumpRope;
      case "kayaking":
        return WorkoutSampleType.kayaking;
      case "kettlebell_training":
        return WorkoutSampleType.kettlebellTraining;
      case "kickboxing":
        return WorkoutSampleType.kickboxing;
      case "kitesurfing":
        return WorkoutSampleType.kitesurfing;
      case "martial_arts":
      case "martial_arts.mixed":
        return WorkoutSampleType.martialArts;
      case "meditation":
        return WorkoutSampleType.meditation;
      case "paragliding":
        return WorkoutSampleType.paragliding;
      case "pilates":
        return WorkoutSampleType.pilates;
      case "polo":
        return WorkoutSampleType.polo;
      case "racquetball":
        return WorkoutSampleType.racquetball;
      case "rock_climbing":
        return WorkoutSampleType.climbing;
      case "rowing":
      case "rowing.machine":
        return WorkoutSampleType.rowing;
      case "rugby":
        return WorkoutSampleType.rugby;
      case "running":
      case "running.jogging":
      case "running.sand":
      case "running.treadmill":
        return WorkoutSampleType.running;
      case "sailing":
        return WorkoutSampleType.sailing;
      case "scuba_diving":
        return WorkoutSampleType.diving;
      case "skateboarding":
        return WorkoutSampleType.skatingSports;
      case "skating":
      case "skating.cross":
      case "skating.indoor":
      case "skating.inline":
        return WorkoutSampleType.skatingSports;
      case "skiing":
      case "skiing.back_country":
      case "skiing.kite":
      case "skiing.roller":
        return WorkoutSampleType.skiing;
      case "skiing.cross_country":
        return WorkoutSampleType.crossCountrySkiing;
      case "skiing.downhill":
        return WorkoutSampleType.downhillSkiing;
      case "sledding":
      case "snowmobile":
      case "snowshoeing":
        return WorkoutSampleType.snowSports;
      case "snowboarding":
        return WorkoutSampleType.snowboarding;
      case "softball":
        return WorkoutSampleType.softball;
      case "squash":
        return WorkoutSampleType.squash;
      case "stair_climbing":
      case "stair_climbing.machine":
        return WorkoutSampleType.stairClimbing;
      case "standup_paddleboarding":
        return WorkoutSampleType.paddleSports;
      case "surfing":
        return WorkoutSampleType.surfingSports;
      case "swimming":
      case "swimming.pool":
      case "swimming.open_water":
        return WorkoutSampleType.swimming;
      case "table_tennis":
        return WorkoutSampleType.tableTennis;
      case "tennis":
        return WorkoutSampleType.tennis;
      case "treadmill":
        return WorkoutSampleType.walking;
      case "volleyball":
      case "volleyball.beach":
      case "volleyball.indoor":
        return WorkoutSampleType.volleyball;
      case "walking":
      case "walking.fitness":
      case "walking.nordic":
      case "walking.treadmill":
      case "walking.stroller":
        return WorkoutSampleType.walking;
      case "water_polo":
        return WorkoutSampleType.polo;
      case "weightlifting":
        return WorkoutSampleType.weightlifting;
      case "wheelchair":
        return WorkoutSampleType.wheelchairRunPace;
      case "windsurfing":
        return WorkoutSampleType.surfingSports;
      case "yoga":
        return WorkoutSampleType.yoga;
      case "zumba":
        return WorkoutSampleType.zumba;
      default:
        return WorkoutSampleType.other;
    }
  }

  static WorkoutSampleType _androidTypeFromInt(int input) {
    // we got the list from https://developers.google.com/fit/rest/v1/reference/activity-types
    switch (input) {
      case 9:
        return WorkoutSampleType.aerobics;
      case 119:
        return WorkoutSampleType.archery;
      case 10:
        return WorkoutSampleType.badminton;
      case 11:
        return WorkoutSampleType.baseball;
      case 12:
        return WorkoutSampleType.basketball;
      case 13:
        return WorkoutSampleType.biathlon;
      case 1:
        return WorkoutSampleType.cycling;
      case 14:
        return WorkoutSampleType.handCycling;
      case 15:
        return WorkoutSampleType.mountainCycling;
      case 16:
        return WorkoutSampleType.roadCycling;
      case 17:
        return WorkoutSampleType.spinning;
      case 18:
        return WorkoutSampleType.stationaryCycling;
      case 19:
        return WorkoutSampleType.utilityCycling;
      case 20:
        return WorkoutSampleType.boxing;
      case 21:
        return WorkoutSampleType.calisthenics;
      case 22:
        return WorkoutSampleType.circuitTraining;
      case 23:
        return WorkoutSampleType.cricket;
      case 113:
        return WorkoutSampleType.crossTraining;
      case 106:
        return WorkoutSampleType.curling;
      case 24:
        return WorkoutSampleType.dance;
      case 102:
        return WorkoutSampleType.diving;
      case 117:
        return WorkoutSampleType.elevator;
      case 25:
        return WorkoutSampleType.elliptical;
      case 103:
        return WorkoutSampleType.ergometer;
      case 118:
        return WorkoutSampleType.escalator;
      case 26:
        return WorkoutSampleType.fencing;
      case 27:
        return WorkoutSampleType.americanFootball;
      case 28:
        return WorkoutSampleType.australianFootball;
      case 29:
        return WorkoutSampleType.soccer;
      case 30:
        return WorkoutSampleType.frisbee;
      case 31:
        return WorkoutSampleType.gardening;
      case 32:
        return WorkoutSampleType.golf;
      case 122:
        return WorkoutSampleType.guidedBreathing;
      case 33:
        return WorkoutSampleType.gymnastics;
      case 34:
        return WorkoutSampleType.handball;
      case 114:
        return WorkoutSampleType.highIntensityIntervalTraining;
      case 35:
        return WorkoutSampleType.hiking;
      case 36:
        return WorkoutSampleType.hockey;
      case 37:
        return WorkoutSampleType.horsebackRiding;
      case 38:
        return WorkoutSampleType.housework;
      case 38:
        return WorkoutSampleType.iceSkating;
      case 115:
        return WorkoutSampleType.intervalTraining;
      case 39:
        return WorkoutSampleType.jumpingRope;
      case 40:
        return WorkoutSampleType.kayaking;
      case 41:
        return WorkoutSampleType.kettlebellTraining;
      case 42:
        return WorkoutSampleType.kickboxing;
      case 43:
        return WorkoutSampleType.kitesurfing;
      case 44:
        return WorkoutSampleType.martialArts;
      case 45:
        return WorkoutSampleType.meditation;
      case 46:
        return WorkoutSampleType.martialArts;
      case 108:
        return WorkoutSampleType.other;
      case 48:
        return WorkoutSampleType.paragliding;
      case 49:
        return WorkoutSampleType.pilates;
      case 50:
        return WorkoutSampleType.polo;
      case 51:
        return WorkoutSampleType.racquetball;
      case 52:
        return WorkoutSampleType.climbing;
      case 53:
        return WorkoutSampleType.rowing;
      case 54:
        return WorkoutSampleType.other;
      case 55:
        return WorkoutSampleType.rugby;
      case 8:
        return WorkoutSampleType.running;
      case 56:
        return WorkoutSampleType.running;
      case 57:
        return WorkoutSampleType.running;
      case 58:
        return WorkoutSampleType.running;
      case 59:
        return WorkoutSampleType.sailing;
      case 60:
        return WorkoutSampleType.diving;
      case 61:
        return WorkoutSampleType.skatingSports;
      case 62:
        return WorkoutSampleType.skatingSports;
      case 63:
        return WorkoutSampleType.skatingSports;
      case 105:
        return WorkoutSampleType.skatingSports;
      case 64:
        return WorkoutSampleType.skatingSports;
      case 65:
        return WorkoutSampleType.skiing;
      case 66:
        return WorkoutSampleType.skiing;
      case 67:
        return WorkoutSampleType.crossCountrySkiing;
      case 68:
        return WorkoutSampleType.downhillSkiing;
      case 69:
        return WorkoutSampleType.skiing;
      case 70:
        return WorkoutSampleType.skiing;
      case 71:
        return WorkoutSampleType.snowSports;
      case 73:
        return WorkoutSampleType.snowboarding;
      case 74:
        return WorkoutSampleType.snowSports;
      case 75:
        return WorkoutSampleType.snowSports;
      case 120:
        return WorkoutSampleType.softball;
      case 76:
        return WorkoutSampleType.squash;
      case 77:
        return WorkoutSampleType.stairClimbing;
      case 78:
        return WorkoutSampleType.stairClimbing;
      case 79:
        return WorkoutSampleType.paddleSports;
      case 3:
        return WorkoutSampleType.other;
      case 80:
        return WorkoutSampleType.other;
      case 81:
        return WorkoutSampleType.surfingSports;
      case 82:
        return WorkoutSampleType.swimming;
      case 84:
        return WorkoutSampleType.swimming;
      case 83:
        return WorkoutSampleType.swimming;
      case 85:
        return WorkoutSampleType.tableTennis;
      case 85:
        return WorkoutSampleType.other;
      case 86:
        return WorkoutSampleType.other;
      case 87:
        return WorkoutSampleType.tennis;
      case 5:
        return WorkoutSampleType.other;
      case 88:
        return WorkoutSampleType.walking;
      case 4:
        return WorkoutSampleType.other;
      case 89:
        return WorkoutSampleType.volleyball;
      case 90:
        return WorkoutSampleType.volleyball;
      case 91:
        return WorkoutSampleType.volleyball;
      case 92:
        return WorkoutSampleType.other;
      case 7:
        return WorkoutSampleType.walking;
      case 93:
        return WorkoutSampleType.walking;
      case 94:
        return WorkoutSampleType.walking;
      case 95:
        return WorkoutSampleType.walking;
      case 116:
        return WorkoutSampleType.walking;
      case 96:
        return WorkoutSampleType.waterPolo;
      case 97:
        return WorkoutSampleType.weightlifting;
      case 98:
        return WorkoutSampleType.wheelchairRunPace;
      case 99:
        return WorkoutSampleType.other;
      case 100:
        return WorkoutSampleType.yoga;
      case 101:
        return WorkoutSampleType.zumba;
      default:
        return WorkoutSampleType.other;
    }
  }
}
