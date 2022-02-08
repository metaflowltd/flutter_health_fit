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
    private val caloriesDataType: DataType = DataType.TYPE_CALORIES_EXPENDED
    private val activityDataType: DataType = DataType.TYPE_ACTIVITY_SEGMENT
    private val activitySummaryDataType: DataType = DataType.AGGREGATE_ACTIVITY_SUMMARY
    private val unknownWorkoutType: Int = 4

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
            .aggregate(caloriesDataType)
            .aggregate(activityDataType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .bucketByActivitySegment(1, TimeUnit.MINUTES)
            .build()

        val response = Fitness.getHistoryClient(activity, gsa).readData(request)

       val outputList = mutableListOf<Map<String, Any>>()
        Thread {
            try {
                val caloriesExpendedField = caloriesDataType.fields[0]
                val activityField = activitySummaryDataType.fields.first {
                    it.name == "activity"
                }
                val readDataResult = Tasks.await(response)
                readDataResult.buckets.forEach{
                    val caloriesDataPoint = it.getDataSet(caloriesDataType)?.dataPoints?.lastOrNull()
                    val activityDataPoint = it.getDataSet(activitySummaryDataType)?.dataPoints?.lastOrNull()
                    val workoutType = activityDataPoint?.getValue(activityField)?.asInt() ?: unknownWorkoutType
                    val workoutActivity = it.activity
                    val workoutStart = it.getStartTime(TimeUnit.MILLISECONDS)
                    val workoutEnd = it.getEndTime(TimeUnit.MILLISECONDS)
                    val workoutEnergy = caloriesDataPoint?.getValue(caloriesExpendedField)?.asFloat()
                    val workoutSource = caloriesDataPoint?.originalDataSource?.appPackageName ?: caloriesDataPoint?.dataSource?.appPackageName
                    if (workoutType != unknownWorkoutType) {
                        // we don't want unknown activities. Those are just fillers with calories
                        val map = createWorkoutMap(
                            workoutType,
                            workoutActivity,
                            workoutStart,
                            workoutEnd,
                            workoutEnergy,
                            workoutSource
                        )
                        outputList.add(map)
                    }
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
            map["energy"] = energy
        }
        if (source != null) {
            map["source"] = source
        }

        return map
    }
}