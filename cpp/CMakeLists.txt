cmake_minimum_required(VERSION 3.10)
project(kcl-lib VERSION 0.9.3 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(ENV{MACOSX_DEPLOYMENT_TARGET} "10.13")

option(KCL_LIB_ENABLE_TESTING "Enable building test binary" OFF)

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
set_target_properties(kcl-lib-cpp
        PROPERTIES ADDITIONAL_CLEAN_FILES ${CARGO_TARGET_DIR}
)

set(EXECUTABLES exec_api exec_with_deps_api override_api update_deps_api validate_api list_options_api get_version_api load_settings_files_api testing_api rename_code_api rename_api lint_path_api format_path_api format_code_api get_schema_type_api list_variables_api load_package_api parse_file_api parse_program_api)
foreach(EXE IN LISTS EXECUTABLES)
    add_executable(${EXE} examples/${EXE}.cpp)
    target_include_directories(${EXE} PUBLIC ${CPP_INCLUDE_DIR})
    target_link_libraries(${EXE} PUBLIC kcl-lib-cpp)
    if(WIN32)
        target_link_libraries(${EXE} PRIVATE userenv ws2_32 bcrypt)
    endif()
    if(APPLE)
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

# Tests
if (KCL_LIB_ENABLE_TESTING)
    enable_testing()
    find_package(GTest REQUIRED)
    file(GLOB_RECURSE TEST_SOURCE_FILE tests/*.cpp)
    add_executable(kcl-lib-cpp_test ${TEST_SOURCE_FILE})
    target_include_directories(kcl-lib-cpp_test PUBLIC ${CPP_INCLUDE_DIR} ${GTEST_INCLUDE_DIRS})
    target_link_libraries(kcl-lib-cpp_test ${GTEST_LDFLAGS} GTest::gtest_main kcl-lib-cpp)
    target_compile_options(kcl-lib-cpp_test PRIVATE ${GTEST_CFLAGS})

    # Platform-specific test configuration
    if(WIN32)
        target_link_libraries(kcl-lib-cpp_test userenv ws2_32 bcrypt)
    endif()
    if(APPLE)
        target_link_libraries(kcl-lib-cpp_test "-framework CoreFoundation -framework Security")
    endif()

    include(GoogleTest)
    gtest_discover_tests(kcl-lib-cpp_test)
endif()
