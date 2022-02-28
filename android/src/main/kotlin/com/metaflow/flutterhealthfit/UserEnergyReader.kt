package com.metaflow.flutterhealthfit

import android.app.Activity
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
import java.util.concurrent.TimeUnit

class UserEnergyReader {
    private val logTag = UserEnergyReader::class.java.simpleName

    companion object {
        val activeEnergyType: DataType = DataType.TYPE_BASAL_METABOLIC_RATE
        val activeEnergySummaryType: DataType = DataType.TYPE_BASAL_METABOLIC_RATE
    }

    fun getActiveEnergy(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        val gsa = GoogleSignIn.getAccountForExtension(currentActivity,
            NutritionReader.authorizedNutritionOptions)

        val request = DataReadRequest.Builder()
            .read(activeEnergyType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .build()


        Fitness.getHistoryClient(currentActivity, gsa).readData(request)
            .addOnSuccessListener { response ->
                val field = activeEnergyType.fields[0]
                val valueMap = mutableMapOf<String,DataPointValue>()
                val caloriesDataSet = response.getDataSet(activeEnergySummaryType)
                var aggregatedValue = 0.0F
                caloriesDataSet.dataPoints.forEach { dataPoint ->
                    val value = dataPoint.getValue(field).asFloat()
                    if (value != null && value > 0) {
                        aggregatedValue += value

                        val sourceApp = dataPoint.dataSource.appPackageName
                        val dateInMillis = dataPoint.getStartTime(TimeUnit.MILLISECONDS)
                        val sourceValue = valueMap[sourceApp]
                        if (sourceValue != null) {
                            valueMap[sourceApp] = sourceValue.add(
                                value = value,
                                dateInMillis = dateInMillis)
                        }
                        else {
                            valueMap[sourceApp] = DataPointValue(
                                dateInMillis = dateInMillis,
                                value = value,
                                units = LumenUnit.KCAL,
                                sourceApp = sourceApp,
                            )
                        }
                    }
                }

                if (valueMap.isEmpty()) {
                    result(null, null)
                }
                else {
                    val outputList = valueMap.values.toMutableList()
                    val dataPointValue = DataPointValue(
                        dateInMillis = outputList.first().dateInMillis,
                        value = aggregatedValue,
                        units = LumenUnit.KCAL,
                        sourceApp = FlutterHealthFitPlugin.aggregatedSourceApp,
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