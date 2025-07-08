add_executable(search_phy_model main.cpp)
target_include_directories(search_phy_model PRIVATE ${CMAKE_CURRENT_SOURCE_DIR}/../../lib/cpp)
add_custom_target(run-search_phy_model COMMAND search_phy_model DEPENDS search_phy_model WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR} COMMENT "Running SearchPhyModel test")
