//
//  DataPointValue.swift
//  flutter_health_fit
//
//  Created by Nimrod Einat on 13/02/2022.
//

import Foundation

/**
 new items should use this class to collect data
 */
struct DataPointValue {
    enum LumenUnit: String {
        case count = "count"
        case kg = "kg"
        case percent = "percent"
        case cm = "cm"
    }
    
    let dateInMillis: Int
    let value: Double
    let units: LumenUnit
    let sourceApp: String?
    let additionalInfo: [String: Any]?
    
    func resultMap() -> [String: Any] {
        var outMap: [String: Any] = ["dateInMillis": dateInMillis,
                                     "value": value,
                                     "units": units.rawValue]
        if let sourceApp = sourceApp {
            outMap["sourceApp"] = sourceApp
        }
        if let additionalInfo = additionalInfo {
            outMap = outMap.merging(additionalInfo) {$1}
        }
        
        return outMap
    }
}
