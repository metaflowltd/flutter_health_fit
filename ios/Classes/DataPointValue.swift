//
//  DataPointValue.swift
//  flutter_health_fit
//
//  Created by Nimrod Einat on 13/02/2022.
//

import Foundation

/**
 new DataPoints sould retun DataPointValue
 */
struct DataPointValue {
    enum LumenUnit: String {
        case count = "count"
        case kg = "kg"
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
