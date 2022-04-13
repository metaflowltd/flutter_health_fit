package com.metaflow.flutterhealthfit

import android.app.Activity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
import java.util.concurrent.TimeUnit

class UserEnergyReader {
    companion object {
        val restingEnergyType: DataType = DataType.TYPE_BASAL_METABOLIC_RATE
    }

    fun getRestingEnergy(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (DataPointValue?, Throwable?) -> Unit,
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        val gsa = GoogleSignIn.getAccountForExtension(currentActivity, FlutterHealthFitPlugin.getFitnessOptions(restingEnergyType))

        val request = DataReadRequest.Builder()
            .read(restingEnergyType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .build()

        Fitness.getHistoryClient(currentActivity, gsa).readData(request)
            .addOnSuccessListener { response ->
                val field = restingEnergyType.fields[0]
                val caloriesDataSet = response.getDataSet(restingEnergyType)
                caloriesDataSet.dataPoints.lastOrNull()?.let { dataPoint ->
                    val dataPointValue = DataPointValue(
                        dateInMillis = dataPoint.getStartTime(TimeUnit.MILLISECONDS),
                        value = dataPoint.getValue(field).asFloat(),
                        units = LumenUnit.KCAL,
                        sourceApp = dataPoint.dataSource.appPackageName,
                    )
                    result(dataPointValue, null)
                } ?: run {
                    result(null, null)
                }
            }
            .addOnFailureListener { e ->
                result(null, e)
            }
    }
}