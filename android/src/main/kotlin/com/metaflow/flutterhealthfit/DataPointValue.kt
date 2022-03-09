package com.metaflow.flutterhealthfit

import java.util.HashMap

/**
 * new items should use this class to collect data
 */
data class DataPointValue(
    val dateInMillis: Long,
    val value: Float,
    val units: LumenUnit,
    val sourceApp: String?,
    val additionalInfo: HashMap<String, Any>?,
) {
    constructor(dateInMillis: Long, value: Float, units: LumenUnit, sourceApp: String?) : this(
        dateInMillis = dateInMillis,
        value = value,
        units = units,
        sourceApp = sourceApp,
        additionalInfo = null
    )

    fun add(value: Float, dateInMillis: Long): DataPointValue {
       val newValue = this.value + value;
       val newDate = if (this.dateInMillis < dateInMillis) this.dateInMillis else dateInMillis

        return (DataPointValue(
            dateInMillis = newDate,
            value = newValue,
            units = this.units,
            sourceApp = this.sourceApp,
            additionalInfo = this.additionalInfo))
    }

    fun resultMap(): HashMap<String, Any> {
        val map: HashMap<String, Any> = hashMapOf(
            "dateInMillis" to dateInMillis,
            "value" to value,
            "units" to units.value,
        )
        sourceApp?.let { map["sourceApp"] = it }
        additionalInfo?.let { map.putAll(it) }

        return map
    }
}
