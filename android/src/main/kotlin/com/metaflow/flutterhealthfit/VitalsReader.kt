package com.metaflow.flutterhealthfit

import android.app.Activity
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.HealthDataTypes
import com.google.android.gms.fitness.data.HealthFields
import com.google.android.gms.fitness.request.DataReadRequest
import java.util.concurrent.TimeUnit

enum class BloodGlucoseReadingType {
    GENERAL,
    FASTING,
    AFTER_MEAL,
    BEFORE_MEAL
}

class VitalsReader {
    private val logTag = VitalsReader::class.java.simpleName

    companion object {
        val bloodGlucoseType: DataType = HealthDataTypes.TYPE_BLOOD_GLUCOSE
        val bloodPressureType: DataType = HealthDataTypes.TYPE_BLOOD_PRESSURE
    }

    fun getBloodGlucose(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<Map<String, Any>>?, Throwable?) -> Unit,
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        val fitnessOptions = FlutterHealthFitPlugin.getFitnessOptions(bloodGlucoseType)

        val gsa = GoogleSignIn.getAccountForExtension(currentActivity, fitnessOptions)

        val request = DataReadRequest.Builder().read(bloodGlucoseType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .build()

        Fitness.getHistoryClient(currentActivity, gsa)
            .readData(request)
            .addOnSuccessListener { response ->
                val resultList = mutableListOf<Map<String, Any>>()
                for (dataPoint in response.dataSets.flatMap { it.dataPoints }) {
                    val dateTime = dataPoint.getTimestamp(TimeUnit.MILLISECONDS)
                    val value = dataPoint.getValue(bloodGlucoseType.fields[0]).asFloat()
                    val readingType = when (dataPoint.getValue(bloodGlucoseType.fields[1]).asInt()) {
                        HealthFields.FIELD_TEMPORAL_RELATION_TO_MEAL_FASTING -> BloodGlucoseReadingType.FASTING
                        HealthFields.FIELD_TEMPORAL_RELATION_TO_MEAL_AFTER_MEAL -> BloodGlucoseReadingType.AFTER_MEAL
                        HealthFields.FIELD_TEMPORAL_RELATION_TO_MEAL_BEFORE_MEAL -> BloodGlucoseReadingType.BEFORE_MEAL
                        else -> BloodGlucoseReadingType.GENERAL
                    }

                    Log.i(
                        logTag, "Blood glucose data:" +
                                "\n Glucose value: $value" +
                                "\n Reading type: $readingType" +
                                "\n Datetime: $dateTime"
                    )

                    resultList.add(
                        mapOf(
                            "dateTime" to dateTime,
                            "value" to value,
                            "readingType" to readingType.name,
                            "sourceApp" to (dataPoint.originalDataSource.appPackageName ?: ""),
                        )
                    )
                }
                result(resultList, null)
            }
            .addOnFailureListener { exception ->
                Log.e(logTag, "Failed to read blood sugar", exception)
                result(null, exception)
            }
    }

    fun getBloodPressure(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<Map<String, Any>>?, Throwable?) -> Unit,
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        val fitnessOptions = FlutterHealthFitPlugin.getFitnessOptions(bloodPressureType)

        val gsa = GoogleSignIn.getAccountForExtension(currentActivity, fitnessOptions)

        val request = DataReadRequest.Builder().read(bloodPressureType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .build()

        Fitness.getHistoryClient(currentActivity, gsa)
            .readData(request)
            .addOnSuccessListener { response ->
                val resultList = mutableListOf<Map<String, Any>>()
                for (dataPoint in response.dataSets.flatMap { it.dataPoints }) {
                    val dateTime = dataPoint.getTimestamp(TimeUnit.MILLISECONDS)
                    val systolicValue = dataPoint.getValue(bloodPressureType.fields[0]).asFloat()
                    val diastolicValue = dataPoint.getValue(bloodPressureType.fields[1]).asFloat()

                    Log.i(
                        logTag, "Blood pressure data:" +
                                "\n Systolic value: $systolicValue" +
                                "\n Diastolic value: $diastolicValue" +
                                "\n Datetime: $dateTime"
                    )

                    resultList.add(
                        mapOf(
                            "dateTime" to dateTime,
                            "systolic" to systolicValue,
                            "diastolic" to diastolicValue,
                            "sourceApp" to (dataPoint.originalDataSource.appPackageName ?: ""),
                        )
                    )
                }
                result(resultList, null)
            }
            .addOnFailureListener { exception ->
                Log.e(logTag, "Failed to read blood pressure", exception)
                result(null, exception)
            }
    }
}
