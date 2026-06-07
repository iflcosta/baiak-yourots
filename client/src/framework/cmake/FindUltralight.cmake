find_path(Ultralight_INCLUDE_DIR
    NAMES Ultralight/Ultralight.h
    HINTS
        "${ULTRALIGHT_SDK_PATH}/include"
        "C:/ultralight-sdk*/include"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk/include"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk*/include"
)

find_library(Ultralight_LIBRARY
    NAMES Ultralight
    HINTS
        "${ULTRALIGHT_SDK_PATH}/lib"
        "C:/ultralight-sdk*/lib"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk/lib"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk*/lib"
)

find_library(UltralightCore_LIBRARY
    NAMES UltralightCore
    HINTS
        "${ULTRALIGHT_SDK_PATH}/lib"
        "C:/ultralight-sdk*/lib"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk/lib"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk*/lib"
)

find_library(WebCore_LIBRARY
    NAMES WebCore
    HINTS
        "${ULTRALIGHT_SDK_PATH}/lib"
        "C:/ultralight-sdk*/lib"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk/lib"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk*/lib"
)

find_library(AppCore_LIBRARY
    NAMES AppCore
    HINTS
        "${ULTRALIGHT_SDK_PATH}/lib"
        "C:/ultralight-sdk*/lib"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk/lib"
        "${CMAKE_SOURCE_DIR}/../ultralight-sdk*/lib"
)

include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Ultralight
    REQUIRED_VARS Ultralight_INCLUDE_DIR Ultralight_LIBRARY
                  UltralightCore_LIBRARY WebCore_LIBRARY AppCore_LIBRARY
)

if(Ultralight_FOUND)
    set(Ultralight_INCLUDE_DIRS ${Ultralight_INCLUDE_DIR})
    set(Ultralight_LIBRARIES
        ${Ultralight_LIBRARY}
        ${UltralightCore_LIBRARY}
        ${WebCore_LIBRARY}
        ${AppCore_LIBRARY}
    )
    mark_as_advanced(Ultralight_INCLUDE_DIR Ultralight_LIBRARY
                     UltralightCore_LIBRARY WebCore_LIBRARY AppCore_LIBRARY)
    message(STATUS "Ultralight SDK found at: ${Ultralight_INCLUDE_DIR}")
endif()
