package com.metaflow.flutterhealthfit

import android.app.Activity
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessActivities
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Field
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
            FitnessOptions.builder().addDataType(DataType.TYPE_WORKOUT_EXERCISE).build()
    }

    private val logTag = WorkoutsReader::class.java.simpleName
    private val unknownActivityType: Int = 4
    private val stillActivityType: Int = 3
    private val carActivityType: Int = 0
    private val walkingActivityType: Int = 7
    private val runningActivityType: Int = 8


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
            .bucketByActivitySegment(1, TimeUnit.MINUTES)
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
                        val durationInMinutes = (workoutEnd - workoutStart) / 60000
                        Log.i(
                            logTag, "Workout data data:" +
                                    "\n duration: $durationInMinutes" +
                                    "\n Name: $workoutActivity" +
                                    "\n Activity type: $workoutType" +
                                    "\n Session start: ${Date(workoutStart)}" +
                                    "\n Session end: ${Date(workoutEnd)}" +
                                    "\n Session id: $workoutUID" +
                                    "\n Calories spent: $workoutEnergy" +
                                    "\n Reported from: $workoutSource"
                        )
                        if (durationInMinutes > 15 ||
                            (workoutType != walkingActivityType && workoutType != runningActivityType) ) {
                            // we don't want to log walks and runs that are less than 15 minutes
                            Log.i(logTag, "logged workout")
                            createWorkoutMap(
                                type = workoutType,
                                duration = null,
                                id = workoutUID,
                                start = workoutStart,
                                end = workoutEnd,
                                energy = workoutEnergy,
                                source = workoutSource,
                            ).also { workout -> outputList.add(workout) }
                        }
                        else {
                            Log.i(logTag, "workout was not logged")
                        }
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

    fun getWorkoutsSessions(
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
            .read(DataType.TYPE_WORKOUT_EXERCISE)
            .enableServerQueries()
            .aggregate(DataType.TYPE_CALORIES_EXPENDED)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .bucketBySession(1, TimeUnit.MINUTES)
            .build()

        val outputList = mutableListOf<Map<String, Any>>()

        Fitness.getHistoryClient(currentActivity, gsa).readData(request)
            .addOnSuccessListener { response ->
                response.buckets.forEach {
                    if (it.session == null) {
                        Log.w(logTag, "Failed to analyse session bucket: Session is null")
                        return@forEach
                    }
                    val session = it.session!!

                    if (session.activity !in listOf(
                            FitnessActivities.UNKNOWN,
                            FitnessActivities.STILL,
                            FitnessActivities.IN_VEHICLE
                        )
                    ) {
                        val caloriesDataPoint =
                            it.getDataSet(DataType.TYPE_CALORIES_EXPENDED)?.dataPoints?.lastOrNull()

                        val workoutStart = it.getStartTime(TimeUnit.MILLISECONDS)
                        val workoutEnd = it.getEndTime(TimeUnit.MILLISECONDS)
                        val workoutEnergy =
                            caloriesDataPoint?.getValue(Field.FIELD_CALORIES)?.asFloat()
                        val workoutSource = caloriesDataPoint?.originalDataSource?.appPackageName
                            ?: caloriesDataPoint?.dataSource?.appPackageName
                        val durationInMinutes = session.getActiveTime(TimeUnit.MINUTES).toInt()
                        Log.i(
                            logTag, "Workout data:" +
                                    "\n Name: ${session.name}" +
                                    "\n Id: ${session.identifier}" +
                                    "\n Activity type: ${session.activity}" +
                                    "\n Session start: ${Date(workoutStart)}" +
                                    "\n Session end: ${Date(workoutEnd)}" +
                                    "\n Duration: $durationInMinutes" +
                                    "\n Calories spent: $workoutEnergy" +
                                    "\n Reported from: $workoutSource"
                        )
                        if (session.getActiveTime(TimeUnit.MINUTES) > 15 ||
                            (session.activity != FitnessActivities.WALKING
                                    && session.activity != FitnessActivities.RUNNING)
                        ) {
                            // we don't want to log walks and runs that are less than 15 minutes
                            Log.i(logTag, "logged workout")
                            createWorkoutMap(
                                type = session.activity,
                                id = session.identifier,
                                start = workoutStart,
                                end = workoutEnd,
                                duration = durationInMinutes,
                                energy = workoutEnergy,
                                source = workoutSource,
                            ).also { workout -> outputList.add(workout) }
                        } else {
                            Log.i(logTag, "workout session was not logged")
                        }
                    }
                }

                if (outputList.isEmpty()) {
                    result(null, null)
                } else {
                    result(outputList, null)
                }
            }
            .addOnFailureListener { e ->
                Log.d(logTag, "failed to fetch workouts data $e")
                result(null, e)
            }
    }

    private fun createWorkoutMap(
        type: Any,
        id: String,
        start: Long,
        end: Long,
        duration: Int?,
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

        duration?.let {
            map["duration"] = it
        }

        source?.let {
            map["source"] = it
        }

        return map
    }
}