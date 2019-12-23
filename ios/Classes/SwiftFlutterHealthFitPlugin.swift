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
        if call.method == "getActivity"{
            self.getActivity(call, result: result)
        }
        
        if call.method == "getBasicHealthData" {
            self.getBasicHealthData(result: result)
        }
        
        if call.method == "startDateInDays" {
            self.getStepsBeforeDays(result: result, startDateInDays: 7)
        }
    }
    
    func makeNumberNegative(number: Int) -> Int {
        return number > 0 ? (0 - number) : number
    }
    
    func getStepsBeforeDays(result: @escaping FlutterResult, startDateInDays: Int) {
        let healthStore = HKHealthStore()
        let stepsQuantityType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        
        let startDateInDays = makeNumberNegative(number: startDateInDays)
        
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        
        var interval = DateComponents()
        interval.day = 1
        
        var anchorComponents = Calendar.current.dateComponents([.day, .month, .year], from: now)
        anchorComponents.hour = 0
        let anchorDate = Calendar.current.date(from: anchorComponents)!
        
        let query = HKStatisticsCollectionQuery(quantityType: stepsQuantityType,
                                                quantitySamplePredicate: nil,
                                                options: [.cumulativeSum],
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        query.initialResultsHandler = { _, results, error in
            guard let results = results else {
                NSLog("error", "Error returned")
                return
            }
            var dic = [String: Int]()
            results.enumerateStatistics(from: startDate, to: now) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    let steps = sum.doubleValue(for: HKUnit.count())
                    print("Amount of steps: \(steps), date: \(statistics.startDate)")
                    
                    dic[steps.toString()] = Int(statistics.startDate.timeIntervalSince1970 * 1000)
                    
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
