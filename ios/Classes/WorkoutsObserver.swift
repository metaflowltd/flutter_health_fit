import Foundation
import Flutter
import HealthKit

class WorkoutsObserver: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?
    var observerQuery: HKObserverQuery?
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        self.startObservation()
        return nil
    }
    
    private func startObservation() {
        let observerQuery = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { (query, completionHandler, errorOrNil) in
            print("WorkoutsObserver got event")
            guard let eventSink = self.eventSink else {
                return
            }
            
            if let error = errorOrNil as NSError? {
                eventSink(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
            } else {
                eventSink("workouts updated");
            }
            completionHandler()
        }
        
        self.observerQuery = observerQuery
        HealthkitReader.sharedInstance.healthStore.execute(observerQuery)
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("WorkoutsObserver cancelled")
        eventSink = nil
        if let observerQuery = self.observerQuery {
            HealthkitReader.sharedInstance.healthStore.stop(observerQuery)
        }
        return nil
    }
    
}
