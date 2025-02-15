cmake_minimum_required(VERSION 3.10.0)

if(WIN32)
    #autodetect 64bit architecture
    if(CMAKE_SIZEOF_VOID_P MATCHES "8")
        set(IS_WIN64 ON CACHE BOOL "64bit architecture")
        if(MSVC)
            set(SDK_PATH "$ENV{PSI_SDK_MSVC_WIN64}" CACHE STRING "Path to Psi SDK")
            if(BUILD_PSIMEDIA)
                set(GST_SDK $ENV{GSTREAMER_1_0_ROOT_MSVC_X86_64} CACHE STRING "Path to gstreamer SDK")
            endif()
        else()
            set(SDK_PATH "$ENV{PSI_SDK_MINGW_x86_64}" CACHE STRING "Path to Psi SDK")
            if(BUILD_PSIMEDIA)
                set(GST_SDK $ENV{GSTREAMER_1_0_ROOT_x86_64} CACHE STRING "Path to gstreamer SDK")
            endif()
        endif()

        message(STATUS "Detected build architecture: 64bit")
    else()
        set(IS_WIN64 OFF CACHE BOOL "64bit architecture")
        if(MSVC)
            set(SDK_PATH "$ENV{PSI_SDK_MSVC_WIN32}" CACHE STRING "Path to Psi SDK")
            if(BUILD_PSIMEDIA)
                set(GST_SDK $ENV{GSTREAMER_1_0_ROOT_MSVC_X86} CACHE STRING "Path to gstreamer SDK")
            endif()
        else()
            set(SDK_PATH "$ENV{PSI_SDK_MINGW_x86}" CACHE STRING "Path to Psi SDK")
            if(BUILD_PSIMEDIA)
                set(GST_SDK $ENV{GSTREAMER_1_0_ROOT_x86} CACHE STRING "Path to gstreamer SDK")
            endif()
        endif()
        message(STATUS "Detected build architecture: 32bit")
    endif()
    #try to find pkg-config executable in ${GST_SDK}/bin
    if(BUILD_PSIMEDIA)
        if(EXISTS ${GST_SDK}/bin)
            find_program(PKG_EXEC pkg-config PATHS "${GST_SDK}/bin")
            if(NOT "${PKG_EXEC}" STREQUAL "PKG_EXEC-NOTFOUND")
                set(PKG_CONFIG_EXECUTABLE ${PKG_EXEC} CACHE STRING "Path to pkg-config executable")
            endif()
        endif()
    endif()
    #Set SDK-related variables
    if(SDK_PATH AND (EXISTS "${SDK_PATH}"))
        set(QCA_DIR "${SDK_PATH}/" CACHE STRING "Path to QCA")
        set(HUNSPELL_ROOT "${SDK_PATH}/" CACHE STRING "Path to hunspell library")
        if(ENABLE_PLUGINS)
            set(LIBGCRYPT_ROOT "${SDK_PATH}/" CACHE STRING "Path to libgcrypt library")
            set(LIBGPGERROR_ROOT "${SDK_PATH}/" CACHE STRING "Path to libgpg-error library")
            set(LIBOTR_ROOT "${SDK_PATH}/" CACHE STRING "Path to libotr library")
            set(LIBTIDY_ROOT "${SDK_PATH}/" CACHE STRING "Path to libtidy library")
            set(SIGNAL_PROTOCOL_C_ROOT "${SDK_PATH}/" CACHE STRING "Path to libsignal-protocol-c library")
        endif()
        set(ZLIB_ROOT "${SDK_PATH}/" CACHE STRING "Path to zlib")
        set(OPENSSL_ROOT_DIR "${SDK_PATH}/" CACHE STRING "Path to openssl library")
        if(MSVC)
            set(Qt5Keychain_DIR "${SDK_PATH}/lib/cmake/Qt5Keychain" CACHE STRING "Path to Qt5Keychain cmake files")
        else()
            set(Qt5Keychain_DIR "${SDK_PATH}/qt5keychain/lib/cmake/Qt5Keychain" CACHE STRING "Path to Qt5Keychain cmake files")
        endif()
        if(DEV_MODE AND BUILD_PSIMEDIA)
            if(NOT GST_SDK)
                set(GST_SDK "${SDK_PATH}/gstbundle/" CACHE STRING "Path to gstreamer SDK")
            endif()
        endif()
    else()
        if(USE_MXE)
            if(USE_KEYCHAIN AND (EXISTS "${CMAKE_PREFIX_PATH}/lib/cmake/Qt5Keychain"))
                set(Qt5Keychain_DIR "${CMAKE_PREFIX_PATH}/lib/cmake/Qt5Keychain" CACHE STRING "Path to Qt5Keychain cmake files")
            endif()
        else()
            message(WARNING "Psi SDK not found at ${SDK_PATH}. Please set SDK_PATH variable or add Psi dependencies path to PATH system environmet variable")
        endif()
    endif()
    set(PLUGINS_PATH "/plugins" CACHE STRING "Install suffix for plugins")

    #Wokr with build flags
    function(set_deb_flags FLAG_VALUES FLAG_ITEM)
        foreach(FLAG ${FLAG_VALUES})
            if(NOT ("${${FLAG_ITEM}}" MATCHES "${FLAG}"))
                set(${FLAG_ITEM} "${${FLAG_ITEM}} ${FLAG}" PARENT_SCOPE)
            endif()
        endforeach()
    endfunction()
    if(NOT MSVC)
        set(FLAGS_DEBUG "-O0")
        if(ISDEBUG AND NO_DEBUG_OPTIMIZATION)
            #Force build without optimizations
            set(CompilerFlags
                CMAKE_CXX_FLAGS_DEBUG
                CMAKE_C_FLAGS_DEBUG
                CMAKE_C_FLAGS_RELWITHDEBINFO
                CMAKE_CXX_FLAGS_RELWITHDEBINFO
                )
            foreach(CompilerFlag ${CompilerFlags})
              string(REPLACE "-O3" "-O0" ${CompilerFlag} "${${CompilerFlag}}")
              string(REPLACE "-O2" "-O0" ${CompilerFlag} "${${CompilerFlag}}")
              string(REPLACE "-DNDEBUG" "" ${CompilerFlag} "${${CompilerFlag}}")
            endforeach()
            set_deb_flags(${FLAGS_DEBUG} CMAKE_C_FLAGS_RELWITHDEBINFO)
            set_deb_flags(${FLAGS_DEBUG} CMAKE_CXX_FLAGS_RELWITHDEBINFO)
        endif()
        set_deb_flags(${FLAGS_DEBUG} CMAKE_CXX_FLAGS_DEBUG)
        set_deb_flags(${FLAGS_DEBUG} CMAKE_C_FLAGS_DEBUG)
        set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++17 -Wall -Wextra")
        set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -Wall -Wextra")
    else()
        set_deb_flags("/MP" CMAKE_CXX_FLAGS)
        set(DEFAULT_DEBUG_FLAG "/ENTRY:mainCRTStartup /DEBUG /INCREMENTAL /SAFESEH:NO /MANIFEST:NO")
        set(DEFAULT_LINKER_FLAG "/ENTRY:mainCRTStartup /INCREMENTAL:NO /LTCG")
        set(CMAKE_EXE_LINKER_FLAGS_DEBUG        "${DEFAULT_DEBUG_FLAG}" CACHE STRING "" FORCE)
        set(CMAKE_EXE_LINKER_FLAGS_MINSIZEREL        "${DEFAULT_LINKER_FLAG}" CACHE STRING "" FORCE)
        set(CMAKE_EXE_LINKER_FLAGS_RELEASE        "${DEFAULT_LINKER_FLAG}" CACHE STRING "" FORCE)
        set(CMAKE_EXE_LINKER_FLAGS_RELWITHDEBINFO    "${DEFAULT_DEBUG_FLAG}" CACHE STRING "" FORCE)
        set(CMAKE_MODULE_LINKER_FLAGS_DEBUG        "/DEBUG /INCREMENTAL /SAFESEH:NO /MANIFEST:NO" CACHE STRING "" FORCE)
        set(CMAKE_MODULE_LINKER_FLAGS_MINSIZEREL    "/INCREMENTAL:NO /LTCG" CACHE STRING "" FORCE)
        set(CMAKE_MODULE_LINKER_FLAGS_RELEASE        "/INCREMENTAL:NO /LTCG" CACHE STRING "" FORCE)
        set(CMAKE_MODULE_LINKER_FLAGS_RELWITHDEBINFO    "/DEBUG /INCREMENTAL:NO /MANIFEST:NO" CACHE STRING "" FORCE)
        set(CMAKE_SHARED_LINKER_FLAGS_DEBUG        "${DEFAULT_DEBUG_FLAG}" CACHE STRING "" FORCE)
        set(CMAKE_SHARED_LINKER_FLAGS_MINSIZEREL    "${DEFAULT_LINKER_FLAG}" CACHE STRING "" FORCE)
        set(CMAKE_SHARED_LINKER_FLAGS_RELEASE        "${DEFAULT_LINKER_FLAG}" CACHE STRING "" FORCE)
        set(CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO    "${DEFAULT_DEBUG_FLAG}" CACHE STRING "" FORCE)
        set(DEBUG_FLAGS "/Zi" "/MDd" "/Ob0" "/Od" "/RTC1")
        if(ISDEBUG AND NO_DEBUG_OPTIMIZATION)
            #Force use debug flags instead of release flags for debug
            set(CompilerFlags
                CMAKE_CXX_FLAGS_DEBUG
                CMAKE_C_FLAGS_DEBUG
                CMAKE_C_FLAGS_RELWITHDEBINFO
                CMAKE_CXX_FLAGS_RELWITHDEBINFO
                )
            foreach(CompilerFlag ${CompilerFlags})
              string(REPLACE "/MD " "/MDd " ${CompilerFlag} "${${CompilerFlag}}")
              string(REPLACE "/Ob1" "/Ob0" ${CompilerFlag} "${${CompilerFlag}}")
              string(REPLACE "/O2" "/Od" ${CompilerFlag} "${${CompilerFlag}}")
              string(REPLACE "/DNDEBUG" "" ${CompilerFlag} "${${CompilerFlag}}")
            endforeach()
            set_deb_flags("${DEBUG_FLAGS}" CMAKE_C_FLAGS_RELWITHDEBINFO)
            set_deb_flags("${DEBUG_FLAGS}" CMAKE_CXX_FLAGS_RELWITHDEBINFO)
        elseif(ISDEBUG)
            set(CompilerFlags
                CMAKE_CXX_FLAGS_DEBUG
                CMAKE_C_FLAGS_DEBUG
                )
            foreach(CompilerFlag ${CompilerFlags})
              string(REPLACE "/MTd " "/MDd " ${CompilerFlag} "${${CompilerFlag}}")
            endforeach()
        endif()
        set_deb_flags("${DEBUG_FLAGS}" CMAKE_CXX_FLAGS_DEBUG)
        set_deb_flags("${DEBUG_FLAGS}" CMAKE_C_FLAGS_DEBUG)

        add_definitions(-DNOMINMAX)
        add_definitions(-D_CRT_SECURE_NO_WARNINGS)
        add_definitions(-D_CRT_SECURE_NO_DEPRECATE)
        add_definitions(-D_CRT_NON_CONFORMING_SWPRINTFS)
        add_definitions(-D_SCL_SECURE_NO_WARNINGS)
    endif()
    if(CMAKE_BUILD_TYPE STREQUAL "Debug")
        set(D "d")
        add_definitions(-DALLOW_QT_PLUGINS_DIR)
    endif()
    add_definitions(
        -DUNICODE
        -D_UNICODE
    )
endif()
