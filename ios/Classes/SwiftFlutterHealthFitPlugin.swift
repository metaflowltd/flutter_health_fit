import Flutter
import UIKit
import HealthKit


@available(iOS 9.0, *)
public class SwiftFlutterHealthFitPlugin: NSObject, FlutterPlugin {
    
    private let methodNamesToQuantityTypes: [String: HKQuantityType] = [
        "getEnergyConsumed": HealthkitReader.sharedInstance.dietaryEnergyConsumed,
        "getSugarConsumed": HealthkitReader.sharedInstance.dietarySugar,
        "getCarbsConsumed": HealthkitReader.sharedInstance.dietaryCarbohydrates,
        "getFatConsumed": HealthkitReader.sharedInstance.dietaryFatTotal,
        "getFiberConsumed": HealthkitReader.sharedInstance.dietaryFiber,
        "getProteinConsumed": HealthkitReader.sharedInstance.dietaryProtein,
    ]
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_health_fit", binaryMessenger: registrar.messenger())
        let instance = SwiftFlutterHealthFitPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "requestAuthorization":
            HealthkitReader.sharedInstance.requestHealthAuthorization() { success in
                result(success)
            }
        
        case "isAuthorized":  // only checks if requested! no telling if authorized!
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
                result(HealthkitReader.sharedInstance.hasRequestedHealthKitInThisRun)
            }
        
        case "getActivity":
            self.getActivity(call, result: result)
        
        
        case "getBasicHealthData":
            self.getBasicHealthData(result: result)
        
        
        case "getStepsBySegment":
            getQuantityBySegment(quantityType: HealthkitReader.sharedInstance.stepsQuantityType, call: call, convertToInt: true, result: result)
        
        
        case "getSleepBySegment":
            getSleepSamples(call: call, result: result)
        
        
        case "getFlightsBySegment":
            getQuantityBySegment(quantityType: HealthkitReader.sharedInstance.flightsClimbedQuantityType, call: call, convertToInt: true, result: result)
        
            
        case "getCyclingDistanceBySegment":
            getQuantityBySegment(quantityType: HealthkitReader.sharedInstance.cyclingDistanceQuantityType, call: call, result: result)
        
            
        case "getWeightInInterval":
            let myArgs = call.arguments as! [String: Int]
            let startMillis = myArgs["start"]!
            let endMillis = myArgs["end"]!
            let start = startMillis.toTimeInterval
            let end = endMillis.toTimeInterval
            HealthkitReader.sharedInstance.getWeight(start: start, end: end) { (weight: [Int:Double]?, error: Error?) in
                if let error = error as NSError?{
                    print("[getWeight] got error: \(error)")
                    result(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
                } else {
                    result(weight)
                }
            }
        
        
        case "getHeartRateSample":
            let myArgs = call.arguments as! [String: Int]
            let startMillis = myArgs["start"]!
            let endMillis = myArgs["end"]!
            let start = startMillis.toTimeInterval
            let end = endMillis.toTimeInterval
            HealthkitReader.sharedInstance.getHeartRateSample(start: start, end: end) { (rate: [String: Any]?, error: Error?) in
                if let error = error as NSError? {
                   print("[getHeartRateSample] got error: \(error)")
                   result(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
                } else {
                   result(rate)
                }
            }
        
            
        case "getAverageWalkingHeartRate":
            fallthrough
        case "getAverageRestingHeartRate":
            let myArgs = call.arguments as! [String: Int]
            let startMillis = myArgs["start"]!
            let endMillis = myArgs["end"]!
            let start = startMillis.toTimeInterval
            let end = endMillis.toTimeInterval
            guard #available(iOS 11.0, *) else {
                result(nil)
                return
            }
            let sampleType = call.method == "getAverageWalkingHeartRate" ? HealthkitReader.sharedInstance.walkingHeartRateAverageQuantityType : HealthkitReader.sharedInstance.restingHeartRateQuantityType
            HealthkitReader.sharedInstance.getAverageQuantity(sampleType: sampleType,
                                                              unit: HKUnit.count().unitDivided(by: HKUnit.minute()),
                                                              start: start, end: end) { (rates: [[String : Any]]?, error: Error?) in
                if let error = error as NSError? {
                    print("[\(call.method)] got error: \(error)")
                    result(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
                } else {
                    result(rates)
                }
            }
            
        case "getTotalStepsInInterval":
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
        
        case "getEnergyConsumed":
            fallthrough
        case "getFiberConsumed":
            fallthrough
        case "getSugarConsumed":
            fallthrough
        case "getCarbsConsumed":
            fallthrough
        case "getFatConsumed":
            fallthrough
        case "getProteinConsumed":
            getNutritionSampleInInterval(call: call, result: result)
        
        
        case "getStepsSources":
            HealthkitReader.sharedInstance.getStepsSources { (steps: Array<String>) in
                result(steps)
            }

        case "isAnyPermissionAuthorized":
            // Not supposed to be invoked on iOS. Returns a fake result.
            result(HealthkitReader.sharedInstance.hasRequestedHealthKitInThisRun)

        case "isStepsAuthorized":
            getRequestStatus(types: [HealthkitReader.sharedInstance.stepsQuantityType], result: result)
            
        case "isCyclingAuthorized":
            getRequestStatus(types: [HealthkitReader.sharedInstance.cyclingDistanceQuantityType], result: result)
            
        case "isFlightsAuthorized":
            getRequestStatus(types: [HealthkitReader.sharedInstance.flightsClimbedQuantityType], result: result)
            
        case "isSleepAuthorized":
            getRequestStatus(types: [HealthkitReader.sharedInstance.sleepCategoryType], result: result)
            
        case "isWeightAuthorized":
            getRequestStatus(types: [HealthkitReader.weightQuantityType()], result: result)
            
        case "isHeartRateAuthorized":
            let reader = HealthkitReader.sharedInstance
            var types = [reader.heartRateQuantityType]
            if #available(iOS 11.0, *) {
                types.append(contentsOf: [
                                reader.heartRateVariabilityQuantityType,
                                reader.restingHeartRateQuantityType,
                                reader.walkingHeartRateAverageQuantityType,
                ])
            }
            getRequestStatus(types: types, result: result)
            
        case "isCarbsAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.dietaryCarbohydrates, reader.dietaryFiber], result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    func getRequestStatus(types: [HKObjectType], result: @escaping FlutterResult) {
        if #available(iOS 12.0, *){
            HealthkitReader.sharedInstance.getRequestStatus(for: Set(types)) { status, error in
                if let error = error {
                    result(FlutterError(code: "\((error as NSError).code)", message: error.localizedDescription, details: nil))
                } else {
                    result(status == .unnecessary)
                }
            }
        } else {
            // Fallback on earlier versions
            result(HealthkitReader.sharedInstance.hasRequestedHealthKitInThisRun)
        }
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
    
    private func getSleepSamples(call: FlutterMethodCall,
                                 result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Int]
        let startMillis = args["start"]!
        let endMillis = args["end"]!
        let start = startMillis.toTimeInterval
        let end = endMillis.toTimeInterval
    
        HealthkitReader.sharedInstance.getSleepSamplesForRange(start: start,
                                                               end: end,
                                                               handler: { samples, error in
                                                                
                                                                    if let samples = samples {
                                                                        result(samples)
                                                                    } else {
                                                                        let error = error! as NSError
                                                                        print("[\(#function)] got error: \(error)")
                                                                        result(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
                                                                    }
                                                                
                                                               })
    }

    private func getQuantityBySegment(quantityType: HKQuantityType, call: FlutterMethodCall, convertToInt: Bool = false, result: @escaping FlutterResult) {
        let args = QuantityArgs(arguments: call.arguments!)
        HealthkitReader.sharedInstance.getQuantityBySegment(quantityType: quantityType, start: args.start, end: args.end, duration: args.duration, unit: args.unit) { (quantityByStartTime: [Int: Double]?, error: Error?) -> () in
            if let quantityByStartTime = quantityByStartTime {
                if convertToInt {
                    result(quantityByStartTime.mapValues({ Int($0) }))
                } else {
                    result(quantityByStartTime)
                }
                
                return
            }
            let error = error! as NSError
            print("[\(#function)] got error: \(error)")
            result(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
        }
    }
    
    private func getNutritionSampleInInterval(call: FlutterMethodCall,
                                              result: @escaping FlutterResult) {
        let myArgs = call.arguments as! [String: Int]
        let startMillis = myArgs["start"]!
        let endMillis = myArgs["end"]!
        let start = startMillis.toTimeInterval
        let end = endMillis.toTimeInterval
        let methodName = call.method
        HealthkitReader.sharedInstance.getSampleConsumedInInterval(sampleType: methodNamesToQuantityTypes[methodName]!,
                                                                   unit: getUnitsBy(methodName: call.method),
                                                                   start: start,
                                                                   end: end) { (value: [String : Int]?, error: Error?) in
            if let error = error {
                let error = error as NSError
                if error.code == 11 {
                    print("[\(methodName)] no data was found for a given dates range: \(error)")
                    result(nil)
                } else {
                    print("[\(methodName)] got error: \(error)")
                    result(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
                }
            } else {
                result(value)
            }
        }
    }
    
    private func getUnitsBy(methodName: String) -> HKUnit {
        if methodName == "getEnergyConsumed" {
            return HKUnit.kilocalorie()
        } else {
            return HKUnit.gram()
        }
    }
}

class QuantityArgs {
    let start, end: TimeInterval
    let duration: Int
    let unit: TimeUnit
    
    init(arguments: Any) {
        let args = arguments as! [String: Int]
        let startMillis = args["start"]!
        let endMillis = args["end"]!
        start = startMillis.toTimeInterval
        end = endMillis.toTimeInterval
        duration = args["duration"]!
        let unitInt = args["unit"]!
        unit = TimeUnit(rawValue: unitInt)!
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
