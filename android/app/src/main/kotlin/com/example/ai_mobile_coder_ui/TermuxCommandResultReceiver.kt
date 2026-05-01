package com.yuandex

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TermuxCommandResultReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        RuntimeBackendsManager.onTermuxCommandResult(intent)
    }
}
