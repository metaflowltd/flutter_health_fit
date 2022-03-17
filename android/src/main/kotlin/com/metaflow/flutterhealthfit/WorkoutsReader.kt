package com.metaflow.flutterhealthfit

import android.app.Activity
import android.util.Log
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.Fitness
import com.google.android.gms.fitness.FitnessOptions
import com.google.android.gms.fitness.data.DataType
import com.google.android.gms.fitness.data.Session
import com.google.android.gms.fitness.request.SessionReadRequest
import java.util.*
import java.util.concurrent.TimeUnit

class WorkoutsReader {

    private val logTag = WorkoutsReader::class.java.simpleName
    private val unknownActivityType: Int = 4
    private val stillActivityType: Int = 3
    private val carActivityType: Int = 0

    fun getWorkouts(
        currentActivity: Activity?,
        startTime: Long,
        endTime: Long,
        result: (List<Map<String, Any>>?, Throwable?) -> Unit
    ) {
        if (currentActivity == null) {
            result(null, null)
            return
        }

        // Build a session read request
        val readRequest = SessionReadRequest.Builder()
            .setTimeInterval(startTime, endTime, TimeUnit.MILLISECONDS)
            .read(DataType.TYPE_CALORIES_EXPENDED)
            .read(DataType.AGGREGATE_ACTIVITY_SUMMARY)
            .includeActivitySessions()
            .enableServerQueries()
            .readSessionsFromAllApps()
            .build()

        val account = GoogleSignIn.getLastSignedInAccount(currentActivity) ?: return

        Fitness.getSessionsClient(currentActivity, account)
            .readSession(readRequest)
            .addOnSuccessListener { response ->

                val sessions = response.sessions.filter {
                    it.getActivityTypeByReflection() !in listOf(
                        unknownActivityType,
                        stillActivityType,
                        carActivityType
                    )
                }

                val outputList = mutableListOf<Map<String, Any>>()

                for (session in sessions) {

                    val caloriesInTotal =
                        response.getDataSet(session, DataType.TYPE_CALORIES_EXPENDED)
                            .firstOrNull()?.dataPoints?.map { dataPoint ->
                                dataPoint.getValue(DataType.TYPE_CALORIES_EXPENDED.fields[0]).asFloat()
                            }?.reduce { acc, value ->
                                acc + value
                            }

                    val activityType = session.getActivityTypeByReflection()

                    Log.i(
                        logTag, "Session data:" +
                                "\n Name: ${session.activity}" +
                                "\n Activity type: $activityType" +
                                "\n Session start: $startTime" +
                                "\n Session end: $endTime" +
                                "\n Session id: ${session.identifier}" +
                                "\n Calories spent: $caloriesInTotal" +
                                "\n Reported from: ${session.appPackageName}"
                    )

                    createWorkoutMap(
                        type = activityType,
                        id = session.identifier,
                        start = session.getStartTime(TimeUnit.MILLISECONDS),
                        end = session.getEndTime(TimeUnit.MILLISECONDS),
                        energy = caloriesInTotal,
                        source = session.appPackageName,
                    ).also { outputList.add(it) }
                }

                if (outputList.isEmpty()) {
                    result(null, null)
                } else {
                    result(outputList, null)
                }
            }
            .addOnFailureListener { e ->
                Log.e(logTag, "Failed to read session", e)
                result(null, e)
            }
    }

    private fun Session.getActivityTypeByReflection(): Int {
        return javaClass.getDeclaredField("zzlg").let {
            it.isAccessible = true
            return@let it.getInt(this)
        }
    }

    private fun createWorkoutMap(
        type: Int,
        id: String,
        start: Long,
        end: Long,
        energy: Float?,
        source: String?
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