namespace KclLib.Plugin;

using System;
using System.Collections.Generic;
using Newtonsoft.Json;

public delegate object MethodFunction(object[] args, Dictionary<string, object> kwargs);

public class PluginContext
{
    private Dictionary<string, Plugin> pluginMap = new Dictionary<string, Plugin>();
    private JsonSerializerSettings jsonSettings;

    public PluginContext()
    {
        jsonSettings = new JsonSerializerSettings
        {
            TypeNameHandling = TypeNameHandling.Auto
        };
    }

    public string CallMethod(string name, string argsJson, string kwArgsJson)
    {
        return CallJavaMethod(name, argsJson, kwArgsJson);
    }

    private string CallJavaMethod(string name, string argsJson, string kwArgsJson)
    {
        try
        {
            return CallJavaMethodUnsafe(name, argsJson, kwArgsJson);
        }
        catch (Exception e)
        {
            var panicInfo = new Dictionary<string, string>
                {
                    { "__kcl_PanicInfo__", e.Message },
                };
            return ConvertToJson(panicInfo);
        }
    }

    private string CallJavaMethodUnsafe(string name, string argsJson, string kwArgsJson)
    {
        int dotIdx = name.LastIndexOf(".");
        if (dotIdx < 0)
        {
            return "";
        }
        string modulePath = name.Substring(0, dotIdx);
        string methodName = name.Substring(dotIdx + 1);
        string pluginName = modulePath.Substring(modulePath.LastIndexOf(".") + 1);

        if (pluginMap.TryGetValue(pluginName, out Plugin plugin))
        {
            if (plugin.MethodMap.TryGetValue(methodName, out MethodFunction methodFunc))
            {
                object[] args = ConvertFromJson<object[]>(argsJson);
                Dictionary<string, object> kwArgs = ConvertFromJson<Dictionary<string, object>>(kwArgsJson);
                object result = null;
                if (methodFunc != null)
                {
                    result = methodFunc.Invoke(args, kwArgs);
                }
                return ConvertToJson(result);
            }
        }
        return "";
    }

    public void RegisterPlugin(string name, Dictionary<string, MethodFunction> methodMap)
    {
        pluginMap[name] = new Plugin(name, methodMap);
    }

    private string ConvertToJson(object obj)
    {
        try
        {
            return JsonConvert.SerializeObject(obj, jsonSettings);
        }
        catch (JsonException e)
        {
            Console.WriteLine(e);
            return "";
        }
    }

    private T ConvertFromJson<T>(string json)
    {
        try
        {
            return JsonConvert.DeserializeObject<T>(json, jsonSettings);
        }
        catch (JsonException e)
        {
            Console.WriteLine(e);
            return default;
        }
    }
}
