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
    
    var hasRequestedHealthKit = false
    
    var yesterdayHKData  = [String: String]()
    
    func canWriteWeight()-> Bool{
        let authStatus = self.healthStore.authorizationStatus(for: HealthkitReader.weightQuantityType())
        
        
        return authStatus == .sharingAuthorized
    }
    
    func quantityTypesToRead() -> [HKQuantityType]{
        return [
            HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.stepCount)!,
            HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceWalkingRunning)!,
            HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.distanceCycling)!,
            HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.basalEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.activeEnergyBurned)!,
            HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.flightsClimbed)!,
            HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier.heartRate)!
        ]
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
                HKCategoryType.categoryType(forIdentifier: HKCategoryTypeIdentifier.sleepAnalysis)!
            ] + quantityTypesToRead())
    }
    
    var healthKitTypesToWrite : Set<HKSampleType> {
        return [HKObjectType.workoutType()]
    }

    func requestHealthAuthorization(_ completion: @escaping ((Bool) -> ())){
        self.hasRequestedHealthKit = true
        
        self.healthStore.requestAuthorization(toShare: healthKitTypesToWrite, read: healthKitTypesToRead, completion: { success, error in
            completion(success)
        })
    }
    
    @available(iOS 12.0, *)
    func getRequestStatusForAuthorization(completion: @escaping (HKAuthorizationRequestStatus, Error?) -> Void) {
        healthStore.getRequestStatusForAuthorization(toShare: healthKitTypesToWrite, read: healthKitTypesToRead, completion: completion)
    }
    
    
    func getTotalStepsInInterval(start: TimeInterval, end: TimeInterval, completion: @escaping (Int?, Error?) -> Void) {
        let startDate = Date(timeIntervalSince1970: start)
        let endDate = Date(timeIntervalSince1970: end)
        let sampleType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
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

