package com.metaflow.flutterhealthfit

import android.app.Activity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
import java.util.concurrent.TimeUnit

class HydrationReader {
    companion object {
        val hydrationType: DataType = DataType.TYPE_HYDRATION
        val authorizedHydrationOptions: FitnessOptions =
            FitnessOptions.builder().addDataType(hydrationType).build()
    }

    fun getHydration(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<DataPointValue>?, Throwable?) -> Unit,
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        val gsa = GoogleSignIn.getAccountForExtension(currentActivity, authorizedHydrationOptions)

        val request = DataReadRequest.Builder()
            .read(hydrationType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .build()

        Fitness.getHistoryClient(currentActivity, gsa).readData(request)
            .addOnSuccessListener { response ->
                val outputList = mutableListOf<DataPointValue>()
                val field = hydrationType.fields[0]
                val dataSet = response.getDataSet(hydrationType)


                dataSet.dataPoints.forEach { dataPoint ->
                    val point = DataPointValue(
                        dateInMillis = dataPoint.getStartTime(TimeUnit.MILLISECONDS),
                        value = dataPoint.getValue(field).asFloat(),
                        units = LumenUnit.L,
                        sourceApp = dataPoint.dataSource.appPackageName,
                    )
                    outputList.add(point)
                }


                if (outputList.isEmpty()) {
                    result(null, null)
                } else {
                    result(outputList, null)
                }
            }
            .addOnFailureListener { e ->
                result(null, e)
            }
    }
}