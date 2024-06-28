package com.kcl.plugin;

import java.util.Map;

public class Plugin {
    public String name;
    public Map<String, MethodFunction> methodMap;

    public Map<String, MethodFunction> getMethodMap() {
        return methodMap;
    }

    public Plugin(String name, Map<String, MethodFunction> methodMap) {
        this.name = name;
        this.methodMap = methodMap;
    }
}
