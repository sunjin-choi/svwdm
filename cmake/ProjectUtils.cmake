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

function(sort_verilog_sources OUT_LIST IN_LIST_VAR)
  set(HEADER_SRCS "")
  set(PKG_SRCS "")
  set(IF_SRCS "")
  set(OTHER_SRCS "")

  foreach(SRC IN LISTS IN_LIST_VAR)
    if(SRC MATCHES "\\.svh$")
      list(APPEND HEADER_SRCS ${SRC})
    elseif(SRC MATCHES "_pkg\.sv$")
      list(APPEND PKG_SRCS ${SRC})
    elseif(SRC MATCHES "_if\.sv$")
      list(APPEND IF_SRCS ${SRC})
    else()
      list(APPEND OTHER_SRCS ${SRC})
    endif()
  endforeach()

  set(_tmp_list ${HEADER_SRCS})
  list(APPEND _tmp_list ${PKG_SRCS} ${IF_SRCS} ${OTHER_SRCS})
  set(${OUT_LIST}
      ${_tmp_list}
      PARENT_SCOPE)

endfunction()

function(add_verilog_library_sources OUT_LIST)
  set(options PHOTONICS TUNER CIRCUITS)
  set(oneValueArgs "")
  set(multiValueArgs "")
  cmake_parse_arguments(LIB "${options}" "${oneValueArgs}" "${multiValueArgs}"
                        ${ARGN})

  set(VERI_LIBSV_SRC "")
  set(VERI_LIBSVH_SRC "")
  set(VERI_LIB_SRC "")
  if(LIB_PHOTONICS)
    file(GLOB_RECURSE VERI_LIBSV_SRC "${VERILOG_LIB_DIR}/photonics/*.sv")
    file(GLOB_RECURSE VERI_LIBSVH_SRC "${VERILOG_LIB_DIR}/photonics/*.svh")
    list(APPEND VERI_LIB_SRC ${VERI_LIBSV_SRC} ${VERI_LIBSVH_SRC})
  endif()

  if(LIB_TUNER)
    file(GLOB_RECURSE VERI_LIBSV_SRC "${VERILOG_LIB_DIR}/tuner/*.sv")
    file(GLOB_RECURSE VERI_LIBSVH_SRC "${VERILOG_LIB_DIR}/tuner/*.svh")
    list(APPEND VERI_LIB_SRC ${VERI_LIBSV_SRC} ${VERI_LIBSVH_SRC})
  endif()

  if(LIB_CIRCUITS)
    file(GLOB_RECURSE VERI_LIBSV_SRC "${VERILOG_LIB_DIR}/circuits/*.sv")
    file(GLOB_RECURSE VERI_LIBSVH_SRC "${VERILOG_LIB_DIR}/circuits/*.svh")
    list(APPEND VERI_LIB_SRC ${VERI_LIBSV_SRC} ${VERI_LIBSVH_SRC})
  endif()

  # message(STATUS "Adding Verilog library sources: ${VERI_LIB_SRC}")
  sort_verilog_sources(SORTED_VERI_LIB_SRC "${VERI_LIB_SRC}")

  set(_tmp_list ${SORTED_VERI_LIB_SRC})
  list(APPEND _tmp_list ${${OUT_LIST}})
  set(${OUT_LIST}
      ${_tmp_list}
      PARENT_SCOPE)

endfunction()
