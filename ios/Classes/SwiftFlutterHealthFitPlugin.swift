import Flutter
import UIKit
import HealthKit


@available(iOS 9.0, *)
public class SwiftFlutterHealthFitPlugin: NSObject, FlutterPlugin {
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_health_fit", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterHealthFitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "requestAuthorization"{
            HealthkitReader.sharedInstance.requestHealthAuthorization() { success in
                result(success)
            }
        }
        else if call.method == "isAuthorized" { // only checks if requested! no telling if authorized!
            if #available(iOS 12.0, *) {
                HealthkitReader.sharedInstance.getRequestStatusForAuthorization { (status: HKAuthorizationRequestStatus, error: Error?) in
                    switch status {
                    case .shouldRequest:
                        result(false)
                    case .unnecessary:
                        result(true)
                    case .unknown:
                        let error = error! as NSError
                        result(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
                    }
                }
            } else {
                // Fallback on earlier versions
                result(HealthkitReader.sharedInstance.hasRequestedHealthKit)
            }
        }
        else if call.method == "getActivity"{
            self.getActivity(call, result: result)
        }
        
        else if call.method == "getBasicHealthData" {
            self.getBasicHealthData(result: result)
        }
        
        else if call.method == "getStepsBySegment" {
            let myArgs = call.arguments as! [String: Int]
            let startMillis = myArgs["start"]!
            let endMillis = myArgs["end"]!
            let start = startMillis.toTimeInterval
            let end = endMillis.toTimeInterval
            let duration = myArgs["duration"]!
            let unitInt = myArgs["unit"]!
            let unit = TimeUnit(rawValue: unitInt)!
            self.getStepsBySegment(result: result, start: start, end: end, duration: duration, unit: unit)
        }
        
        else if call.method == "getTotalStepsInInterval" {
            let myArgs = call.arguments as! [String: Int]
            let startMillis = myArgs["start"]!
            let endMillis = myArgs["end"]!
            let start = startMillis.toTimeInterval
            let end = endMillis.toTimeInterval
            HealthkitReader.sharedInstance.getTotalStepsInInterval(start: start, end: end) { (steps: Int?, error: Error?) in
                if let steps = steps {
                    result(steps)
                } else {
                    let error = error! as NSError
                    print("[getStepsByDay] got error: \(error)")
                    result(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
                }
            }
        }
    }

    func getStepsBySegment(result: @escaping FlutterResult, start: TimeInterval, end: TimeInterval, duration: Int, unit: TimeUnit) {
        let healthStore = HKHealthStore()
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        
        var anchorComponents: DateComponents
        var interval = DateComponents()
        switch unit {
        case .days:
            anchorComponents = Calendar.current.dateComponents([.day, .month, .year], from: Date())
            anchorComponents.hour = 0
            interval.day = duration
        case .minutes:
            anchorComponents = Calendar.current.dateComponents([.day, .month, .year, .hour, .second], from: Date())
            interval.minute = duration
        }
        
        let anchorDate = Calendar.current.date(from: anchorComponents)!
        
        let query = HKStatisticsCollectionQuery(quantityType: stepsQuantityType,
                                                quantitySamplePredicate: nil,
                                                options: [.cumulativeSum],
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        query.initialResultsHandler = { _, results, error in
            var dic = [Int: Int]()
            guard let results = results else {
                let error = error! as NSError
                print("[getStepsBySegment] got error: \(error)")
                result(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
                return
            }

            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    let steps = sum.doubleValue(for: HKUnit.count())
                    print("Amount of steps: \(steps), since: \(statistics.startDate) until: \(statistics.endDate)")
                    
                    let timestamp = Int(statistics.startDate.timeIntervalSince1970 * 1000)

                    dic[timestamp] = Int(steps)
                    
                }
            }
            result(dic)
        }
        
        healthStore.execute(query)
    }

    func getBasicHealthData(result: @escaping FlutterResult){
        let dob = HealthkitReader.sharedInstance.getDOB()
        let gender = HealthkitReader.sharedInstance.getBioLogicalSex()
        HealthkitReader.sharedInstance.getLastWeightReading(){
            (aWeight:Double?) in
            HealthkitReader.sharedInstance.getLastHeightReading(){
                (aHeight:Double?) in
                var dic = Dictionary<String,Any>()
                if dob != nil {
                    dic["dob"] = dob!.description
                }
                if gender != nil {
                    dic["gender"] = gender!.asServerParam
                }
                
                if aWeight != nil {
                    dic["weight"] = aWeight!
                }
                
                if aHeight != nil {
                    dic["height"] = aHeight!
                }
                result(dic)
            }
        }
    }
    
    func getActivity(_ call: FlutterMethodCall, result: @escaping FlutterResult){
        guard let params = call.arguments as? Dictionary<String,String> else {
            result(nil)
            return
        }
        
        guard let metric = params["name"] else {
            result(nil)
            return
        }
        
        guard let units = params["units"] else {
            result(nil)
            return
        }
        
        
        var type: HKQuantityTypeIdentifier;
        switch metric {
        case "steps":
            type = HKQuantityTypeIdentifier.stepCount
        case "cycling":
            type = HKQuantityTypeIdentifier.distanceCycling
        case "walkRun":
            type = HKQuantityTypeIdentifier.distanceWalkingRunning
        case "flights":
            type = HKQuantityTypeIdentifier.flightsClimbed
        case "heartRate":
            type = HKQuantityTypeIdentifier.heartRate
        default:
            result(["errorCode": "4040", "error": "unsupported type"])
            return;
        }
        
        HealthkitReader.sharedInstance.requestHealthAuthorization() { success in
            HealthkitReader.sharedInstance.getHealthDataValue(type: type, strUnitType: units) { results in
                if let data = results {
                    var value: Double = 0
                    if data.count > 0
                    {
                        for result in data
                        {
                            value += Double(result["value"]as! String)!
                        }
                        let dic:Dictionary<String, Any> = ["name": metric, "value": value, "units": units]
                        result(dic)
                        return
                    }
                }
                result([])
            }
        }
        
    }
    
    
}

extension Int {
    var toTimeInterval: TimeInterval {
        return TimeInterval(self) / 1000.0
    }
}

extension Date {
    var yesterday: Date {
        return Calendar.current.date(byAdding: .day, value: -1, to: startDay)!
    }
    
    var startDay: Date {
        return Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: self)!
    }
}
private extension Double {
    func toString() -> String {
        return String(format: "%.1f",self)
    }
}
