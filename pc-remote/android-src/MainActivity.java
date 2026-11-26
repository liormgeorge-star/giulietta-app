package com.liorg.pcremote;

import android.os.Bundle;
import com.getcapacitor.BridgeActivity;

public class MainActivity extends BridgeActivity {
    @Override
    public void onCreate(Bundle savedInstanceState) {
        registerPlugin(PcRemotePlugin.class);
        super.onCreate(savedInstanceState);
    }
}
