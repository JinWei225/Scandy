package com.jinwei.scandy;

import android.content.Intent;
import android.util.Log;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onNewIntent(Intent intent) {
        Log.d("MainActivity", "onNewIntent called with action: " + (intent != null ? intent.getAction() : "null"));
        super.onNewIntent(intent);
        setIntent(intent); // Important to update the activity intent for plugins to see it
    }
}
