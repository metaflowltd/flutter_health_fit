package com.metaflow.flutterhealthfit

import android.app.Activity
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Field.*
import com.google.android.gms.fitness.request.DataReadRequest
import java.util.concurrent.TimeUnit

class NutritionReader {
    private val logTag = NutritionReader::class.java.simpleName

    companion object {
        val nutritionType: DataType = DataType.TYPE_NUTRITION
    }

    fun getEnergyConsumed(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        getNutrition(
            type = NUTRIENT_CALORIES,
            units = LumenUnit.KCAL,
            currentActivity = currentActivity,
            startTime = startTime,
            endTime = endTime,
            result = result
        )
    }

    fun getFatConsumed(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        getNutrition(
            type = NUTRIENT_TOTAL_FAT,
            units = LumenUnit.G,
            currentActivity = currentActivity,
            startTime = startTime,
            endTime = endTime,
            result = result
        )
    }

    fun getCarbsConsumed(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        getNutrition(
            type = NUTRIENT_TOTAL_CARBS,
            units = LumenUnit.G,
            currentActivity = currentActivity,
            startTime = startTime,
            endTime = endTime,
            result = result
        )
    }

    fun getProteinConsumed(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        getNutrition(
            type = NUTRIENT_PROTEIN,
            units = LumenUnit.G,
            currentActivity = currentActivity,
            startTime = startTime,
            endTime = endTime,
            result = result
        )
    }

    fun getFiberConsumed(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        getNutrition(
            type = NUTRIENT_DIETARY_FIBER,
            units = LumenUnit.G,
            currentActivity = currentActivity,
            startTime = startTime,
            endTime = endTime,
            result = result
        )
    }

    fun getSugarConsumed(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        getNutrition(
            type = NUTRIENT_SUGAR,
            units = LumenUnit.G,
            currentActivity = currentActivity,
            startTime = startTime,
            endTime = endTime,
            result = result
        )
    }

    private fun getNutrition(
        type: String,
        units: LumenUnit,
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        val gsa = GoogleSignIn.getAccountForExtension(
            currentActivity,
            FlutterHealthFitPlugin.getFitnessOptions(nutritionType)
        )

        val request = DataReadRequest.Builder()
            .read(nutritionType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .build()


        Fitness.getHistoryClient(currentActivity, gsa).readData(request)
            .addOnSuccessListener { response ->
                val nutritionField = nutritionType.fields[0]
                val valueMap = mutableMapOf<String, DataPointValue>()
                val caloriesDataSet = response.getDataSet(nutritionType)
                var aggregatedCalories = 0.0F
                caloriesDataSet.dataPoints.forEach { dataPoint ->
                    val value = dataPoint.getValue(nutritionField).getKeyValue(type)
                    if (value != null && value > 0) {
                        aggregatedCalories += value

                        val sourceApp = dataPoint.dataSource.appPackageName ?: ""
                        val dateInMillis = dataPoint.getStartTime(TimeUnit.MILLISECONDS)
                        val sourceValue = valueMap[sourceApp]
                        if (sourceValue != null) {
                            valueMap[sourceApp] = sourceValue.add(
                                value = value,
                                dateInMillis = dateInMillis
                            )
                        } else {
                            valueMap[sourceApp] = DataPointValue(
                                dateInMillis = dateInMillis,
                                value = value,
                                units = units,
                                sourceApp = sourceApp,
                            )
                        }
                    }
                }

                if (valueMap.isEmpty()) {
                    result(null, null)
                } else {
                    val outputList = valueMap.values.toMutableList()
                    val dataPointValue = DataPointValue(
                        dateInMillis = outputList.first().dateInMillis,
                        value = aggregatedCalories,
                        units = units,
                        sourceApp = FlutterHealthFitPlugin.AGGREGATED_SOURCE_APP,
                    )
                    outputList.add(dataPointValue)
                    result(outputList, null)
                }
            }
            .addOnFailureListener { e ->
                Log.e(logTag, "Failed to read session", e)
                result(null, e)
            }
    }
}