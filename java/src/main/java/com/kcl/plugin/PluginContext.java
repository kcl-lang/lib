package com.kcl.plugin;

import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.core.JsonProcessingException;
import java.util.HashMap;
import java.util.Map;

public class PluginContext {
    private Map<String, Plugin> pluginMap = new HashMap<>();
    private ObjectMapper objectMapper = new ObjectMapper();

    public String callMethod(String name, String argsJson, String kwArgsJson) {
        return callJavaMethod(name, argsJson, kwArgsJson);
    }

    private String callJavaMethod(String name, String argsJson, String kwArgsJson) {
        try {
            return callJavaMethodUnsafe(name, argsJson, kwArgsJson);
        } catch (Exception e) {
            Map<String, String> panicInfo = new HashMap<>();
            panicInfo.put("__kcl_PanicInfo__", e.getMessage());
            return convertToJson(panicInfo);
        }
    }

    private String callJavaMethodUnsafe(String name, String argsJson, String kwArgsJson) {
        int dotIdx = name.lastIndexOf(".");
        if (dotIdx < 0) {
            return "";
        }
        String modulePath = name.substring(0, dotIdx);
        String methodName = name.substring(dotIdx + 1);
        String pluginName = modulePath.substring(modulePath.lastIndexOf(".") + 1);

        MethodFunction methodFunc = this.pluginMap.getOrDefault(pluginName, new Plugin("", new HashMap<>()))
                .getMethodMap().get(methodName);

        Object[] args = convertFromJson(argsJson, Object[].class);
        Map<String, Object> kwArgs = convertFromJson(kwArgsJson, HashMap.class);

        Object result = null;
        if (methodFunc != null) {
            result = methodFunc.invoke(args, kwArgs);
        }

        return convertToJson(result);
    }

    public void registerPlugin(String name, Map<String, MethodFunction> methodMap) {
        this.pluginMap.put(name, new Plugin(name, methodMap));
    }

    private String convertToJson(Object object) {
        try {
            return objectMapper.writeValueAsString(object);
        } catch (JsonProcessingException e) {
            e.printStackTrace();
            return "";
        }
    }

    private <T> T convertFromJson(String json, Class<T> type) {
        try {
            return objectMapper.readValue(json, type);
        } catch (JsonProcessingException e) {
            e.printStackTrace();
            return null;
        }
    }
}
