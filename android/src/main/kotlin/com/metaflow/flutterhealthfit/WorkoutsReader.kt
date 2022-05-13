package com.metaflow.flutterhealthfit

import android.Manifest
import android.app.Activity
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.request.DataReadRequest
import java.util.*
import java.util.concurrent.TimeUnit

const val MY_PERMISSIONS_REQUEST_ACTIVITY_RECOGNITION = 12

class WorkoutsReader {
    companion object {
        private val activityDataType = DataType.TYPE_ACTIVITY_SEGMENT
        private val workoutDataType = DataType.TYPE_WORKOUT_EXERCISE
        private val caloriesDataType = DataType.TYPE_CALORIES_EXPENDED
        private val distanceDataType = DataType.TYPE_DISTANCE_DELTA
        private val activitySummaryDataType = DataType.AGGREGATE_ACTIVITY_SUMMARY
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
        if (currentActivity == null || !checkPermission(currentActivity)) {
            result(null, null)
            return
        }

        val gsa = GoogleSignIn.getAccountForExtension(
            currentActivity,
            FlutterHealthFitPlugin.getFitnessOptions(workoutDataType)
        )

        val request = DataReadRequest.Builder()
            .read(workoutDataType)
            .enableServerQueries()
            .aggregate(caloriesDataType)
            .aggregate(distanceDataType)
            .aggregate(activityDataType)
            .setTimeRange(startTime, endTime, TimeUnit.MILLISECONDS)
            .bucketByActivitySegment(1, TimeUnit.MINUTES)
            .build()

        val outputList = mutableListOf<Map<String, Any>>()

        Fitness.getHistoryClient(currentActivity, gsa).readData(request)
            .addOnSuccessListener { response ->
                val caloriesExpendedField = caloriesDataType.fields[0]
                val distanceDeltaField = distanceDataType.fields[0]
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
                        val distanceDataPoint =
                            it.getDataSet(distanceDataType)?.dataPoints?.lastOrNull()

                        val workoutActivity = it.activity
                        val workoutStart = it.getStartTime(TimeUnit.MILLISECONDS)
                        val workoutEnd = it.getEndTime(TimeUnit.MILLISECONDS)
                        val workoutDistance =
                            distanceDataPoint?.getValue(distanceDeltaField)?.asFloat()
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
                                    "\n Distance: $workoutDistance" +
                                    "\n Calories spent: $workoutEnergy" +
                                    "\n Reported from: $workoutSource"
                        )
                        if (durationInMinutes > 15 ||
                            (workoutType != walkingActivityType && workoutType != runningActivityType)
                        ) {
                            // we don't want to log walks and runs that are less than 15 minutes
                            Log.i(logTag, "logged workout")
                            createWorkoutMap(
                                type = workoutType,
                                id = workoutUID,
                                start = workoutStart,
                                end = workoutEnd,
                                distance = workoutDistance,
                                energy = workoutEnergy,
                                source = workoutSource,
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

    private fun createWorkoutMap(
        type: Int,
        id: String,
        start: Long,
        end: Long,
        distance: Float?,
        energy: Float?,
        source: String?,
    ): Map<String, Any> {

        val map = mutableMapOf(
            "id" to id,
            "type" to type,
            "start" to start,
            "end" to end,
        )

        distance?.let {
            map["distance"] = it
        }

        energy?.let {
            map["energy"] = it
        }

        source?.let {
            map["source"] = it
        }

        return map
    }

    private fun checkPermission(currentActivity: Activity): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(currentActivity, Manifest.permission.ACTIVITY_RECOGNITION)
            != PackageManager.PERMISSION_GRANTED
        ) {
            ActivityCompat.requestPermissions(
                currentActivity,
                arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
                MY_PERMISSIONS_REQUEST_ACTIVITY_RECOGNITION
            )
            return false
        }
        return true
    }
}