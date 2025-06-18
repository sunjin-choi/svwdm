function(add_subdirectories_all BASE_DIR)
  file(
    GLOB_RECURSE SUBDIR_CMAKELISTS
    RELATIVE ${BASE_DIR}
    ${BASE_DIR}/*/CMakeLists.txt)

  foreach(CMAKELIST ${SUBDIR_CMAKELISTS})
    get_filename_component(SUBDIR ${CMAKELIST} DIRECTORY)
    if(NOT "${SUBDIR}" STREQUAL "." AND NOT "${SUBDIR}" STREQUAL "${BASE_DIR}")
      message(STATUS "Adding subdirectory: ${BASE_DIR}/${SUBDIR}")
      add_subdirectory(${BASE_DIR}/${SUBDIR})
    endif()
  endforeach()
endfunction()
