cmake_minimum_required(VERSION 3.19)
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>" CACHE STRING "")
project(town_flow LANGUAGES CXX)

include(FetchContent)
set(GODOTCPP_BUILD_PROFILE "${CMAKE_CURRENT_SOURCE_DIR}/profile.json" CACHE FILEPATH "")
set(GODOTCPP_TARGET template_release CACHE STRING "")
FetchContent_Declare(godotcpp
    GIT_REPOSITORY https://github.com/godotengine/godot-cpp.git
    GIT_SUBMODULES ""
    GIT_TAG e83fd0904c13356ed1d4c3d09f8bb9132bdc6b77
)
FetchContent_MakeAvailable(godotcpp)

add_library(town_flow SHARED town_flow.cpp)
target_link_libraries(town_flow PRIVATE godot-cpp)
target_compile_features(town_flow PRIVATE cxx_std_17)
if(MINGW)
    target_link_options(town_flow PRIVATE -static)
endif()
set_target_properties(town_flow PROPERTIES PREFIX "")
install(TARGETS town_flow LIBRARY DESTINATION native_bin RUNTIME DESTINATION native_bin)
install(FILES town_flow.gdextension.in DESTINATION native_bin RENAME town_flow.gdextension)

install(FILES "${godotcpp_SOURCE_DIR}/LICENSE.md" DESTINATION native_bin RENAME godot-cpp-LICENSE.txt)
