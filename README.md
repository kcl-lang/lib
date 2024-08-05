# KCL Multiple Language Bindings and SDKs

This repo mainly includes the binding of the low-level API and spec of the [KCL language core](https://github.com/kcl-lang/kcl), and the SDKs of various languages are based on this to encapsulate higher-level APIs.

## Bindings

### Rust

```shell
cargo add --git https://github.com/kcl-lang/lib
```

Write the Code

```rust
use kcl_lang::*;
use anyhow::Result;

fn main() -> Result<()> {
    let api = API::default();
    let args = &ExecProgramArgs {
        k_filename_list: vec!["main.k".to_string()],
        k_code_list: vec!["a = 1".to_string()],
        ..Default::default()
    };
    let exec_result = api.exec_program(args)?;
    println!("{}", exec_result.yaml_result);
    Ok(())
}
```

More Rust APIs can be found [here](https://github.com/kcl-lang/kcl). If you want to use the sub crate of KCL Rust core, you can run the following command.

```shell
# Take the kclvm-runtime as an example.
cargo add --git https://github.com/kcl-lang/kcl kclvm-runtime
```

### Go

```shell
go get kcl-lang.io/lib
```

Write the Code

```go
package main

import (
	"kcl-lang.io/lib/go/install"
)

func main() {
    path = "path/to/install/lib"
    _ := install.InstallKclvm(path)
}
```

Full Go SDK can be found [here](https://github.com/kcl-lang/kcl-go), which depends on the `kcl-lang/lib` Go bindings.

### Java

Refer to [this](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-apache-maven-registry#authenticating-to-github-packages) to configure your Maven; set up your GitHub account and Token in the `settings.xml`.

#### Maven

In your project's pom.xml, configure our repository as follows:

```xml
<repositories>
    <repository>
        <id>github</id>
        <url>https://maven.pkg.github.com/kcl-lang/*</url>
        <snapshots>
            <enabled>true</enabled>
        </snapshots>
    </repository>
</repositories>
```

This way you'll be able to import the above dependency to use the SDK.

```xml
<dependency>
    <groupId>com.kcl</groupId>
    <artifactId>kcl-lib</artifactId>
    <version>0.10.0-alpha.2-SNAPSHOT</version>
</dependency>
```

Write the code

```java
import com.kcl.api.API;
import com.kcl.api.Spec.ExecProgram_Args;
import com.kcl.api.Spec.ExecProgram_Result;

public class ExecProgramTest {
    public static void main(String[] args) throws Exception {
        API api = new API();
        ExecProgram_Result result = api
                .execProgram(ExecProgram_Args.newBuilder().addKFilenameList("path/to/kcl.k").build());
        System.out.println(result.getYamlResult());
    }
}
```

### .NET

```shell
dotnet add package KclLib
```

Write the code

```cs
using KclLib.API;

var api = new API();
var execArgs = new ExecProgram_Args();
var path = Path.Combine("test_data", "schema.k");
execArgs.KFilenameList.Add(path);
var result = api.ExecProgram(execArgs);
Console.WriteLine(result.YamlResult);
```

### Python

```shell
python3 -m pip install kcl-lib
```

Write the code

```python
import kcl_lib.api as api

args = api.ExecProgram_Args(k_filename_list=["./tests/test_data/schema.k"])
api = api.API()
result = api.exec_program(args)
print(result.yaml_result)
```

### Node.js

```shell
npm install kcl-lib
```

Write the code

```ts
import { execProgram, ExecProgramArgs } from 'kcl-lib'

function main() {
  const result = execProgram(new ExecProgramArgs(['__test__/test_data/schema.k']))
  console.log(result.yamlResult)
}

main();
```

### Kotlin

```kotlin
import com.kcl.api.API
import com.kcl.api.execProgramArgs

val args = execProgramArgs { kFilenameList += "schema.k" }
val api = API()
val result = api.execProgram(args)
```

### Swift

```swift
import KclLib

let api = API()
var execArgs = ExecProgram_Args()
execArgs.kFilenameList.append("schema.k")
let result = try api.execProgram(execArgs)
```

### C++

For CMake, you can use FetchContent to add KCL C++ Lib to your project.

```shell
FetchContent_Declare(
  kcl-lib
  GIT_REPOSITORY https://github.com/kcl-lang/lib.git
  GIT_TAG        v0.10.0-alpha.2
  SOURCE_SUBDIR  cpp
)
FetchContent_MakeAvailable(kcl-lib)
```

Or you can download the source code and add it to your project.

```shell
mkdir third_party
cd third_party
git clone https://github.com/kcl-lang/lib.git
```

```shell
add_subdirectory(third_party/lib/cpp)
```

```shell
target_link_libraries(your_target kcl-lib-cpp)
```

Write the code

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ExecProgramArgs {
        .k_filename_list = { "../test_data/schema.k" },
    };
    auto result = kcl_lib::exec_program(args);
    std::cout << result.yaml_result.c_str() << std::endl;
    return 0;
}
```

### C

See [here](./c/)

### WASM

See [here](./wasm/)

## Documents

See [here](https://www.kcl-lang.io/docs/reference/xlang-api/overview)

## License

[![FOSSA Status](https://app.fossa.com/api/projects/git%2Bgithub.com%2Fkcl-lang%2Flib.svg?type=large)](https://app.fossa.com/projects/git%2Bgithub.com%2Fkcl-lang%2Flib?ref=badge_large)
