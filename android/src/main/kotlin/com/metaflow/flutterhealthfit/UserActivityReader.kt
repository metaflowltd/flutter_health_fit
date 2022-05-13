package com.metaflow.flutterhealthfit

import android.app.Activity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.data.DataSource
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
import java.util.concurrent.TimeUnit

class UserActivityReader {
    companion object {
        val stepsDataType: DataType = DataType.TYPE_STEP_COUNT_DELTA
        val aggregatedStepDataType: DataType = DataType.AGGREGATE_STEP_COUNT_DELTA
    }

    fun getSteps(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (DataPointValue?, Throwable?) -> Unit,
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        val fitnessOptions = FlutterHealthFitPlugin.getFitnessOptions(setOf(stepsDataType, aggregatedStepDataType))
        val gsa = GoogleSignIn.getAccountForExtension(currentActivity, fitnessOptions)

        val ds = DataSource.Builder()
            .setAppPackageName("com.google.android.gms")
            .setDataType(stepsDataType)
            .setType(DataSource.TYPE_DERIVED)
            .setStreamName("estimated_steps")
            .build()

        val request = DataReadRequest.Builder()
            .aggregate(ds)
            .bucketByTime((endTime - startTime + 1).toInt(), TimeUnit.MILLISECONDS)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .build()

        Fitness.getHistoryClient(currentActivity, gsa).readData(request).addOnSuccessListener { response ->
            val outputList = mutableListOf<DataPointValue>()

            response.buckets.firstOrNull()?.dataSets?.firstOrNull()?.dataPoints?.firstOrNull()?.let { dp ->
                val count = dp.getValue(aggregatedStepDataType.fields[0]).asInt()
                val appPackageName = dp.dataSource.appPackageName
                val dpStartTime = dp.getStartTime(TimeUnit.MILLISECONDS)
                val dpEndTime = dp.getEndTime(TimeUnit.MILLISECONDS)

                val dataPointValue = DataPointValue(
                    dateInMillis = dpStartTime,
                    value = count.toFloat(),
                    units = LumenUnit.COUNT,
                    sourceApp = appPackageName,
                    additionalInfo = hashMapOf("endDateInMillis" to dpEndTime),
                )
                outputList.add(dataPointValue)
            }

            result(outputList.firstOrNull(), null)
        }.addOnFailureListener { e ->
            result(null, e)
        }
    }
}
