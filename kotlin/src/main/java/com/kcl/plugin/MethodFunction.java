package com.kcl.plugin;

import java.util.Map;

@FunctionalInterface
public interface MethodFunction {
    Object invoke(Object[] args, Map<String, Object> kwArgs);
}
