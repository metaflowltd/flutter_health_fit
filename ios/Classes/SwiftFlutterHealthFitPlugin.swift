import Flutter
import UIKit
import HealthKit


@available(iOS 9.0, *)
public class SwiftFlutterHealthFitPlugin: NSObject, FlutterPlugin {
    private var workoutsObserver: WorkoutsObserver? = nil
    private var workoutsChannel: FlutterEventChannel? = nil
    
    private enum OutputType{
        case oneValue
        case valueMap
        case detailedMap
        
        func detailedOutput() -> Bool {
            switch self {
            case .oneValue:
                return false
            case .valueMap:
                return false
            case .detailedMap:
                return true
            }
        }

        func outputLimit() -> Int {
            switch self {
            case .oneValue:
                return 1
            case .valueMap:
                return HKObjectQueryNoLimit
            case .detailedMap:
                return HKObjectQueryNoLimit
            }
        }
    }
    
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
        let workoutsChannel = FlutterEventChannel(name: "flutter_health_fit/workouts", binaryMessenger: registrar.messenger())

        let instance = SwiftFlutterHealthFitPlugin()
        let workoutsObserver = WorkoutsObserver()
        instance.workoutsObserver = workoutsObserver
        instance.workoutsChannel = workoutsChannel
        registrar.addMethodCallDelegate(instance, channel: channel)
        workoutsChannel.setStreamHandler(workoutsObserver)
        registrar.publish(instance)
    }

    public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
        NSLog("SwiftFlutterHealthFitPlugin: Detach from engine!")
        if let workoutsObserver = workoutsObserver {
            workoutsObserver.onDetach()
        }
        if let workoutsChannel = workoutsChannel {
            workoutsChannel.setStreamHandler(nil)
        }
     }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard HKHealthStore.isHealthDataAvailable() else {
            result(FlutterError(code: "healthkit not available", message: "healthkit not available on this device", details:""))
            return
        }

    switch call.method {
        case "requestAuthorization":
            HealthkitReader.sharedInstance.requestHealthAuthorization() { success in
                result(success)
            }
            
        case "isAuthorized":  // only checks if requested! no telling if authorized!
            if #available(iOS 12.0, *) {
                HealthkitReader.sharedInstance.getRequestStatusForAuthorization { [weak self] (status: HKAuthorizationRequestStatus, error: Error?) in
                    switch status {
                    case .shouldRequest:
                        result(false)
                    case .unnecessary:
                        result(true)
                    case .unknown:
                        if let error = error {
                            result(self?.createReportError(error: error))
                            return
                        }
                        result(FlutterError(code: "Authorization", message: "missing error details", details: call.method))
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
            getUserActivity(call: call, quantityType:HealthkitReader.sharedInstance.stepsQuantityType, result: result)
        
        case "getSleepBySegment":
            getSleepSamples(call: call, result: result)

        case "getRawSleepDataInRange":
            getRawSleepDataInRange(call: call, result: result)

        case "getFlightsBySegment":
            getUserActivity(call: call, quantityType:HealthkitReader.sharedInstance.flightsClimbedQuantityType, result: result)
            
        case "getCyclingDistanceBySegment":
            getUserActivity(call: call, quantityType:HealthkitReader.sharedInstance.cyclingDistanceQuantityType, result: result)

        case "getWaistSizeBySegment":
            guard let args = call.arguments as? [String: Any],
                  let startMillis = args["start"] as? Int,
                  let endMillis = args["end"] as? Int else {
                      result(FlutterError(code: "Missing args", message: "missing start and end params", details: call.method))
                      return
                  }
            HealthkitReader.sharedInstance.getQuantity(quantityType: HealthkitReader.sharedInstance.waistSizeQuantityType,
                                                       start: startMillis.toTimeInterval,
                                                       end: endMillis.toTimeInterval,
                                                       lmnUnit: lmnUnit(from: call, defalutUnit: LMNUnit.cm),
                                                       maxResults: 1) { [weak self] dataMap, error in
                if let error = error as NSError? {
                    result(self?.createReportError(error: error))
                    return
                }
                
                if let date = dataMap?.keys.first,
                   let detailedOutput = dataMap?[date]  {
                    let value = DataPointValue(dateInMillis: date,
                                               value: detailedOutput.value,
                                               units: .cm,
                                               sourceApp: detailedOutput.sourceApp,
                                               additionalInfo: nil)
                    result(value.resultMap())
                    return
                }
                
                result(nil)
            }
        
        case "getBodyFatPercentageBySegment":
            guard let args = call.arguments as? [String: Any],
                  let startMillis = args["start"] as? Int,
                  let endMillis = args["end"] as? Int else {
                      result(FlutterError(code: "Missing args", message: "missing start and end params", details: call.method))
                      return
                  }
            HealthkitReader.sharedInstance.getQuantity(quantityType: HealthkitReader.sharedInstance.bodyFatPercentageQuantityType,
                                                       start: startMillis.toTimeInterval,
                                                       end: endMillis.toTimeInterval,
                                                       lmnUnit: lmnUnit(from: call, defalutUnit: LMNUnit.percent),
                                                       maxResults: 1) { [weak self] dataMap, error in
                if let error = error as NSError? {
                    result(self?.createReportError(error: error))
                    return
                }
                
                if let date = dataMap?.keys.first,
                   let detailedOutput = dataMap?[date]  {
                    let value = DataPointValue(dateInMillis: date,
                                               value: detailedOutput.value * 100,
                                               units: .percent,
                                               sourceApp: detailedOutput.sourceApp,
                                               additionalInfo: nil)
                    result(value.resultMap())
                    return
                }
                
                result(nil)
            }
        
        case "getMenstrualDataBySegment":
            getCategoryBySegment(categoryType: HealthkitReader.sharedInstance.menstrualFlowCategoryType, call: call, result: result)
        
        case "getWeightInInterval":
            guard let myArgs = call.arguments as? [String: Int],
                  let startMillis = myArgs["start"],
                  let endMillis = myArgs["end"] else {
                      result(FlutterError(code: "Missing args", message: "missing start and end params", details:""))
                      return
                  }
            let start = startMillis.toTimeInterval
            let end = endMillis.toTimeInterval
            HealthkitReader.sharedInstance.getWeight(start: start, end: end) { [weak self] (weight: DataPointValue?, error: Error?) in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(weight?.resultMap())
            }
            
        case "getWorkoutsBySegment":
            let args = call.arguments as! [String: Int]
            let startMillis = args["start"]!.toTimeInterval
            let endMillis = args["end"]!.toTimeInterval
            
            HealthkitReader.sharedInstance.getWokoutsBySegment(start: startMillis, end: endMillis)  { [weak self] (workouts, error) in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(workouts)
            }
        case "getLatestHeartRate":
            let myArgs = call.arguments as! [String: Int]
            let startMillis = myArgs["start"]!
            let endMillis = myArgs["end"]!
            let start = startMillis.toTimeInterval
            let end = endMillis.toTimeInterval
            HealthkitReader.sharedInstance.getHeartRateSample(start: start, end: end) { [weak self] (rate: [String: Any]?, error: Error?) in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(rate)
            }
        case "getRawHeartRate":
            let myArgs = call.arguments as! [String: Int]
            let startMillis = myArgs["start"]!
            let endMillis = myArgs["end"]!
            let start = startMillis.toTimeInterval
            let end = endMillis.toTimeInterval
            HealthkitReader.sharedInstance.getRawHeartRate(start: start, end: end) { [weak self] (samples, error) in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(samples)
            }
        
        case "getAverageHeartRate":
            getAverageQuantity(quantityType: HealthkitReader.sharedInstance.heartRateQuantityType,
                         call: call,
                         unit: HKUnit.count().unitDivided(by: HKUnit.minute())) { [weak self] (rates: [[String : Any]]?, error: Error?) in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(rates?.first)
            }
        
        case "getAverageWalkingHeartRate":
            getAverageQuantity(quantityType: HealthkitReader.sharedInstance.walkingHeartRateAverageQuantityType,
                         call: call,
                         unit: HKUnit.count().unitDivided(by: HKUnit.minute())) { [weak self] (rates: [[String : Any]]?, error: Error?) in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(rates?.first)
            }
        
        case "getAverageRestingHeartRate":
            getAverageQuantity(quantityType: HealthkitReader.sharedInstance.restingHeartRateQuantityType,
                         call: call,
                         unit: HKUnit.count().unitDivided(by: HKUnit.minute())) { [weak self] (rates: [[String : Any]]?, error: Error?) in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(rates?.first)
            }
        
        case "getAverageHeartRateVariability":
            getAverageQuantity(quantityType: HealthkitReader.sharedInstance.hrvQuantityType,
                         call: call,
                               unit: HKUnit.secondUnit(with: .milli)) { [weak self] (rates: [[String : Any]]?, error: Error?) in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(rates?.first)
                
            }
        
        case "getTotalStepsInInterval":
            let myArgs = call.arguments as! [String: Int]
            let startMillis = myArgs["start"]!
            let endMillis = myArgs["end"]!
            let start = startMillis.toTimeInterval
            let end = endMillis.toTimeInterval
            HealthkitReader.sharedInstance.getTotalStepsInInterval(start: start, end: end) { [weak self] (steps: Int?, error: Error?) in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(steps)
            }
            
        case "getEnergyConsumed", "getFiberConsumed", "getSugarConsumed",
            "getCarbsConsumed", "getFatConsumed", "getProteinConsumed":
            getNutritionSampleInInterval(call: call, result: result)
                       
        case "getStepsSources":
            HealthkitReader.sharedInstance.getStepsSources { (steps: Array<String>) in
                result(steps)
            }
        
        case "getBloodGlucose":
            getQuantity(quantityType: HealthkitReader.sharedInstance.bloodGlucoseQuantityType,
                        lmnUnit: lmnUnit(from: call, defalutUnit: LMNUnit.glucoseMillimolesPerLiter),
                        call: call,
                        outputType: .detailedMap,
                        result: result)
        
        case "getForcedVitalCapacity":
            getQuantity(quantityType: HealthkitReader.sharedInstance.forcedVitalCapacityQuantityType,
                        lmnUnit: lmnUnit(from: call, defalutUnit: LMNUnit.liter),
                        call: call,
                        outputType: .detailedMap,
                        result: result)
        
        case "getPeakExpiratoryFlowRate":
            getQuantity(quantityType: HealthkitReader.sharedInstance.peakExpiratoryFlowRateQuantityType,
                        lmnUnit: lmnUnit(from: call, defalutUnit: LMNUnit.literPerMin),
                        call: call,
                        outputType: .detailedMap,
                        result: result)
            
        case "getRestingEnergy":
            getRestingEnergy(call: call, result: result)

        case "getActiveEnergy":
            getActiveEnergy(call: call, result: result)
        
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
            
        case "isCarbsConsumedAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.dietaryCarbohydrates], result: result)
        case "isFiberConsumedAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.dietaryFiber], result: result)
        case "isFatConsumedAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.dietaryFatTotal], result: result)
        case "isSugarConsumedAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.dietarySugar], result: result)
        case "isProteinConsumedAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.dietaryProtein], result: result)
        case "isEnergyConsumedAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.dietaryEnergyConsumed], result: result)

        
        case "isWaistSizeAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.waistSizeQuantityType], result: result)
        
        case "isBodyFatPercentageAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.bodyFatPercentageQuantityType], result: result)
        
        case "isHeartRateVariabilityAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.hrvQuantityType], result: result)

        case "isMenstrualDataAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.menstrualFlowCategoryType], result: result)

        case "isWorkoutsAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.workoutType], result: result)
        
        case "isBloodGlucoseAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.bloodGlucoseQuantityType], result: result)
        
        case "isForcedVitalCapacityAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.forcedVitalCapacityQuantityType], result: result)
        
        case "isPeakExpiratoryFlowRateAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.peakExpiratoryFlowRateQuantityType], result: result)

        case "isRestingEnergyAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.restingEnergyQuantityType], result: result)

        case "isActiveEnergyAuthorized":
            let reader = HealthkitReader.sharedInstance
            getRequestStatus(types: [reader.activeEnergyQuantityType], result: result)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func createReportError(error: Error) -> FlutterError? {
        let nsError = error as NSError
        
        if #available(iOS 14.0, *) {
            if nsError.code == HKError.Code.errorNoData.rawValue {
                // no data
                return nil
            }
        }
        
        if nsError.code == HKError.Code.errorDatabaseInaccessible.rawValue {
            // phone is locked
            return nil
        }
        
        return FlutterError(code: "\(nsError.code)", message: nsError.domain, details: nsError.localizedDescription)
    }

    
    private func getRestingEnergy(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let startMillis = args["start"] as? Int,
              let endMillis = args["end"] as? Int else {
            result(FlutterError(code: "Missing args", message: "missing start and end params", details: call.method))
            return
        }
        HealthkitReader.sharedInstance.getQuantity(quantityType: HealthkitReader.sharedInstance.restingEnergyQuantityType,
                                                   start: startMillis.toTimeInterval,
                                                   end: endMillis.toTimeInterval,
                                                   lmnUnit: .kCal,
                                                   maxResults: 1) { [weak self] dataMap, error in
            if let error = error {
                result(self?.createReportError(error: error))
                return
            }
            
            if let date = dataMap?.keys.first,
               let detailedOutput = dataMap?[date]  {
                let value = DataPointValue(dateInMillis: date,
                                           value: detailedOutput.value,
                                           units: .kCal,
                                           sourceApp: detailedOutput.sourceApp,
                                           additionalInfo: nil)
                result(value.resultMap())
                return
            }
            
            result(nil)
        }
    }
   
    private func getActiveEnergy(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let startMillis = args["start"] as? Int,
              let endMillis = args["end"] as? Int else {
                  result(FlutterError(code: "Missing args", message: "missing start and end params", details: call.method))
                  return
              }
        
        HealthkitReader.sharedInstance.getSampleConsumedInInterval(sampleType: HealthkitReader.sharedInstance.activeEnergyQuantityType,
                                                                   searchUnit: .kilocalorie(),
                                                                   reportUnit: .kCal,
                                                                   start: startMillis.toTimeInterval,
                                                                   end: endMillis.toTimeInterval) {[weak self] list, error in
            if let error = error {
                result(self?.createReportError(error: error))
                return
            }
            
            let resultList = list?.compactMap({ dataPointValue in
                return dataPointValue.resultMap()
            })
            result(resultList)
            
        }
    }
    
    func getRequestStatus(types: [HKObjectType], result: @escaping FlutterResult) {
        if #available(iOS 12.0, *){
            HealthkitReader.sharedInstance.getRequestStatus(for: Set(types)) { [weak self] status, error in
                if let error = error {
                    result(self?.createReportError(error: error))
                    return
                }
                
                result(status == .unnecessary)
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
    
    private func lmnUnit(from call: FlutterMethodCall, defalutUnit: LMNUnit) -> LMNUnit {
        guard let args = call.arguments as? [String: Any],
              let unit = args["unit"] as? String,
              let lmnUnit = LMNUnit(rawValue: unit) else {
                  return defalutUnit;
              }
        
        return lmnUnit
    }
    
    private func getQuantity(quantityType: HKQuantityType,
                             lmnUnit: LMNUnit,
                             call: FlutterMethodCall,
                             outputType: OutputType,
                             result: @escaping FlutterResult) {
        
        guard let args = call.arguments as? [String: Any],
              let startMillis = args["start"] as? Int,
              let endMillis = args["end"] as? Int else {
                  result(FlutterError(code: "2666", message: "Missing args", details: call.method))
                  return
              }
        
        HealthkitReader.sharedInstance.getQuantity(quantityType: quantityType,
                                                   start: startMillis.toTimeInterval,
                                                   end: endMillis.toTimeInterval,
                                                   lmnUnit: lmnUnit,
                                                   maxResults: outputType.outputLimit()) { [weak self] dataMap, error in
            if let error = error {
                result(self?.createReportError(error: error))
                return
            }
            
            result(self?.createResultData(outputType: outputType, dataMap: dataMap))
        }
    }
    
    private func createResultData(outputType: OutputType, dataMap: [Int: DetailedOutput]?) -> Any? {
        switch outputType {
        case .oneValue,.valueMap:
            return dataMap?.mapValues({ detailedOutput in
                return detailedOutput.value
            })
        case .detailedMap:
            return dataMap?.mapValues({ detailedOutput -> [String:Any] in
                var outputDict: [String:Any] = ["value": detailedOutput.value,
                                                "sourceApp": detailedOutput.sourceApp]
                if let units = detailedOutput.units {
                    outputDict["units"] = units
                }
                return outputDict
            })
        }
    }
    
    
    private func getAverageQuantity(quantityType: HKQuantityType,
                                    call: FlutterMethodCall,
                                    unit: HKUnit,
                                    result: @escaping ([[String: Any]]?, Error?) -> Void) {
        guard let myArgs = call.arguments as? [String: Int],
              let startMillis = myArgs["start"],
              let endMillis = myArgs["end"] else {
                  result( nil, NSError(domain: "", code: 2666, userInfo: ["title" : "Missing args", "details": call.method]))
            return
        }
        let start = startMillis.toTimeInterval
        let end = endMillis.toTimeInterval

        HealthkitReader.sharedInstance.getAverageQuantity(sampleType: quantityType,
                                                          unit: unit,
                                                          start: start,
                                                          end: end) { (rates: [[String : Any]]?, error: Error?) in
            if let error = error as NSError? {
                
                result( nil, error)
            } else {
                result(rates, nil)
            }
        }
    }

    private func getUserActivity(call: FlutterMethodCall,
                                 quantityType: HKQuantityType,
                                 result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let startTime = args["start"] as? TimeInterval,
              let endTime = args["end"] as? TimeInterval else {
            result(FlutterError(code: "Missing args", message: "missing start and end params", details: call.method))
            return
        }
        
        let startMillis = startTime / 1000
        let endMillis = endTime / 1000
        HealthkitReader.sharedInstance.getQuantityBySegment(quantityType: quantityType,
                                                            start: startMillis,
                                                            end: endMillis,
                                                            duration: 1,
                                                            unit: .days,
                                                            options: [.cumulativeSum, .separateBySource]) { [weak self] _, results, error in
            if let error = error {
                result(self?.createReportError(error: error))
                return
            }
            
            guard let results = results else {
                result(nil)
                return
            }
            
            let startDate = Date(timeIntervalSince1970: startMillis)
            let endDate = Date(timeIntervalSince1970: endMillis)
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    if sum.is(compatibleWith: .count()) == false {
                        result(FlutterError(code: "\(-1)", message: "getUserActivity", details: "Cannd evaluate count for \(quantityType) "))
                        return
                    }
                    
                    let dataPointValue = DataPointValue(dateInMillis: Int(statistics.startDate.timeIntervalSince1970 * 1000),
                                                        value: sum.doubleValue(for: .count()),
                                                        units: .count,
                                                        sourceApp: statistics.sources?.first?.bundleIdentifier,
                                                        additionalInfo: ["endDateInMillis" : Int(statistics.endDate.timeIntervalSince1970 * 1000)])
                    result(dataPointValue.resultMap())
                    return
                }
                
                result(nil)
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
                                                               handler: { [weak self] samples, error in
            if let error = error {
                result(self?.createReportError(error: error))
                return
            }
            
            result(samples)
        })
    }

    private func getRawSleepDataInRange(call: FlutterMethodCall,
                                 result: @escaping FlutterResult) {
        let args = call.arguments as! [String: Int]
        let startMillis = args["start"]!
        let endMillis = args["end"]!
        let start = startMillis.toTimeInterval
        let end = endMillis.toTimeInterval

        HealthkitReader.sharedInstance.getRawSleepDataForRange(start: start,
                                                               end: end,
                                                               handler: { [weak self] rawData, error in
            if let error = error {
                result(self?.createReportError(error: error))
                return
            }
            
            result(rawData)
        })
    }
    
    private func getQuantityBySegment(quantityType: HKQuantityType, call: FlutterMethodCall, convertToInt: Bool = false, result: @escaping FlutterResult) {
        let args = QuantityArgs(arguments: call.arguments!)
        HealthkitReader.sharedInstance.getQuantityBySegment(quantityType: quantityType, start: args.start, end: args.end, duration: args.duration, unit: args.unit) { [weak self] (quantityByStartTime: [Int: Double]?, error: Error?) -> () in
            if let error = error {
                result(self?.createReportError(error: error))
                return
            }
            
            if let quantityByStartTime = quantityByStartTime {
                if convertToInt {
                    result(quantityByStartTime.mapValues({ Int($0) }))
                } else {
                    result(quantityByStartTime)
                }
                return
            }
            
            result(nil)
        }
    }

    private func getCategoryBySegment(categoryType: HKCategoryType,
                                              call: FlutterMethodCall,
                                              result: @escaping FlutterResult) {
        
        guard let args = call.arguments as? [String: Any],
              let startMillis = args["start"] as? Int,
              let endMillis = args["end"] as? Int else {
                  result(FlutterError(code: "2666", message: "Missing args", details: call.method))
                  return
              }
        
        HealthkitReader.sharedInstance.getCategory(categoryType: categoryType,
                                                   start: startMillis.toTimeInterval,
                                                   end: endMillis.toTimeInterval) { [weak self] values, error in
            if let error = error {
                result(self?.createReportError(error: error))
                return
            }
            
            let resultList = values?.compactMap({ dataPointValue in
                return dataPointValue.resultMap()
            })
            result(resultList)
        }
    }
    
    private func getNutritionSampleInInterval(call: FlutterMethodCall,
                                              result: @escaping FlutterResult) {
        let methodName = call.method
        
        guard let myArgs = call.arguments as? [String: Int],
              let startMillis = myArgs["start"],
              let endMillis = myArgs["end"],
              let sampleType = methodNamesToQuantityTypes[methodName] else {
            result(FlutterError(code: "Missing args", message: "missing start and end params", details:""))
            return
        }
        let start = startMillis.toTimeInterval
        let end = endMillis.toTimeInterval
        
        let units = getNutritionUnitsBy(methodName: methodName)
        HealthkitReader.sharedInstance.getSampleConsumedInInterval(sampleType: sampleType,
                                                                   searchUnit: units.searchUnit,
                                                                   reportUnit: units.reportUnit,
                                                                   start: start,
                                                                   end: end) {[weak self] (list: [DataPointValue]?, error: Error?) in
            if let error = error {
                result(self?.createReportError(error: error))
                return
            }
            
            let resultList = list?.compactMap({ dataPointValue in
                return dataPointValue.resultMap()
            })
            result(resultList)
        }
    }


    private func getNutritionUnitsBy(methodName: String) -> (searchUnit: HKUnit, reportUnit: DataPointValue.LumenUnit) {
        if methodName == "getEnergyConsumed" {
            return (HKUnit.kilocalorie(), .kCal)
        } else {
            return (HKUnit.gram(), .g)
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
