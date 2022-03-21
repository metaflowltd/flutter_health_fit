package com.metaflow.flutterhealthfit

import android.app.Activity
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
import java.util.*
import java.util.concurrent.TimeUnit

class WorkoutsReader {
    companion object {
        private val activityDataType = DataType.TYPE_ACTIVITY_SEGMENT
        private val workoutDataType = DataType.TYPE_WORKOUT_EXERCISE
        private val caloriesDataType = DataType.TYPE_CALORIES_EXPENDED
        private val activitySummaryDataType = DataType.AGGREGATE_ACTIVITY_SUMMARY
        val authorizedFitnessOptions: FitnessOptions =
            FitnessOptions.builder().addDataType(workoutDataType).build()
    }

    private val logTag = WorkoutsReader::class.java.simpleName
    private val unknownActivityType: Int = 4
    private val stillActivityType: Int = 3
    private val carActivityType: Int = 0

    fun getWorkouts(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<Map<String, Any>>?, Throwable?) -> Unit,
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        val gsa = GoogleSignIn.getAccountForExtension(currentActivity, authorizedFitnessOptions)

        val request = DataReadRequest.Builder()
            .read(workoutDataType)
            .enableServerQueries()
            .aggregate(caloriesDataType)
            .aggregate(activityDataType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .bucketByActivitySegment(20, TimeUnit.MINUTES) // It's not a workout if it's less than 20 minutes
            .build()

        val outputList = mutableListOf<Map<String, Any>>()

        Fitness.getHistoryClient(currentActivity, gsa).readData(request)
            .addOnSuccessListener { response ->
                val caloriesExpendedField = caloriesDataType.fields[0]
                val activityField = activitySummaryDataType.fields[0]

                response.buckets.forEach {
                    val activityDataPoint =
                        it.getDataSet(activitySummaryDataType)?.dataPoints?.lastOrNull()
                    val workoutType =
                        activityDataPoint?.getValue(activityField)?.asInt() ?: unknownActivityType

                    if (workoutType !in listOf(
                            unknownActivityType,
                            stillActivityType,
                            carActivityType
                        )
                    ) {
                        val caloriesDataPoint =
                            it.getDataSet(caloriesDataType)?.dataPoints?.lastOrNull()

                        val workoutActivity = it.activity
                        val workoutStart = it.getStartTime(TimeUnit.MILLISECONDS)
                        val workoutEnd = it.getEndTime(TimeUnit.MILLISECONDS)
                        val workoutEnergy =
                            caloriesDataPoint?.getValue(caloriesExpendedField)?.asFloat()
                        val workoutSource = caloriesDataPoint?.originalDataSource?.appPackageName
                            ?: caloriesDataPoint?.dataSource?.appPackageName
                        val workoutUID = "$workoutActivity-$workoutStart-$workoutEnd"

                        Log.i(
                            logTag, "Workout data data:" +
                                    "\n Name: $workoutActivity" +
                                    "\n Activity type: $workoutType" +
                                    "\n Session start: ${Date(workoutStart)}" +
                                    "\n Session end: ${Date(workoutEnd)}" +
                                    "\n Session id: $workoutUID" +
                                    "\n Calories spent: $workoutEnergy" +
                                    "\n Reported from: $workoutSource"
                        )

                        createWorkoutMap(
                            type = workoutType,
                            id = workoutUID,
                            start = workoutStart,
                            end = workoutEnd,
                            energy = workoutEnergy,
                            source = workoutSource,
                        ).also { workout -> outputList.add(workout) }
                    }
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

    private fun createWorkoutMap(
        type: Int,
        id: String,
        start: Long,
        end: Long,
        energy: Float?,
        source: String?,
    ): Map<String, Any> {

        val map = mutableMapOf(
            "id" to id,
            "type" to type,
            "start" to start,
            "end" to end,
        )

        energy?.let {
            map["energy"] = it
        }

        source?.let {
            map["source"] = it
        }

        return map
    }
}