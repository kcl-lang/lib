namespace KclLib.Plugin;

public class Plugin
{
    public string Name { get; set; }
    public Dictionary<string, MethodFunction> MethodMap { get; set; }

    public Plugin(string name, Dictionary<string, MethodFunction> methodMap)
    {
        Name = name;
        MethodMap = methodMap;
    }
}
