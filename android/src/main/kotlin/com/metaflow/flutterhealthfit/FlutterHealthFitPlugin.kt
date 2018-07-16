package com.metaflow.flutterhealthfit

import android.app.Activity
import android.widget.Toast
import com.google.android.gms.auth.api.signin.GoogleSignIn
import com.google.android.gms.fitness.FitnessOptions
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.PluginRegistry.Registrar

import com.google.android.gms.fitness.data.DataType

class FlutterHealthFitPlugin(val activity: Activity): MethodCallHandler {

  companion object {
    @JvmStatic
    fun registerWith(registrar: Registrar) {
      val channel = MethodChannel(registrar.messenger(), "flutter_health_fit")
      channel.setMethodCallHandler(FlutterHealthFitPlugin(registrar.activity()))
    }
  }

  override fun onMethodCall(call: MethodCall, result: Result) {

    Toast.makeText(activity, call.method, Toast.LENGTH_SHORT).show()

    when (call.method) {
      "getPlatformVersion" -> result.success("Android ${android.os.Build.VERSION.RELEASE}")

      "requestAuthorization" -> result.success(true)

      "getBasicHealthData" -> result.success("Android got getBasicHealthData")

      else -> result.notImplemented()
    }
  }

//  private fun connectGoogleFit() {
//
//
//    val fitnessOptions = FitnessOptions.builder()
//            .addDataType(DataType.TYPE_STEP_COUNT_DELTA, FitnessOptions.ACCESS_READ)
//            .addDataType(DataType.AGGREGATE_STEP_COUNT_DELTA, FitnessOptions.ACCESS_READ)
//            .build()
//
//    if (!GoogleSignIn.hasPermissions(GoogleSignIn.getLastSignedInAccount(this), fitnessOptions)) {
//      GoogleSignIn.requestPermissions(
//              this, // your activity
//              GOOGLE_FIT_PERMISSIONS_REQUEST_CODE,
//              GoogleSignIn.getLastSignedInAccount(this),
//              fitnessOptions);
//    } else {
//      accessGoogleFit();
//    }
//  }
}
