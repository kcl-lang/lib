# KCL Artifact Library for C++

This repo is under development, PRs welcome!

## How to Use

### CMake

You can use FetchContent to add KCL C++ Lib to your project.

```shell
FetchContent_Declare(
  kcl-lib
  GIT_REPOSITORY https://github.com/kcl-lang/lib.git
  GIT_TAG        v0.9.2
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

## Developing

**Prerequisites**

+ CMake >= 3.10
+ C++ Compiler with C++17 Support
+ Cargo

```shell
export MACOSX_DEPLOYMENT_TARGET='10.13'
mkdir build
cd build
cmake ..
make
```

## Examples

+ ExecProgram

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int main()
{
    auto args = kcl_lib::ExecProgramArgs();
    auto files = rust::Vec<rust::String>();
    files.push_back(rust::String("../test_data/schema.k"));
    args.k_filename_list = files;
    auto result = kcl_lib::exec_program(args);
    std::cout << result.yaml_result.c_str() << std::endl;
}
```

Run the ExecProgram example.

```shell
./exec_api
```

+ ValidateCode

```cpp
#include "kcl_lib.hpp"
#include <iostream>

int validate(const char* code_str, const char* data_str) {
    auto args = kcl_lib::ValidateCodeArgs();
    args.code = rust::String(code_str);
    args.data = rust::String(data_str);
    auto result = kcl_lib::validate_code(args);
    std::cout << result.success << std::endl;
    std::cout << result.err_message.c_str() << std::endl;
    return 0;
}

int main()
{
    const char* code_str = "schema Person:\n"
                           "    name: str\n"
                           "    age: int\n"
                           "    check:\n"
                           "        0 < age < 120\n";
    const char* data_str = "{\"name\": \"Alice\", \"age\": 10}";
    const char* error_data_str = "{\"name\": \"Alice\", \"age\": 1110}";
    validate(code_str, data_str);
    validate(code_str, error_data_str);
    return 0;
}
```

Run the ValidateAPI example.

```shell
./validate_api
```
