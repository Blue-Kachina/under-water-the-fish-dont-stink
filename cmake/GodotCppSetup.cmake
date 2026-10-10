# godot-cpp git submodule setup for GDExtension
# Included by CMakeLists.txt when present. Delete this file to remove GDExtension support.
# Runs before native/under-water-the-fish-dont-stinkExt is added as a subdirectory.

find_program(GIT git REQUIRED)

# Initialize git repository at the project root if not already present
if(NOT EXISTS "${CMAKE_SOURCE_DIR}/.git")
    message(NOTICE "Initializing git repository...")
    execute_process(
        COMMAND ${GIT} init
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMAND_ERROR_IS_FATAL ANY
    )
    execute_process(
        COMMAND ${GIT} add .
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
        COMMAND_ERROR_IS_FATAL ANY
    )
endif()

set(_godot_cpp_dir "${CMAKE_SOURCE_DIR}/native/under-water-the-fish-dont-stinkExt/godot-cpp")

if(NOT EXISTS "${_godot_cpp_dir}/.git")
    # Recover from any interrupted previous attempt
    if(EXISTS "${_godot_cpp_dir}")
        message(NOTICE "Cleaning up incomplete godot-cpp directory...")
        execute_process(
            COMMAND ${GIT} submodule deinit -f -- native/under-water-the-fish-dont-stinkExt/godot-cpp
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            ERROR_QUIET OUTPUT_QUIET
        )
        file(REMOVE_RECURSE "${CMAKE_SOURCE_DIR}/.git/modules/native/under-water-the-fish-dont-stinkExt/godot-cpp")
        file(REMOVE_RECURSE "${_godot_cpp_dir}")
        execute_process(
            COMMAND ${GIT} config --file "${CMAKE_SOURCE_DIR}/.gitmodules"
                --remove-section "submodule.native/under-water-the-fish-dont-stinkExt/godot-cpp"
            ERROR_QUIET OUTPUT_QUIET
        )
        execute_process(
            COMMAND ${GIT} rm --cached -f native/under-water-the-fish-dont-stinkExt/godot-cpp
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            ERROR_QUIET OUTPUT_QUIET
        )
    endif()

    message(NOTICE "Adding and initializing the godot-cpp submodule...")
    execute_process(
        COMMAND ${GIT} submodule add -b master https://github.com/godotengine/godot-cpp
        WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}/native/under-water-the-fish-dont-stinkExt"
        COMMAND_ERROR_IS_FATAL ANY
    )
endif()

# godot-cpp 10+ supports several engine versions and needs to be told which API to target.
# Keep this in sync with compatibility_minimum in the addon's .gdextension file.
set(GODOTCPP_API_VERSION "4.6" CACHE STRING "The Godot API version to target")

add_subdirectory("${_godot_cpp_dir}""${CMAKE_BINARY_DIR}/native/under-water-the-fish-dont-stinkExt/godot-cpp" SYSTEM)
set(godot-cpp_SOURCE_DIR "${_godot_cpp_dir}")
set(godot-cpp_BINARY_DIR "${CMAKE_BINARY_DIR}/native/under-water-the-fish-dont-stinkExt/godot-cpp")
