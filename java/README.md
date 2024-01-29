# KCL Artifact Library for Java

## Example

```java
import com.kcl.api.API;
import com.kcl.api.Spec.*;
import com.kcl.ast.Program;
import com.kcl.util.JsonUtil;

public class Main {
    public void testProgramSymbols() throws Exception {
        API api = new API();
        LoadPackage_Result result = api.loadPackage(
                LoadPackage_Args.newBuilder().setResolveAst(true).setParseArgs(
                        ParseProgram_Args.newBuilder().addPaths("./src/test_data/schema.k").build())
                        .build());
        String programString = result.getProgram();
        Program program = JsonUtil.deserializeProgram(programString);
        result.getSymbolsMap().values().forEach(s -> System.out.println(s));
    }
}
```

## Getting Started

This project is built upon the native KCL core library, and it is released for multiple platforms you can use a classifier to specify the platform you are building the application on.

### Maven

Generally, you can first add the `os-maven-plugin` to automatically detect the classifier based on your platform:

```xml
<build>
<extensions>
  <extension>
    <groupId>kr.motd.maven</groupId>
    <artifactId>os-maven-plugin</artifactId>
    <version>1.7.0</version>
  </extension>
</extensions>
</build>
```

Then add the dependency to `kcl-lib` as follows:

```xml
<dependencies>
<dependency>
  <groupId>com.kcl</groupId>
  <artifactId>kcl-lib</artifactId>
  <version>${kcl_lib.version}</version>
</dependency>
<dependency>
  <groupId>com.kcl</groupId>
  <artifactId>kcl-lib</artifactId>
  <version>${kcl_lib.version}</version>
  <classifier>${os.detected.classifier}</classifier>
</dependency>
</dependencies>
```

### Gradle

For Gradle, you can first add the `com.google.osdetector` to automatically detect the classifier based on your platform:


```groovy
plugins {
    id "com.google.osdetector" version "1.7.3"
}
```

Then add the dependency to `kcl-lib` as follows:

```groovy
dependencies {
    implementation "com.kcl:kcl-lib:0.7.5"
    implementation "com.kcl:kcl-lib:0.7.5:$osdetector.classifier"
}
```

### Classified Library

Note that the dependency without classifier ships all classes and resources except the `kcl-lib` shared library. And those with classifier bundle only the shared library.

For downstream usage, it's recommended:

+ Depends on the one without the classifier to write code;
+ Depends on the classified ones with "test" for testing.

To load the shared library correctly, you can choose one of the following approaches:

+ Append the classified JARs to the classpath at the runtime;
+ Depend on the classified JARs and build a fat JAR (You may need to depend on all the provided classified JARs for running on multiple platforms);
+ Build your own `kcl-lib` shared library and specify `-Djava.library.path` to the folder containing that shared library using the `make` command.

## Developing

+ Install Python3
+ Install Rust
+ Install Java8+
+ Install Maven
