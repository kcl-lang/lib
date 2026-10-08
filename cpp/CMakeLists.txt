cmake_minimum_required(VERSION 3.10)
project(kcl-lib VERSION 0.13.1 LANGUAGES C CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(KCL_LIB_ENABLE_TESTING "Enable building test binary" OFF)

# Optional nlohmann/json backend for kcl_facade.hpp. When found, the facade
# parses results into `nlohmann::ordered_json`; when not, it falls back to the
# bundled parser so the header keeps building with only a C++17 toolchain.
# Both paths are exercised by ctest (see the `facade` / `facade_bundled_json`
# targets below).
find_package(nlohmann_json QUIET)
if(nlohmann_json_FOUND)
    message(STATUS "kcl-lib-cpp: using nlohmann/json for the facade JSON backend")
else()
    message(STATUS "kcl-lib-cpp: nlohmann/json not found, using the bundled facade JSON parser")
endif()

# Get cargo target dir using cargo locate-project
# We should do this because the target dir is different for development and release
execute_process(COMMAND cargo locate-project --workspace --message-format plain
    OUTPUT_VARIABLE CARGO_TARGET_DIR
    WORKING_DIRECTORY ${PROJECT_SOURCE_DIR})
string(REGEX REPLACE "/Cargo.toml\n$" "/target" CARGO_TARGET_DIR "${CARGO_TARGET_DIR}")
set(CARGO_MANIFEST ${PROJECT_SOURCE_DIR}/Cargo.toml)
set(RUST_SOURCE_FILE ${PROJECT_SOURCE_DIR}/src/lib.rs)
set(RUST_BRIDGE_CPP ${CARGO_TARGET_DIR}/cxxbridge/kcl-lib-cpp/src/lib.rs.cc)
set(RUST_HEADER_FILE ${CARGO_TARGET_DIR}/cxxbridge/kcl-lib-cpp/src/lib.rs.h)
set(RUST_LIB ${CARGO_TARGET_DIR}/release/${CMAKE_STATIC_LIBRARY_PREFIX}kcl_lib_cpp${CMAKE_STATIC_LIBRARY_SUFFIX})
set(CPP_INCLUDE_DIR ${PROJECT_SOURCE_DIR}/include ${CARGO_TARGET_DIR}/cxxbridge/kcl-lib-cpp/src)
file(GLOB_RECURSE CPP_SOURCE_FILE src/*.cpp)
file(GLOB_RECURSE CPP_HEADER_FILE include/*.hpp)
file(GLOB_RECURSE EXAMPLE_SOURCE_FILE examples/*.cpp)

# Optional C typed-AST module. The C binding ships a self-contained
# `kcl_lib_ast.h` + `kcl_lib_ast.c` pair (no nanopb dependency) that
# parses the AST JSON emitted by `kcl_lib::parse_file`. The C++
# wrapper `kcl_lib_ast.hpp` is a thin RAII layer over those C types.
set(KCL_AST_C_DIR ${PROJECT_SOURCE_DIR}/../c)
set(KCL_AST_INCLUDE_DIR ${KCL_AST_C_DIR}/include)
set(KCL_AST_SOURCE ${KCL_AST_C_DIR}/lib/kcl_lib_ast.c)

add_library(kcl-lib-ast STATIC ${KCL_AST_SOURCE})
target_include_directories(kcl-lib-ast PUBLIC ${KCL_AST_INCLUDE_DIR})
set_target_properties(kcl-lib-ast PROPERTIES C_STANDARD 99)

add_custom_command(
    OUTPUT ${RUST_BRIDGE_CPP} ${RUST_LIB} ${RUST_HEADER_FILE}
    COMMAND cargo build --manifest-path ${CARGO_MANIFEST} --release
    USES_TERMINAL
    COMMENT "Running cargo build --release..."
)

add_library(kcl-lib-cpp STATIC ${CPP_SOURCE_FILE} ${RUST_BRIDGE_CPP})
target_sources(kcl-lib-cpp PUBLIC ${CPP_HEADER_FILE})
target_sources(kcl-lib-cpp PRIVATE ${RUST_HEADER_FILE})
target_include_directories(kcl-lib-cpp PUBLIC ${CPP_INCLUDE_DIR})
target_link_libraries(kcl-lib-cpp PUBLIC ${RUST_LIB})
target_link_libraries(kcl-lib-cpp PRIVATE ${CMAKE_DL_LIBS})
if(nlohmann_json_FOUND)
    # PUBLIC so the imported target's include directory reaches every
    # consumer of the facade header, which is what makes the header's own
    # `__has_include(<nlohmann/json.hpp>)` probe succeed.
    target_link_libraries(kcl-lib-cpp PUBLIC nlohmann_json::nlohmann_json)
endif()
set_target_properties(kcl-lib-cpp
        PROPERTIES ADDITIONAL_CLEAN_FILES ${CARGO_TARGET_DIR}
)

set(EXECUTABLES facade exec_api exec_with_deps_api override_api update_deps_api validate_api list_options_api get_version_api load_settings_files_api testing_api format_test_report_api rename_code_api rename_api lint_path_api format_path_api format_path_dry_run_api format_code_api get_schema_type_api schema_function_type_api list_variables_api load_package_api parse_file_api parse_program_api get_schema_type_under_path_api list_method_api ping_api ast_alignment ast_contract plugin_api generate_kcl_api generate_toml_api generate_openapi_api generate_proto_api generate_doc_api)
foreach(EXE IN LISTS EXECUTABLES)
    add_executable(${EXE} examples/${EXE}.cpp)
    target_include_directories(${EXE} PUBLIC ${CPP_INCLUDE_DIR})
    target_link_libraries(${EXE} PUBLIC kcl-lib-cpp)
    # The ast_alignment and ast_contract examples exercise the typed AST
    # module — link against `kcl-lib-ast` (compiled from the C binding's
    # `kcl_lib_ast.c`) so they can call `kcl_ast_parse_module`.
    if(EXE STREQUAL "ast_alignment" OR EXE STREQUAL "ast_contract")
        target_include_directories(${EXE} PUBLIC ${KCL_AST_INCLUDE_DIR})
        target_link_libraries(${EXE} PUBLIC kcl-lib-ast)
    endif()
    if(WIN32)
        target_link_libraries(${EXE} PRIVATE userenv ws2_32 bcrypt)
    endif()
    if(APPLE)
        find_library(CORESERVICES_LIB CoreServices)
        target_link_libraries(${EXE} PRIVATE ${CORESERVICES_LIB})
        target_link_libraries(${EXE} PRIVATE "-framework CoreFoundation -framework Security")
    endif()
endforeach()

# Platform-specific test configuration
if(WIN32)
    target_link_libraries(kcl-lib-cpp userenv ws2_32 bcrypt)
    set_target_properties(
            kcl-lib-cpp
            PROPERTIES
            MSVC_RUNTIME_LIBRARY "MultiThreadedDLL"
            RUNTIME_OUTPUT_DIRECTORY_DEBUG ${CMAKE_BINARY_DIR}
            RUNTIME_OUTPUT_DIRECTORY_RELEASE ${CMAKE_BINARY_DIR}
    )
endif()

# Assertion-based API test suite (tests/test_api.cpp, plain CHECK macro).
# Built and registered with ctest only when testing is enabled:
#   cmake -B build -DKCL_LIB_ENABLE_TESTING=ON
if(KCL_LIB_ENABLE_TESTING)
    enable_testing()
    add_executable(kcl_lib_api_tests tests/test_api.cpp)
    target_include_directories(kcl_lib_api_tests PUBLIC ${CPP_INCLUDE_DIR})
    target_link_libraries(kcl_lib_api_tests PUBLIC kcl-lib-cpp)
    target_compile_definitions(kcl_lib_api_tests PRIVATE
            KCL_TEST_DATA_DIR="${PROJECT_SOURCE_DIR}/test_data")
    if(WIN32)
        target_link_libraries(kcl_lib_api_tests PRIVATE userenv ws2_32 bcrypt)
    endif()
    if(APPLE)
        find_library(CORESERVICES_LIB CoreServices)
        target_link_libraries(kcl_lib_api_tests PRIVATE ${CORESERVICES_LIB})
        target_link_libraries(kcl_lib_api_tests PRIVATE "-framework CoreFoundation -framework Security")
    endif()
    add_test(NAME kcl_lib_api_tests COMMAND kcl_lib_api_tests)

    # Contract suite for the typed AST in include/kcl_ast.hpp. It decodes the
    # shared golden capture at testdata/ast/alignment.json and walks every
    # tag in it, and it parses a live fixture through the cxx bridge, so it
    # links kcl-lib-cpp rather than standing alone.
    add_executable(kcl_ast_tests tests/test_ast.cpp)
    target_include_directories(kcl_ast_tests PUBLIC ${CPP_INCLUDE_DIR})
    target_link_libraries(kcl_ast_tests PUBLIC kcl-lib-cpp)
    target_compile_definitions(kcl_ast_tests PRIVATE
            KCL_TEST_DATA_DIR="${PROJECT_SOURCE_DIR}/test_data"
            KCL_AST_FIXTURE="${PROJECT_SOURCE_DIR}/../testdata/ast/alignment.json")
    if(WIN32)
        target_link_libraries(kcl_ast_tests PRIVATE userenv ws2_32 bcrypt)
    endif()
    if(APPLE)
        find_library(CORESERVICES_LIB CoreServices)
        target_link_libraries(kcl_ast_tests PRIVATE ${CORESERVICES_LIB})
        target_link_libraries(kcl_ast_tests PRIVATE "-framework CoreFoundation -framework Security")
    endif()
    add_test(NAME kcl_ast_tests COMMAND kcl_ast_tests)

    # Cross-language consistency runner. It reads the shared golden manifest at
    # tests/consistency/cases.json, so the path is baked in at configure time
    # rather than resolved against whatever working directory ctest picks. The
    # expectations come from the manifest, never from this file, and the JSON
    # backend is the facade's own (nlohmann when CMake found it, the bundled
    # parser otherwise), so no JSON dependency is introduced here.
    add_executable(kcl_consistency_tests tests/test_consistency.cpp)
    target_include_directories(kcl_consistency_tests PUBLIC ${CPP_INCLUDE_DIR})
    target_link_libraries(kcl_consistency_tests PUBLIC kcl-lib-cpp)
    target_compile_definitions(kcl_consistency_tests PRIVATE
            KCL_CONSISTENCY_CASES="${PROJECT_SOURCE_DIR}/../tests/consistency/cases.json")
    if(WIN32)
        target_link_libraries(kcl_consistency_tests PRIVATE userenv ws2_32 bcrypt)
    endif()
    if(APPLE)
        find_library(CORESERVICES_LIB CoreServices)
        target_link_libraries(kcl_consistency_tests PRIVATE ${CORESERVICES_LIB})
        target_link_libraries(kcl_consistency_tests PRIVATE "-framework CoreFoundation -framework Security")
    endif()
    add_test(NAME kcl_consistency_tests COMMAND kcl_consistency_tests)

    # Same runner compiled against the facade's bundled JSON parser, so the
    # no-nlohmann configuration the facade supports stays covered the same way
    # `facade_bundled_json` covers the facade example.
    add_executable(kcl_consistency_tests_bundled_json tests/test_consistency.cpp)
    target_include_directories(kcl_consistency_tests_bundled_json PUBLIC ${CPP_INCLUDE_DIR})
    target_link_libraries(kcl_consistency_tests_bundled_json PUBLIC kcl-lib-cpp)
    target_compile_definitions(kcl_consistency_tests_bundled_json PRIVATE
            KCL_LIB_NO_NLOHMANN
            KCL_CONSISTENCY_CASES="${PROJECT_SOURCE_DIR}/../tests/consistency/cases.json")
    if(WIN32)
        target_link_libraries(kcl_consistency_tests_bundled_json PRIVATE userenv ws2_32 bcrypt)
    endif()
    if(APPLE)
        find_library(CORESERVICES_LIB CoreServices)
        target_link_libraries(kcl_consistency_tests_bundled_json PRIVATE ${CORESERVICES_LIB})
        target_link_libraries(kcl_consistency_tests_bundled_json PRIVATE "-framework CoreFoundation -framework Security")
    endif()
    add_test(NAME kcl_consistency_tests_bundled_json COMMAND kcl_consistency_tests_bundled_json)

    # The facade example is the only coverage the facade has, so run it
    # twice: once with the default JSON backend and once forced onto the
    # bundled parser, keeping the optional nlohmann/json path honest on
    # machines that have it installed.
    add_executable(facade_bundled_json examples/facade.cpp)
    target_include_directories(facade_bundled_json PUBLIC ${CPP_INCLUDE_DIR})
    target_link_libraries(facade_bundled_json PUBLIC kcl-lib-cpp)
    target_compile_definitions(facade_bundled_json PRIVATE KCL_LIB_NO_NLOHMANN)
    if(WIN32)
        target_link_libraries(facade_bundled_json PRIVATE userenv ws2_32 bcrypt)
    endif()
    if(APPLE)
        find_library(CORESERVICES_LIB CoreServices)
        target_link_libraries(facade_bundled_json PRIVATE ${CORESERVICES_LIB})
        target_link_libraries(facade_bundled_json PRIVATE "-framework CoreFoundation -framework Security")
    endif()

    add_test(NAME facade COMMAND facade)
    add_test(NAME facade_bundled_json COMMAND facade_bundled_json)
    # The plugin example is the only coverage the plugin header has.
    add_test(NAME plugin_api COMMAND plugin_api)
    # Both AST examples are built by the EXECUTABLES list above, so without
    # these they are compiled on every run and executed on none.
    add_test(NAME ast_alignment COMMAND ast_alignment)
    add_test(NAME ast_contract COMMAND ast_contract)
endif()
