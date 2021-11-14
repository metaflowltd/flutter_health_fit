//
//  HealthkitReader.swift
//  ActivityTracker
//
//  Created by Danny Shmueli on 02/11/2015.
//  Copyright © 2015 Metaflow. All rights reserved.
//

import UIKit
import HealthKit

enum TimeUnit: Int {
    case minutes
    case days
}

class HealthkitReader: NSObject {
    
    static let sharedInstance = HealthkitReader()
    let healthStore = HKHealthStore()
    
    var hasRequestedHealthKitInThisRun = false
    
    var yesterdayHKData  = [String: String]()
    
    func canWriteWeight()-> Bool{
        let authStatus = self.healthStore.authorizationStatus(for: HealthkitReader.weightQuantityType())
        
        
        return authStatus == .sharingAuthorized
    }
    
    var stepsQuantityType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .stepCount)!
    }
        
    var sleepCategoryType: HKCategoryType {
        return HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    }
    
    var menstrualFlowType: HKCategoryType {
        return HKObjectType.categoryType(forIdentifier: .menstrualFlow)!
    }


    var cyclingDistanceQuantityType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .distanceCycling)!
        
    }

    var flightsClimbedQuantityType : HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .flightsClimbed)!
    }
    
    var heartRateQuantityType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .heartRate)!
    }
    
    var dietaryEnergyConsumed: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed)!
    }
    
    var dietaryFiber: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .dietaryFiber)!
    }
    
    var dietarySugar: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .dietarySugar)!
    }
    
    var dietaryCarbohydrates: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .dietaryCarbohydrates)!
    }
    
    var dietaryFatTotal: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .dietaryFatTotal)!
    }
    
    var dietaryProtein: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .dietaryProtein)!
    }
    
    @available(iOS 11.0, *)
    var restingHeartRateQuantityType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
    }

    @available(iOS 11.0, *)
    var walkingHeartRateAverageQuantityType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .walkingHeartRateAverage)!
    }
    
    @available(iOS 11.0, *)
    var heartRateVariabilityQuantityType: HKQuantityType {
        return HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
    }
    
    func quantityTypesToRead() -> [HKQuantityType]{
        var types = [
            stepsQuantityType,
            HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            cyclingDistanceQuantityType,
            HKQuantityType.quantityType(forIdentifier: .basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
            flightsClimbedQuantityType,
            heartRateQuantityType,
            dietaryEnergyConsumed,
            dietaryFiber,
            dietarySugar,
            dietaryFatTotal,
            dietaryProtein,
            dietaryCarbohydrates
        ]
        if #available(iOS 11.0, *) {
            types += [restingHeartRateQuantityType, walkingHeartRateAverageQuantityType, heartRateVariabilityQuantityType]
        }
        return types
    }
    
    func getHealthDataValue ( type : HKQuantityTypeIdentifier , strUnitType : String , complition: @escaping (((([[String:Any]])?) -> Void)) )
    {
        if let heartRateType = HKQuantityType.quantityType(forIdentifier: type)
        {
            if (HKHealthStore.isHealthDataAvailable()  ){
                
                let sortByTime = NSSortDescriptor(key:HKSampleSortIdentifierEndDate, ascending:false)
                
                //            let timeFormatter = NSDateFormatter()
                //            timeFormatter.dateFormat = "hh:mm:ss"
                //yyyy-MM-dd'T'HH:mm:ss.SSSZZZZ
                
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                let yesterday = Date().yesterday
                
                //this is probably why my data is wrong
                let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: Date().startDay, options: [])

                let query = HKSampleQuery(sampleType:heartRateType, predicate:predicate, limit:0, sortDescriptors:[sortByTime], resultsHandler:{(query, results, error) in
                    
                    guard let results = results else {
                        return
                    }
                    
                    var arrHealthValues     = [[String:Any]]()
                    
                    for quantitySample in results {
                        let quantity = (quantitySample as! HKQuantitySample).quantity
                        let healthDataUnit : HKUnit
                        if (strUnitType.count > 0 ){
                            healthDataUnit = HKUnit(from: strUnitType)
                        }else{
                            healthDataUnit = HKUnit.count()
                        }
                        
                        let tempActualhealthData = "\(quantity.doubleValue(for: healthDataUnit))"
                        let tempActualRecordedDate = "\(dateFormatter.string(from: quantitySample.startDate))"
                        if  (tempActualhealthData.count > 0){
                            let dicHealth : [String:Any] = ["value" :tempActualhealthData , "date" :tempActualRecordedDate , "unit" : strUnitType ]
                            arrHealthValues.append(dicHealth)
                        }
                    }
                    
                    if  (arrHealthValues.count > 0)
                    {
                        complition( arrHealthValues)
                    }
                    else
                    {
                        complition(nil)
                    }
                })
                self.healthStore.execute(query)
            }
        }
    }
    
    var healthKitTypesToRead : Set<HKObjectType> {
        return Set([
                HKCharacteristicType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.biologicalSex)!,
                HKCharacteristicType.characteristicType(forIdentifier: HKCharacteristicTypeIdentifier.dateOfBirth)!,
                HKObjectType.workoutType(),
                HealthkitReader.weightQuantityType(),
                HealthkitReader.heightQuantityType(),
                sleepCategoryType,
                menstrualFlowType,
            ] + quantityTypesToRead())
    }
    
    func requestHealthAuthorization(_ completion: @escaping ((Bool) -> ())){
        self.hasRequestedHealthKitInThisRun = true
        
        self.healthStore.requestAuthorization(toShare: nil, read: healthKitTypesToRead, completion: { success, error in
            completion(success)
        })
    }
    
    @available(iOS 12.0, *)
    func getRequestStatusForAuthorization(completion: @escaping (HKAuthorizationRequestStatus, Error?) -> Void) {
        getRequestStatus(for: healthKitTypesToRead, completion: completion)
    }
    
    @available(iOS 12.0, *)
    func getRequestStatus(for types: Set<HKObjectType>, completion: @escaping (HKAuthorizationRequestStatus, Error?) -> Void) {
        healthStore.getRequestStatusForAuthorization(toShare: Set(), read: types, completion: completion)
    }
    
    func getSleepSamplesForRange(start: TimeInterval,
                                  end: TimeInterval,
                                  handler: @escaping (_ result: [Any]?, _ error: Error?) -> Void)  {
        
        // Use a sortDescriptor to get the recent data first
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictEndDate])
        
        let query = HKSampleQuery(
            sampleType: sleepCategoryType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]) {
        (query: HKSampleQuery, tmpResult: [HKSample]?, error: Error?) in
            
            if let error = error {
                print("Failed to get sleep data, the reason: \(String(describing: error))")
                handler(nil, error)
                return
            }
            
            if let rawResult = tmpResult {
                let map = rawResult.map { item -> [String: Any] in
                    let sample = item as! HKCategorySample
                    let value = sample.value
                    let startDate = Int(sample.startDate.timeIntervalSince1970 * 1000)
                    let endDate = Int(sample.endDate.timeIntervalSince1970 * 1000)
                    let source = sample.sourceRevision.source.bundleIdentifier
                    
                    print("Healthkit sleep: \(startDate) \(endDate) - value: \(value)")
                    
                    return [
                        "type": value,
                        "start": startDate,
                        "end": endDate,
                        "source": source
                    ]
                    
                }
                handler(map, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func getLatestMensturalCycle(handler: @escaping (_ result: [Any]?, _ error: Error?) -> Void)  {
        
        // Use a sortDescriptor to get the recent data first
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(
            sampleType: HKSampleType.categoryType(forIdentifier: .menstrualFlow)!,
            predicate: nil,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [sortDescriptor]) {
        (query: HKSampleQuery, tmpResult: [HKSample]?, error: Error?) in
            
            if let error = error {
                print("Failed to get sleep data, the reason: \(String(describing: error))")
                handler(nil, error)
                return
            }
            
            if let rawResult = tmpResult {
                let map = rawResult.map { item -> [String: Any] in
                    let sample = item as! HKCategorySample
                    let value = sample.value
                    let startDate = Int(sample.startDate.timeIntervalSince1970 * 1000)
                    let endDate = Int(sample.endDate.timeIntervalSince1970 * 1000)
                    let source = sample.sourceRevision.source.bundleIdentifier
                    
                    print("Healthkit sleep: \(startDate) \(endDate) - value: \(value)")
                    
                    return [
                        "type": value,
                        "start": startDate,
                        "end": endDate,
                        "source": source
                    ]
                    
                }
                handler(map, nil)
            }
        }
        
        healthStore.execute(query)
    }
    
    func getQuantityBySegment(quantityType: HKQuantityType, start: TimeInterval, end: TimeInterval, duration: Int, unit: TimeUnit,
                              options: HKStatisticsOptions, initialResultsHandler: ((HKStatisticsCollectionQuery, HKStatisticsCollection?, Error?) -> Void)?) {
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
        
        let query = HKStatisticsCollectionQuery(quantityType: quantityType,
                                                quantitySamplePredicate: nil,
                                                options: options,
                                                anchorDate: anchorDate,
                                                intervalComponents: interval)
        query.initialResultsHandler = initialResultsHandler
        
        healthStore.execute(query)
    }
    
    func getQuantityBySegment(quantityType: HKQuantityType, start: TimeInterval, end: TimeInterval, duration: Int, unit: TimeUnit,
                              completion: @escaping ([Int: Double]?, Error?) -> ()) {
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        
        getQuantityBySegment(quantityType: quantityType, start: start, end: end, duration: duration, unit: unit, options: [.cumulativeSum]) { _, results, error in
            guard let results = results else {
                completion(nil, error)
                return
            }

            var dic = [Int: Double]()
            results.enumerateStatistics(from: startDate, to: endDate) { statistics, _ in
                if let sum = statistics.sumQuantity() {
                    let unit: HKUnit = quantityType.is(compatibleWith: HKUnit.count()) ? HKUnit.count() : HKUnit.meterUnit(with: .kilo)
                    let quantity = sum.doubleValue(for: unit)
                    print("Amount of \(quantityType): \(quantity), since: \(statistics.startDate) until: \(statistics.endDate)")
                    
                    let timestamp = Int(statistics.startDate.timeIntervalSince1970 * 1000)

                    dic[timestamp] = quantity
                    
                }
            }
            completion(dic, nil)
        }
    }

    func getWeight(start: TimeInterval, end: TimeInterval, completion: @escaping ([Int: Double]?, Error?) -> Void) {
            let startDate = Date(timeIntervalSince1970: start)
            let endDate = Date(timeIntervalSince1970: end)
            let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])

            // Since we are interested in retrieving the user's latest sample, we sort the samples in descending order, and set the limit to 1.
            let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

            let query = HKSampleQuery(sampleType: HealthkitReader.weightQuantityType(), predicate: predicate, limit: 1, sortDescriptors: [timeSortDescriptor]){
                query, results, error in

                guard let results = results, results.count > 0 else {
                    completion(nil, error);
                    return;
                }

                let quantitySample = results.first as! HKQuantitySample
                var dic = [Int: Double]()
                let weightInKilograms = quantitySample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                let timestamp = Int(quantitySample.startDate.timeIntervalSince1970 * 1000)
                dic[timestamp]=weightInKilograms
                completion(dic, error)
            }

            healthStore.execute(query)
        }
    
    func getHeartRateSample(start: TimeInterval, end: TimeInterval, completion: @escaping ([String: Any]?, Error?) -> Void) {
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])

        // Since we are interested in retrieving the user's latest sample, we sort the samples in descending order, and set the limit to 1.
        let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let query = HKSampleQuery(sampleType: heartRateQuantityType, predicate: predicate, limit: 1, sortDescriptors: [timeSortDescriptor]){
            query, results, error in

            guard let results = results, results.count > 0 else {
                completion(nil, error);
                return;
            }

            let quantitySample = results.first as! HKQuantitySample
            let heartRate = quantitySample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
            let timestamp = Int(quantitySample.startDate.timeIntervalSince1970 * 1000)
            var dic: [String: Any] = [
                "value": Int(heartRate),
                "timestamp": timestamp,
                "sourceApp": quantitySample.sourceRevision.source.bundleIdentifier
            ]
            if let device = quantitySample.device {
                dic["sourceDevice"] = device.localIdentifier
            }
            if let metadata = quantitySample.metadata {
                dic["metadata"] = metadata.mapValues({ (value: Any) -> Any in
                    if let date = value as? Date {
                        return Int(date.timeIntervalSince1970 * 1000)
                    }
                    return value
                })
            }
            completion(dic, error)
        }

        healthStore.execute(query)
    }
    
    func getAverageQuantity(sampleType: HKQuantityType, unit: HKUnit, start: TimeInterval, end: TimeInterval, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])
        
        let query = HKStatisticsQuery(quantityType: sampleType,
                                      quantitySamplePredicate: predicate,
                                      options: [.discreteAverage, .separateBySource]) { query, queryResult, error in
                                        
                                        guard let queryResult = queryResult else {
                                            let error = error! as NSError
                                            print("[getAverageQuantity] got error: \(error)")
                                            completion(nil, error)
                                            return
                                        }
                                        
                                        var list: [[String: Any]] = []
                                        if let sources = queryResult.sources {
                                            for source in sources {
                                                guard let quantity = queryResult.averageQuantity(for: source) else {
                                                    continue
                                                }
                                                let value = quantity.doubleValue(for: unit)
                                                let timestamp = Int(queryResult.startDate.timeIntervalSince1970 * 1000)
                                                let dic: [String: Any] = [
                                                    "value": value,
                                                    "timestamp": timestamp,
                                                    "sourceApp": source.bundleIdentifier,
                                                ]
                                                list.append(dic)
                                            }
                                        } else if let quantity = queryResult.averageQuantity() {
                                            let value = quantity.doubleValue(for: unit)
                                            let timestamp = Int(queryResult.startDate.timeIntervalSince1970 * 1000)
                                            let dic: [String: Any] = [
                                                "value": value,
                                                "timestamp": timestamp,
                                            ]
                                            list.append(dic)
                                        }

                                        completion(list, nil)
        }
        
        healthStore.execute(query)
    }

    func getTotalStepsInInterval(start: TimeInterval, end: TimeInterval, completion: @escaping (Int?, Error?) -> Void) {
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        let sampleType = stepsQuantityType
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])
        
        let query = HKStatisticsQuery(quantityType: sampleType,
                                      quantitySamplePredicate: predicate,
                                      options: .cumulativeSum) { query, queryResult, error in
                                        
                                        guard let queryResult = queryResult else {
                                            let error = error! as NSError
                                            print("[getTotalStepsInInterval] got error: \(error)")
                                            completion(nil, error)
                                            return
                                        }
                                        
                                        var steps = 0.0
                                        
                                        if let quantity = queryResult.sumQuantity() {
                                            let unit = HKUnit.count()
                                            steps = quantity.doubleValue(for: unit)
                                            print("Amount of steps: \(steps), since: \(queryResult.startDate) until: \(queryResult.endDate)")
                                        }
                                        
                                        completion(Int(steps), nil)
        }
        
        healthStore.execute(query)
    }
    
    func getSampleConsumedInInterval(sampleType: HKQuantityType, unit: HKUnit, start: TimeInterval, end: TimeInterval, completion: @escaping ([String: Int]?, Error?) -> Void) {
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: [.strictStartDate])
        
        var results = [String: Int]()
        
        let query = HKStatisticsQuery(quantityType: sampleType,
                                      quantitySamplePredicate: predicate,
                                      options: [.cumulativeSum, .separateBySource]) { query, queryResult, error in
                                        
                                        guard let queryResult = queryResult else {
                                            let error = error! as NSError
                                            print("[getSampleConsumedInInterval] for sampleType: \(sampleType) got error: \(error)")
                                            completion(nil, error)
                                            return
                                        }
                                        
                                        if let sources = queryResult.sources {
                                            for source in sources {
                                                guard let quantityBySource = queryResult.sumQuantity(for: source) else {
                                                    continue
                                                }
                                                let value = quantityBySource.doubleValue(for: unit)
                                                print("[getSampleConsumedInInterval] value: \(value), sourceApp: \(source.bundleIdentifier)")
                                                results["\(source.name):\(source.bundleIdentifier)"] = Int(value)
                                            }
                                        }
                                        
                                        if let aggregatedQuantity = queryResult.sumQuantity() {
                                            let value = aggregatedQuantity.doubleValue(for: unit)
                                            print("[getSampleConsumedInInterval] aggregated value: \(value)")
                                            results["Aggregated"] = Int(value)
                                        }
                                        
                                        completion(results, nil)
        }
        
        healthStore.execute(query)
    }
    
    func getStepsSources(completion: @escaping ((Array<String>) -> Void)) {
        let query = HKSourceQuery.init(sampleType: stepsQuantityType, samplePredicate: nil) { (query, sourcesOrNil, error) in
            guard let sources = sourcesOrNil else {
                completion([])
                return
            }
            
            let sourcesStringSet = Set(sources.map { $0.name })
            
            completion(Array(sourcesStringSet))
        }
        healthStore.execute(query)
    }
    
    func readHealthKitWokoutOfType(_ workoutType:HKWorkoutActivityType, completion:@escaping (([HKWorkout])->())){
        
        let predicate =  HKQuery.predicateForWorkouts(with: workoutType)
        // 2. Order the workouts by date
        let sortDescriptor = NSSortDescriptor(key:HKSampleSortIdentifierStartDate, ascending: false)
        // 3. Create the query
        let sampleQuery = HKSampleQuery(sampleType: HKWorkoutType.workoutType(), predicate: predicate, limit: 0, sortDescriptors: [sortDescriptor])
            {
                (sampleQuery, results, error ) -> Void in
                
                if let queryError = error {
                    print( "There was an error while reading the samples: \(queryError.localizedDescription)")
                    completion([HKWorkout]())
                }
                
                if (results != nil){
                    completion(results!.map { $0 as! HKWorkout})
                }
        }
        self.healthStore.execute(sampleQuery)
    }
    
    //MARK: - Type Makers
    
    class func weightQuantityType() -> HKQuantityType{
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!
    }
    
    class func heightQuantityType() -> HKQuantityType{
        return HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.height)!
    }
    
    //MARK: - For Profile
    
    func getLastWeightReading(_ completion:@escaping ( (_ weight:Double?) -> ())){
        self.mostRecentQuantitySampleOfType(HealthkitReader.weightQuantityType()){
            (result:HKQuantity?, error:NSError?) in
            if result == nil{
                completion(nil)
                return
            }
            let weightInKilograms = result?.doubleValue(for: HKUnit.gramUnit(with: .kilo))
            completion(weightInKilograms)
        }
    }
    
    func getLastHeightReading(_ completion:@escaping ( (_ height:Double?) -> ())){
        self.mostRecentQuantitySampleOfType(HealthkitReader.heightQuantityType()){
            (result:HKQuantity?, error:NSError?) in
            if result == nil{
                completion(nil)
                return
            }
            let heightInCM = result?.doubleValue(for: HKUnit(from: "cm"))
            completion(heightInCM)
        }
    }
    
    func getBioLogicalSex() -> Gender?{
        var bioSex:HKBiologicalSexObject?
        do {
            bioSex = try self.healthStore.biologicalSex()
        } catch _{
            bioSex = nil
        }
        if (bioSex == nil){
            return nil
        }
        if (bioSex!.biologicalSex == .male){
            return  .male
        }
        if (bioSex!.biologicalSex == .female){
            return .female
        }
        return nil
    }
    
    func getDOB() -> Date?{
        var dob:Date?
        do {
            if #available(iOS 10.0, *) {
                dob = try self.healthStore.dateOfBirthComponents().date
            } else {
                dob = nil
            }
        } catch _{
            dob = nil
        }
        return dob
    }
    
    func queryTypeForTimePeriod(_ type:HKQuantityType, fromDate: Date, toDate:Date, completion:@escaping ( (_ results:[HKSample]?)->() ) ) {
        
        let type = HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning)!
        
        
        let predicate = HKQuery.predicateForSamples(withStart: fromDate, end: toDate, options: .strictStartDate)
        let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [timeSortDescriptor]){
            query, results, error in
            
            completion(results)
        }
        self.healthStore.execute(query)
    }
    
    //MARK: - Private
    
    
    
    func mostRecentQuantitySampleOfType(_ quantityType:HKQuantityType, completion:@escaping ( (_ result:HKQuantity?, NSError?)->() )){
        let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        
        // Since we are interested in retrieving the user's latest sample, we sort the samples in descending order, and set the limit to 1. We are not filtering the data, and so the predicate is set to nil.
        let query = HKSampleQuery(sampleType: quantityType, predicate: nil, limit: 1, sortDescriptors: [timeSortDescriptor]){
            query, results, error in
            
            if (results == nil || results?.count == 0) {
                completion(nil, error as NSError?);
                return;
            }
            
            let quantitySample = results!.first as! HKQuantitySample
            
            completion(quantitySample.quantity, error as NSError?);
        }
        
        self.healthStore.execute(query)
        
    }
    
}

enum Gender : Int{
    case male = 0
    case female = 1
    
    var description : String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        }
    }
    var asServerParam:Int{
        return self.rawValue + 1
    }
    
    static func fromServerParam(_ serverParam:Int) -> Gender {
        return Gender(rawValue: (serverParam - 1) )!
    }
}

