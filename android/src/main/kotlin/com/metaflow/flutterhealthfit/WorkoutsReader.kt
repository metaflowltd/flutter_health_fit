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
import com.google.android.gms.fitness.request.SessionReadRequest
import java.util.Date
import java.util.concurrent.TimeUnit

class WorkoutsReader {
    companion object {
        private val activityDataType = DataType.TYPE_ACTIVITY_SEGMENT
        private val workoutDataType = DataType.TYPE_WORKOUT_EXERCISE
        private val caloriesDataType = DataType.TYPE_CALORIES_EXPENDED
        private val aggregatedStepsType: DataType = DataType.AGGREGATE_STEP_COUNT_DELTA
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
            .aggregate(aggregatedStepsType)
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
                    val steps = it.getDataSet(aggregatedStepsType)?.dataPoints?.firstOrNull()
                        ?.getValue(Field.FIELD_STEPS)?.asInt()

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
                                    "\n Reported from: $workoutSource" +
                                    "\n Steps: $steps"
                        )
                        if (durationInMinutes > 15 ||
                            (workoutType != walkingActivityType && workoutType != runningActivityType)
                        ) {
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
                                steps = steps,
                            ).also { workout -> outputList.add(workout) }
                        } else {
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


        val readRequest = SessionReadRequest.Builder()
            .setTimeInterval(startTime, endTime, TimeUnit.MILLISECONDS)
            .read(DataType.TYPE_ACTIVITY_SEGMENT)
            .read(DataType.TYPE_CALORIES_EXPENDED)
            .read(DataType.AGGREGATE_STEP_COUNT_DELTA)
            .readSessionsFromAllApps()
            .includeActivitySessions()
            .build()

        val outputList = mutableListOf<Map<String, Any>>()

        Fitness.getSessionsClient(currentActivity, gsa)
            .readSession(readRequest)
            .addOnSuccessListener { response ->
                // Get a list of the sessions that match the criteria to check the result.
                val sessions = response.sessions
                Log.i(logTag, "Number of returned sessions is: ${sessions.size}")

                for (session in sessions) {
                    if (session.isOngoing) {
                        Log.i(logTag, "An ongoing workout session skipped")
                        continue
                    }

                    if (session.activity !in listOf(
                            FitnessActivities.UNKNOWN,
                            FitnessActivities.STILL,
                            FitnessActivities.IN_VEHICLE,
                            FitnessActivities.SLEEP,
                        )
                    ) {
                        // Process the session
                        var steps = 0
                        var workoutEnergy = 0.0f
                        val workoutSource = session.appPackageName
                        val sessionStart =
                            session.getStartTime(TimeUnit.MILLISECONDS)
                        val sessionEnd =
                            session.getEndTime(TimeUnit.MILLISECONDS)
                        val sessionActiveTime = if (session.hasActiveTime()) {
                            session.getActiveTime(TimeUnit.MINUTES).toInt()
                        } else {
                            null
                        }
                        val sessionTotalDuration =
                            (sessionEnd - sessionStart) / 60000

                        for (dataSet in response.getDataSet(session)) {
                            if (dataSet.dataType == DataType.TYPE_CALORIES_EXPENDED) {
                                for (dataPoint in dataSet.dataPoints) {
                                    workoutEnergy += dataPoint.getValue(Field.FIELD_CALORIES)
                                        .asFloat()
                                }
                            }
                            if (dataSet.dataType == aggregatedStepsType) {
                                for (dataPoint in dataSet.dataPoints) {
                                    steps += dataPoint.getValue(Field.FIELD_STEPS)
                                        .asInt()
                                }
                            }
                        }

                        Log.i(
                            logTag, "Session data:" +
                                    "\n Name: ${session.name}" +
                                    "\n Id: ${session.identifier}" +
                                    "\n Activity type: ${session.activity}" +
                                    "\n Session start: ${Date(sessionStart)}" +
                                    "\n Session end: ${Date(sessionEnd)}" +
                                    "\n Duration: $sessionActiveTime" +
                                    "\n Calories spent: $workoutEnergy" +
                                    "\n Reported from: $workoutSource" +
                                    "\n Steps: $steps"
                        )
                        if ((sessionActiveTime != null && sessionActiveTime > 15) ||
                            sessionTotalDuration > 15 ||
                            (session.activity != FitnessActivities.WALKING
                                    && session.activity != FitnessActivities.RUNNING)
                        ) {
                            // we don't want to log walks and runs that are less than 15 minutes
                            Log.i(logTag, "logged workout session")
                            createWorkoutMap(
                                type = session.activity,
                                id = session.identifier,
                                start = sessionStart,
                                end = sessionEnd,
                                duration = sessionActiveTime,
                                energy = workoutEnergy,
                                source = workoutSource,
                                steps = steps,
                            ).also { workout -> outputList.add(workout) }
                        } else {
                            Log.i(logTag, "Skipped short walk/run session logging")
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
        steps: Int?,
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

        steps?.let {
            map["steps"] = it
        }

        return map
    }
}