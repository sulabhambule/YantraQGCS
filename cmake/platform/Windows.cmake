# ----------------------------------------------------------------------------
# QGroundControl Windows Platform Configuration
# ----------------------------------------------------------------------------

if(NOT WIN32)
    message(FATAL_ERROR "QGC: Invalid Platform: Windows.cmake included but platform is not Windows")
endif()

# ----------------------------------------------------------------------------
# Windows-Specific Definitions
# ----------------------------------------------------------------------------
target_compile_definitions(${CMAKE_PROJECT_NAME}
    PRIVATE
        _USE_MATH_DEFINES       # Enable M_PI and other math constants
        NOMINMAX                # Prevent min/max macro conflicts
        WIN32_LEAN_AND_MEAN     # Reduce Windows.h bloat
        _CRT_SECURE_NO_WARNINGS # Disable warnings for unsafe C functions
)

if(MSVC)
    target_compile_options(${CMAKE_PROJECT_NAME}
        PRIVATE
            /bigobj
            /Zc:preprocessor
    )
endif()

# ----------------------------------------------------------------------------
# Windows Executable Configuration
# ----------------------------------------------------------------------------
if(MINGW)
    # Under MinGW Makefiles, windres fails if target_sources adds .rc directly to the main executable target
    # because CMake expands all 100+ module include paths into the windres command line (exceeding Windows' 8191 char limit).
    # Compiling the .rc file in a standalone OBJECT library isolates windres from target include bloat.
    set(_rc_file "${CMAKE_BINARY_DIR}/${CMAKE_PROJECT_NAME}_resource.rc")
    set(_rc_icons "")
    if(QGC_WINDOWS_ICON_PATH)
        set(_rc_icons "IDI_ICON1    ICON    \"${QGC_WINDOWS_ICON_PATH}\"\n")
    endif()
    set(_rc_version "${CMAKE_PROJECT_VERSION}")
    if(_rc_version MATCHES "^[0-9]+(\\.[0-9]+)*$")
        string(REPLACE "." "," _rc_version_comma "${_rc_version}")
    else()
        set(_rc_version_comma "0,0,0,0")
    endif()
    file(GENERATE OUTPUT "${_rc_file}" CONTENT
"#include <windows.h>
${_rc_icons}
VS_VERSION_INFO VERSIONINFO
FILEVERSION ${_rc_version_comma}
PRODUCTVERSION ${_rc_version_comma}
FILEFLAGSMASK 0x3fL
#ifdef _DEBUG
    FILEFLAGS VS_FF_DEBUG
#else
    FILEFLAGS 0x0L
#endif
FILEOS VOS_NT_WINDOWS32
FILETYPE VFT_APP
FILESUBTYPE VFT2_UNKNOWN
BEGIN
    BLOCK \"StringFileInfo\"
    BEGIN
        BLOCK \"040904b0\"
        BEGIN
            VALUE \"CompanyName\", \"${QGC_ORG_NAME}\"
            VALUE \"FileDescription\", \"${CMAKE_PROJECT_DESCRIPTION}\"
            VALUE \"FileVersion\", \"${CMAKE_PROJECT_VERSION}\"
            VALUE \"LegalCopyright\", \"${QGC_APP_COPYRIGHT}\"
            VALUE \"OriginalFilename\", \"${CMAKE_PROJECT_NAME}.exe\"
            VALUE \"ProductName\", \"${CMAKE_PROJECT_NAME}\"
            VALUE \"ProductVersion\", \"${CMAKE_PROJECT_VERSION}\"
        END
    END
    BLOCK \"VarFileInfo\"
    BEGIN
        VALUE \"Translation\", 0x0409, 1200
    END
END
"
    )
    add_library(${CMAKE_PROJECT_NAME}_rc OBJECT "${_rc_file}")
    target_link_libraries(${CMAKE_PROJECT_NAME} PRIVATE $<TARGET_OBJECTS:${CMAKE_PROJECT_NAME}_rc>)
elseif(COMMAND _qt_internal_generate_win32_rc_file)
    set_target_properties(${CMAKE_PROJECT_NAME}
        PROPERTIES
            QT_TARGET_COMPANY_NAME "${QGC_ORG_NAME}"
            QT_TARGET_DESCRIPTION "${CMAKE_PROJECT_DESCRIPTION}"
            QT_TARGET_VERSION "${CMAKE_PROJECT_VERSION}"
            QT_TARGET_COPYRIGHT "${QGC_APP_COPYRIGHT}"
            QT_TARGET_PRODUCT_NAME "${CMAKE_PROJECT_NAME}"
            # QT_TARGET_COMMENTS: ${QGC_QT_TARGET_COMMENTS}
            # QT_TARGET_ORIGINAL_FILENAME: ${QGC_QT_TARGET_ORIGINAL_FILENAME}
            # QT_TARGET_TRADEMARKS: ${QGC_QT_TARGET_TRADEMARKS}
            # QT_TARGET_INTERNALNAME: ${QGC_QT_TARGET_INTERNALNAME}
            QT_TARGET_RC_ICONS "${QGC_WINDOWS_ICON_PATH}"
    )
    _qt_internal_generate_win32_rc_file(${CMAKE_PROJECT_NAME})
elseif(EXISTS "${QGC_WINDOWS_RESOURCE_FILE_PATH}")
    target_sources(${CMAKE_PROJECT_NAME} PRIVATE "${QGC_WINDOWS_RESOURCE_FILE_PATH}")
    set_target_properties(${CMAKE_PROJECT_NAME} PROPERTIES QT_TARGET_WINDOWS_RC_FILE "${QGC_WINDOWS_RESOURCE_FILE_PATH}")
elseif(EXISTS "${CMAKE_SOURCE_DIR}/deploy/windows/QGroundControl.rc.in")
    configure_file(
        "${CMAKE_SOURCE_DIR}/deploy/windows/QGroundControl.rc.in"
        "${CMAKE_BINARY_DIR}/QGroundControl.rc"
        @ONLY
    )
    target_sources(${CMAKE_PROJECT_NAME} PRIVATE "${CMAKE_BINARY_DIR}/QGroundControl.rc")
else()
    message(WARNING "QGC: No Windows resource file found")
endif()

if(MSVC)
    # qt_add_win_app_sdk(${CMAKE_PROJECT_NAME} PRIVATE)
endif()

message(STATUS "QGC: Windows platform configuration applied")
