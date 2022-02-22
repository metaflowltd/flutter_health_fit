package com.metaflow.flutterhealthfit

import android.app.Activity
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Field.NUTRIENT_CALORIES
import com.google.android.gms.fitness.request.DataReadRequest
import java.util.concurrent.TimeUnit

class NutritionReader {
    private val logTag = NutritionReader::class.java.simpleName

    companion object {
        val nutritionType: DataType = DataType.TYPE_NUTRITION
        val authorizedNutritionOptions: FitnessOptions = FitnessOptions.builder().addDataType(nutritionType).build()
        val aggregatedData = "Aggregated"
    }

    fun getEnergyConsumed(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        val gsa = GoogleSignIn.getAccountForExtension(currentActivity, authorizedNutritionOptions)

        val request = DataReadRequest.Builder()
            .read(nutritionType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .build()

        Fitness.getHistoryClient(currentActivity, gsa).readData(request)
            .addOnSuccessListener { response ->
                val nutritionField = nutritionType.fields[0]

                val outputList = mutableListOf<DataPointValue>()
                val caloriesDataSet = response.getDataSet(nutritionType)
                var aggregatedCalories = 0.0F
                caloriesDataSet.dataPoints.forEach { dataPoint ->
                    val value = dataPoint.getValue(nutritionField).getKeyValue(NUTRIENT_CALORIES)
                    if (value != null && value > 0) {
                        aggregatedCalories += value
                        val dataPointValue = DataPointValue(
                            dateInMillis = dataPoint.getStartTime(TimeUnit.MILLISECONDS),
                            value = value,
                            units = LumenUnit.KCAL,
                            sourceApp = dataPoint.dataSource.appPackageName,
                        )
                        outputList.add(dataPointValue)
                    }
                }

                if (outputList.isEmpty()) {
                    result(null, null)
                }
                else {
                    val dataPointValue = DataPointValue(
                        dateInMillis = outputList.first().dateInMillis,
                        value = aggregatedCalories,
                        units = LumenUnit.KCAL,
                        sourceApp = aggregatedData,
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