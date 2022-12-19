import Foundation
import Flutter
import HealthKit

class WorkoutsObserver: NSObject, FlutterStreamHandler {
    var eventSink: FlutterEventSink?
    var observerQuery: HKObserverQuery?
    private var detached:Bool = true
    
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        self.startObservation()
        return nil
    }
    
    private func startObservation() {
        detached = false
        let observerQuery = HKObserverQuery(sampleType: .workoutType(), predicate: nil) { (query, completionHandler, errorOrNil) in
            print("WorkoutsObserver got event")
            
            if(self.detached == false){
                guard let eventSink = self.eventSink else {
                    return
                }
                
                if let error = errorOrNil as NSError? {
                    eventSink(FlutterError(code: "\(error.code)", message: error.domain, details: error.localizedDescription))
                } else {
                    eventSink("workouts updated");
                }
            }
            completionHandler()
        }
        
        self.observerQuery = observerQuery
        HealthkitReader.sharedInstance.healthStore.execute(observerQuery)
    }
    
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        detached = true
        print("WorkoutsObserver cancelled")
        eventSink = nil
        if let observerQuery = observerQuery {
            HealthkitReader.sharedInstance.healthStore.stop(observerQuery)
        }
        return nil
    }
    
    func onDetach() {
        NSLog("WorkoutsObserver: Detaching workouts observer")
        _ = onCancel(withArguments: nil)
    }
    
}
