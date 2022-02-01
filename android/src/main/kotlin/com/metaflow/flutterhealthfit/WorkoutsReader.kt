package com.metaflow.flutterhealthfit

import android.app.Activity
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
import com.google.android.gms.tasks.Tasks
import java.util.concurrent.TimeUnit

class WorkoutsReader {
    private val workoutDataType: DataType = DataType.TYPE_WORKOUT_EXERCISE

    fun authorizedFitnessOptions(): FitnessOptions {
        return FitnessOptions.builder().addDataType(workoutDataType).build()
    }

    fun getWorkouts(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<Map<String, Any>>?, Throwable?) -> Unit
    ) {
        val workoutOptions = FitnessOptions.builder().addDataType(workoutDataType).build()

        val activity = currentActivity ?: return
        val gsa = GoogleSignIn.getAccountForExtension(activity, workoutOptions)

        val request = DataReadRequest.Builder().read(workoutDataType)
            .aggregate(DataType.TYPE_CALORIES_EXPENDED)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .bucketByActivityType(1, TimeUnit.MINUTES)
            .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

       val outputList = mutableListOf<Map<String, Any>>()
        Thread {
            try {
                val caloriesDataType = DataType.TYPE_CALORIES_EXPENDED
                val caloriesExpendedField = caloriesDataType.fields[0]

                val readDataResult = Tasks.await(response)
                readDataResult.buckets.forEach{
                    val dataPoint = it.getDataSet(caloriesDataType)?.dataPoints?.lastOrNull()
                    val workoutType = it.zzd()
                    val workoutActivity = it.activity
                    val workoutStart = it.getStartTime(TimeUnit.MILLISECONDS)
                    val workoutEnd = it.getEndTime(TimeUnit.MILLISECONDS)
                    val workoutEnergy = dataPoint?.getValue(caloriesExpendedField)?.asFloat()
                    val workoutSource = dataPoint?.originalDataSource?.appPackageName ?: dataPoint?.dataSource?.appPackageName

                    val map = createWorkoutMap( workoutType, workoutActivity, workoutStart, workoutEnd, workoutEnergy, workoutSource)
                    outputList.add(map)
                }

                activity.runOnUiThread {
                    if (outputList.isEmpty()) {
                        result(null, null)
                    }
                    else {
                        result(outputList, null)
                    }
                }

            } catch (e: Throwable) {
                activity.runOnUiThread {
                    result(null, e)
                }
            }

        }.start()
    }

    private fun createWorkoutMap(type: Int,
                                 activity: String,
                                 start: Long,
                                 end: Long,
                                 energy: Float?,
                                 source: String? ): Map<String, Any> {
        val workoutId = "$activity-$start-$end"

        val map = mutableMapOf(
            "id" to workoutId,
            "type" to type,
            "start" to start,
            "end" to end,
        )
        if (energy != null) {
            map["energy"] = energy.toInt()
        }
        if (source != null) {
            map["source"] = source
        }

        return map
    }
}