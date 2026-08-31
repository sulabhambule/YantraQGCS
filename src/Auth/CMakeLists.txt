# ============================================================================
# Auth Module
# Backend REST API authentication for Yantra GCS
# ============================================================================

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        AuthManager.cpp
        AuthManager.h
)

target_include_directories(${CMAKE_PROJECT_NAME} PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Qt6::Network and Qt6::Core are already linked on ${CMAKE_PROJECT_NAME} in src/CMakeLists.txt.
# No new link dependencies are required.

