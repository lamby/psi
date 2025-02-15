cmake_minimum_required(VERSION 3.10.0)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Release" CACHE STRING "")
endif()

# Psi or Psi+ detection
option(PSI_PLUS "Build Psi+ client instead of Psi" OFF)
if(PSI_PLUS)
    add_definitions(-DPSI_PLUS)
    project(psi-plus)
    message(STATUS "===Building Psi+===")
else()
    project(psi)
    message(STATUS "===Building Psi===")
endif()

# Define LINUX on Linux like as WIN32 on Windows and APPLE on macOS
if(UNIX AND NOT (APPLE OR HAIKU))
    set(LINUX ON)
endif()

# Check for submodules
set(SBM_LIST
    ${PROJECT_SOURCE_DIR}/3rdparty/http-parser/http_parser.h
    ${PROJECT_SOURCE_DIR}/3rdparty/qhttp/qhttp.pro
    ${PROJECT_SOURCE_DIR}/3rdparty/qite/qite.pro
    ${PROJECT_SOURCE_DIR}/iris/CMakeLists.txt
    ${PROJECT_SOURCE_DIR}/src/libpsi/tools/CMakeLists.txt
)
foreach(submodule ${SBM_LIST})
    if(NOT EXISTS "${submodule}")
        message(FATAL_ERROR "Psi submodules not found.\nPlease run:\n====\ncd ${PROJECT_SOURCE_DIR}\ngit submodule init\ngit submodule update\n====\nbefore run cmake again")
    endif()
endforeach()

set( DEFAULT_BUNDLED_QCA OFF )
if (APPLE OR MSVC)
    set( DEFAULT_BUNDLED_QCA ON )
endif()

set( DEFAULT_BUNDLED_USRSCTP OFF )
if (APPLE OR (MSVC OR USE_MXE))
    set( DEFAULT_BUNDLED_USRSCTP ON )
endif()


# Common options
set( CHAT_TYPE "BASIC" CACHE STRING "Type of chatlog engine. WEBKIT | WEBENGINE | BASIC" )
set_property(CACHE CHAT_TYPE PROPERTY STRINGS WEBKIT WEBENGINE BASIC)
option( PRODUCTION "Build production version" OFF )
option( VERBOSE_PROGRAM_NAME "Verbose output binary name" OFF )
option( BUNDLED_IRIS "Build iris library bundled" ON )
option( BUILD_PSIMEDIA "Build psimedia plugin if its code is found in sources tree. Works only with ENABLE_PLUGINS=ON" OFF )
option( ENABLE_PLUGINS "Enable plugins" OFF )
option( USE_HUNSPELL "Build psi with hunspell spellcheck" ON )
option( USE_ENCHANT "Build psi with enchant spellcheck" OFF )
option( USE_ASPELL "Build psi with aspell spellcheck" OFF )
option( USE_CCACHE "Use ccache utility if found" ON )
option( USE_CRASH "Enable builtin sigsegv handling" OFF )
option( USE_DBUS "Enable DBUS support" ON )
option( USE_KEYCHAIN "Enable Qt5Keychain support" ON )
option( ONLY_BINARY "Build and install only binary file" OFF )
option( ONLY_PLUGINS "Build psi plugins only" OFF )
option( INSTALL_EXTRA_FILES "Install sounds, iconsets, certs, client_icons.txt, themes" ON )
option( INSTALL_PLUGINS_SDK "Install sdk files to build plugins outside of project" OFF )
option( PLUGINS_NO_DEBUG "Add -DPLUGINS_NO_DEBUG definition" OFF )
# Developers options
option( DEV_MODE "Enable prepare-bin-libs target for MS Windows only. Set PSI_DATADIR and PSI_LIBDIR to CMAKE_RUNTIME_OUTPUT_DIRECTORY to debug plugins for Linux only" OFF )
# Iris options
option( BUNDLED_QCA "Adds: DTLS, Blake2b and other useful for XMPP crypto-stuff" ${DEFAULT_BUNDLED_QCA} )
option( BUNDLED_USRSCTP "Compile compatible usrsctp lib when system one is not available or uncompatible (required for p2p file transfer)" ${DEFAULT_BUNDLED_USRSCTP} )
if (UNIX AND "${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    option( ENABLE_ASAN "Enable compilation with address sanitizer" OFF )
endif()

# Cross-compilation and native builds for MS Windows
option( ENABLE_PORTABLE "Create portable version of Psi+ for MS Windows" OFF )
option( USE_MXE "Use MXE (cross-compilation build environment for MS Windows)" OFF )

# Other systems
if(LINUX)
    option( USE_X11 "Enable X11 features support" ON )
    option( USE_XSS "Enable Xscreensaver support" ON )
    option( LIMIT_X11_USAGE "Disable usage of X11 features which may crash program" OFF )
elseif(APPLE)
    option( USE_SPARKLE "Use Sparkle for APPLE builds" OFF )
    option( USE_GROWL "Use growl for macOS builds" OFF )
    option( USE_MAC_DOC "Use macOS dock" OFF )
endif()

if(WIN32 AND ("${CMAKE_BUILD_TYPE}" STREQUAL "Debug" OR ("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")))
    option( NO_DEBUG_OPTIMIZATION "Disable optimization for debug builds" OFF )
endif()

if( USE_HUNSPELL AND (USE_ENCHANT AND USE_ASPELL) )
    message(FATAL_ERROR "Flags USE_HUNSPELL, USE_ASPELL and USE_ENCHANT cannot be enabled at the same time.\nPlease enable only one of them")
elseif( USE_HUNSPELL AND USE_ASPELL )
    message(FATAL_ERROR "Both flags USE_HUNSPELL and USE_ASPELL cannot be enabled at the same time.\nPlease enable only one of them")
elseif( USE_ASPELL AND USE_ENCHANT )
    message(FATAL_ERROR "Both flags USE_ASPELL and USE_ENCHANT cannot be enabled at the same time.\nPlease enable only one of them")
elseif( USE_HUNSPELL AND USE_ENCHANT )
    message(FATAL_ERROR "Both flags USE_HUNSPELL and USE_ENCHANT cannot be enabled at the same time.\nPlease enable only one of them")
endif()

if( ONLY_BINARY AND INSTALL_EXTRA_FILES )
    message(FATAL_ERROR "Both flags ONLY_BINARY and INSTALL_EXTRA_FILES cannot be enabled at the same time.\nPlease enable only one of them")
endif()

set( GLOBAL_DEPENDS_DEBUG_MODE ON )

list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/cmake/modules" )

include(policyRules)

set(IS_WEBKIT OFF CACHE INTERNAL "Use webkit. Internal variable")
set(IS_WEBENGINE OFF CACHE INTERNAL "Use webengine. Internal variable")
string(TOLOWER "${CHAT_TYPE}" LCHAT_TYPE)

if("${LCHAT_TYPE}" STREQUAL "webkit")
    add_definitions(
        -DWEBKIT
    )
    set(IS_WEBKIT ON)
    message(STATUS "Chatlog type - QtWebKit")
elseif("${LCHAT_TYPE}" STREQUAL "webengine")
    set(IS_WEBENGINE ON)
    find_package( Qt5Core 5.9.0 REQUIRED )
    add_definitions(
        -DWEBKIT
        -DWEBENGINE=1
    )
    message(STATUS "Chatlog type - QtWebEngine")
else()
    set(IS_WEBKIT OFF)
    set(IS_WEBENGINE OFF)
    message(STATUS "Chatlog type - Basic")
endif()

message(STATUS "System name - ${CMAKE_SYSTEM_NAME}")

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug" OR ("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo"))
    set(ISDEBUG ON)
    option(PLUGIN_INSTALL_PATH_DEBUG "Add -DPLUGIN_INSTALL_PATH_DEBUG definition" OFF)
    option(CHATVIEW_CORRECTION_DEBUG "Add -DCORRECTION_DEBUG definition" OFF)
    if(PLUGIN_INSTALL_PATH_DEBUG)
        add_definitions(-DPLUGIN_INSTALL_PATH_DEBUG)
    endif()
    if(CHATVIEW_CORRECTION_DEBUG)
        add_definitions(-DCORRECTION_DEBUG)
    endif()
endif()

if(PLUGINS_NO_DEBUG)
    add_definitions(-DPLUGINS_NO_DEBUG)
endif()

if(ONLY_PLUGINS)
    set(ENABLE_PLUGINS ON)
endif()

if(ENABLE_PLUGINS AND BUILD_PSIMEDIA)
    if(PSI_PLUS)
        option(USE_PSI "use psi" OFF)
    else()
        option(USE_PSI "use psi" ON)
    endif()
    option(BUILD_DEMO "build demo" OFF)
elseif(NOT ENABLE_PLUGINS AND BUILD_PSIMEDIA)
    message(FATAL_ERROR "BUILD_PSIMEDIA flag not works without ENABLE_PLUGINS flag.\nPlease enable ENABLE_PLUGINS flag or disable BUILD_PSIMEDIA flag")
endif()

if(USE_CRASH)
    add_definitions(-DUSE_CRASH)
endif()

if(BUNDLED_QCA)
    add_definitions(-DQCA_STATIC)
endif()

# Detect MXE cross-compilation
if(EXISTS "${CMAKE_TOOLCHAIN_FILE}")
    string(TOLOWER ${CMAKE_TOOLCHAIN_FILE} TOOLCHAIN_FILE)
    string(REGEX MATCH "mxe-conf" MXE_DETECTED "${TOOLCHAIN_FILE}")
    if(MXE_DETECTED)
        message(STATUS "MXE environment detected")
        set(USE_MXE ON)
        message(STATUS "MXE toolchain: ${CMAKE_TOOLCHAIN_FILE}")
        message(STATUS "MXE root path: ${CMAKE_PREFIX_PATH}")
        if(IS_WEBENGINE)
            message(FATAL_ERROR "Webengine is not available in MXE. Please set the CHAT_TYPE variable to Webkit or Basic")
        endif()
        set(BUNDLED_USRSCTP ON)
    endif()
endif()

# For GNU/Linux and *BSD systems:
if(UNIX AND NOT (APPLE OR HAIKU))
    if(USE_X11)
        add_definitions( -DHAVE_X11 )
        message(STATUS "X11 features support - ENABLED")
    elseif(NOT LIMIT_X11_USAGE)
        set(USE_XSS OFF)
    endif()
    if(LIMIT_X11_USAGE)
        add_definitions( -DLIMIT_X11_USAGE )
        message(STATUS "Unsafe X11 features support - DISABLED")
    endif()
    add_definitions(
        -DHAVE_FREEDESKTOP
        -DAPP_PREFIX=${CMAKE_INSTALL_PREFIX}
        -DAPP_BIN_NAME=${PROJECT_NAME}
    )
    if(USE_XSS)
        add_definitions( -DHAVE_XSS )
        message(STATUS "Xscreensaver support - ENABLED")
    endif()
    if(USE_DBUS)
        message(STATUS "DBus support - ENABLED")
    endif()
endif()

# Detect *BSD systems
STRING (REGEX MATCH "BSD" PROJECT_OS_BSD ${CMAKE_SYSTEM_NAME})
if(PROJECT_OS_BSD)
    message(STATUS "BSD-like system detected")
    add_definitions(-DIOAPI_NO_64)
endif()

# Detect NetBSD and handle library path accordingly
STRING (REGEX MATCH "NetBSD" PROJECT_OS_NETBSD ${CMAKE_SYSTEM_NAME})
if(PROJECT_OS_NETBSD)
    message(STATUS "NetBSD detected")
    set(CMAKE_C_FLAGS "-Wl,-rpath,/usr/X11R7/lib -Wl,-rpath,/usr/pkg/lib -Wl,-rpath,/usr/pkg/qt5/lib")
    set(CMAKE_CXX_FLAGS "-Wl,-rpath,/usr/X11R7/lib -Wl,-rpath,/usr/pkg/lib -Wl,-rpath,/usr/pkg/qt5/lib")
endif()

# Qt dependencies make building very slow
# Track only .h files
include_regular_expression("^.*\\.h$")

# Put executable in build root dir
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/psi" )

# Set CXX and C Flags
if(APPLE)
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -Wno-overloaded-virtual")
elseif(WIN32)
    include("${CMAKE_CURRENT_SOURCE_DIR}/win32/win32_definitions.cmake")
endif()

if(ENABLE_ASAN)
    set (CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -fno-omit-frame-pointer -fsanitize=address")
    set (CMAKE_LINKER_FLAGS_DEBUG "${CMAKE_LINKER_FLAGS_DEBUG} -fno-omit-frame-pointer -fsanitize=address")
endif()

if("${CMAKE_BUILD_TYPE}" STREQUAL "Debug")
    message(STATUS "CXX debug flags: ${CMAKE_CXX_FLAGS_DEBUG}")
    message(STATUS "C debug flags: ${CMAKE_C_FLAGS_DEBUG}")
elseif("${CMAKE_BUILD_TYPE}" STREQUAL "RelWithDebInfo")
    message(STATUS "CXX debug flags: ${CMAKE_CXX_FLAGS_RELWITHDEBINFO}")
    message(STATUS "C debug flags: ${CMAKE_C_FLAGS_RELWITHDEBINFO}")
else()
    message(STATUS "CXX flags: ${CMAKE_CXX_FLAGS}")
    message(STATUS "C flags: ${CMAKE_C_FLAGS}")
endif()

if(NOT WIN32 AND ENABLE_PORTABLE)
    message(WARNING "Portable version creation possible only for Windows OS")
    set(ENABLE_PORTABLE OFF)
elseif(WIN32 AND ENABLE_PORTABLE)
    message(STATUS "Portable version - ENABLED")
endif()

if( PRODUCTION )
    message(STATUS "Production version - ENABLED")
endif()

if( DEV_MODE OR ENABLE_PORTABLE )
    message(STATUS "prepare-bin-libs target - ENABLED")
endif()

# Copy a list of files from one directory to another. Only full paths.
function(copy SOURCE DEST TARGET)
    if(EXISTS ${SOURCE})
        set(OUT_TARGET_FILE "${CMAKE_BINARY_DIR}/${TARGET}.cmake")

        string(REGEX REPLACE "\\\\+" "/" DEST "${DEST}")
        string(REGEX REPLACE "\\\\+" "/" SOURCE "${SOURCE}")

        if(NOT TARGET ${TARGET})
            file(REMOVE "${OUT_TARGET_FILE}")
            add_custom_target(${TARGET} COMMAND ${CMAKE_COMMAND} -P "${OUT_TARGET_FILE}")
        endif()

        if(IS_DIRECTORY ${SOURCE})
            # copy directory
            file(GLOB_RECURSE FILES "${SOURCE}/*")
            get_filename_component(SOURCE_DIR_NAME ${SOURCE} NAME)

            foreach(FILE ${FILES})
                file(RELATIVE_PATH REL_PATH ${SOURCE} ${FILE})
                set(REL_PATH "${SOURCE_DIR_NAME}/${REL_PATH}")
                get_filename_component(REL_PATH ${REL_PATH} DIRECTORY)
                set(DESTIN "${DEST}/${REL_PATH}")

                string(REGEX REPLACE "/+" "/" DESTIN ${DESTIN})
                string(REGEX REPLACE "/+" "/" FILE ${FILE})

                file(APPEND
                    "${OUT_TARGET_FILE}"
                    "file(INSTALL \"${FILE}\" DESTINATION \"${DESTIN}\" USE_SOURCE_PERMISSIONS)\n")
            endforeach()
        else()
            string(REPLACE "//" "/" DEST ${DEST})
            if(DEST MATCHES "/$")
                set(DIR "${DEST}")
                string(REGEX REPLACE "^(.+)/$" "\\1" DIR ${DIR})
            else()
                # need to copy and rename
                get_filename_component(DIR ${DEST} DIRECTORY)
                get_filename_component(FILENAME ${DEST} NAME)
                get_filename_component(SOURCE_FILENAME ${SOURCE} NAME)
            endif()
            file(APPEND
                "${OUT_TARGET_FILE}"
                "file(INSTALL \"${SOURCE}\" DESTINATION \"${DIR}\" USE_SOURCE_PERMISSIONS)\n")
            if(DEFINED FILENAME)
                file(APPEND
                    "${OUT_TARGET_FILE}"
                    "file(RENAME \"${DIR}/${SOURCE_FILENAME}\" \"${DIR}/${FILENAME}\")\n")
            endif()
        endif()
    endif()
endfunction()

if(USE_CCACHE)
    # Configure CCache if available
    find_program(CCACHE_PATH ccache DOC "Path to ccache")
    if(CCACHE_PATH)
        message(STATUS "Found ccache at ${CCACHE_PATH}")
        set_property(GLOBAL PROPERTY RULE_LAUNCH_COMPILE ${CCACHE_PATH})
        set_property(GLOBAL PROPERTY RULE_LAUNCH_LINK ${CCACHE_PATH})
    endif()
endif()

if(NOT ONLY_PLUGINS)
    add_subdirectory( 3rdparty )
    if(BUNDLED_IRIS)
        add_subdirectory( iris )
    else()
        find_package( Iris REQUIRED )
        include_directories(${Iris_INCLUDE_DIR})
    endif()
    set( iris_LIB iris )
    add_subdirectory(src)
    if(ENABLE_PLUGINS)
        add_subdirectory(plugins)
    endif()
else()
    add_subdirectory(plugins)
endif()
