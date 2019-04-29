# SPDX-License-Identifier: Apache-2.0

find_program(CMAKE_LINKER     ${CROSS_COMPILE}ld      PATH ${TOOLCHAIN_HOME} NO_DEFAULT_PATH)

set_ifndef(LINKERFLAGPREFIX -Wl)

# ld -T scriptfile: Use scriptfile as the linker script
get_property(TOPT GLOBAL PROPERTY TOPT)
set_ifndef(  TOPT -T)


# Run $LINKER_SCRIPT file through the C preprocessor, producing ${linker_script_gen}
# NOTE: ${linker_script_gen} will be produced at build-time; not at configure-time
macro(configure_linker_script linker_script_gen linker_pass_define)
  set(extra_dependencies ${ARGN})

  # Different generators deal with depfiles differently.
  if(CMAKE_GENERATOR STREQUAL "Unix Makefiles")
    # Note that the IMPLICIT_DEPENDS option is currently supported only
    # for Makefile generators and will be ignored by other generators.
    set(linker_script_dep IMPLICIT_DEPENDS C ${LINKER_SCRIPT})
  elseif(CMAKE_GENERATOR STREQUAL "Ninja")
    # Using DEPFILE with other generators than Ninja is an error.
    set(linker_script_dep DEPFILE ${PROJECT_BINARY_DIR}/${linker_script_gen}.dep)
  else()
    # TODO: How would the linker script dependencies work for non-linker
    # script generators.
    message(STATUS "Warning; this generator is not well supported. The
  Linker script may not be regenerated when it should.")
    set(linker_script_dep "")
  endif()

  zephyr_get_include_directories_for_lang(C current_includes)
  get_filename_component(base_name ${CMAKE_CURRENT_BINARY_DIR} NAME)
  get_property(current_defines GLOBAL PROPERTY PROPERTY_LINKER_SCRIPT_DEFINES)

  add_custom_command(
    OUTPUT ${linker_script_gen}
    DEPENDS
    ${LINKER_SCRIPT}
    ${extra_dependencies}
    # NB: 'linker_script_dep' will use a keyword that ends 'DEPENDS'
    ${linker_script_dep}
    COMMAND ${CMAKE_C_COMPILER}
    -x assembler-with-cpp
    ${NOSYSDEF_CFLAG}
    -MD -MF ${linker_script_gen}.dep -MT ${base_name}/${linker_script_gen}
    ${current_includes}
    ${current_defines}
    ${linker_pass_define}
    -E ${LINKER_SCRIPT}
    -P # Prevent generation of debug `#line' directives.
    -o ${linker_script_gen}
    VERBATIM
    WORKING_DIRECTORY ${PROJECT_BINARY_DIR}
  )
endmacro()




macro(toolchain_ld_userspace2)
  ##CONSIDER
  if(CONFIG_USERSPACE)
    set(APP_SMEM_ALIGNED_LD "${PROJECT_BINARY_DIR}/include/generated/app_smem_aligned.ld")
    set(APP_SMEM_UNALIGNED_LD "${PROJECT_BINARY_DIR}/include/generated/app_smem_unaligned.ld")
    set(OBJ_FILE_DIR "${PROJECT_BINARY_DIR}/../")

    add_custom_target(
      ${APP_SMEM_ALIGNED_DEP}
      DEPENDS
      ${APP_SMEM_ALIGNED_LD}
      )

    add_custom_target(
      ${APP_SMEM_UNALIGNED_DEP}
      DEPENDS
      ${APP_SMEM_UNALIGNED_LD}
      )

    if(CONFIG_NEWLIB_LIBC)
      set(NEWLIB_PART -l libc.a z_libc_partition)
    endif()
    if(CONFIG_MBEDTLS)
      set(MBEDTLS_PART -l libext__lib__crypto__mbedtls.a k_mbedtls_partition)
    endif()

    add_custom_command(
      OUTPUT ${APP_SMEM_UNALIGNED_LD}
      COMMAND ${PYTHON_EXECUTABLE}
      ${ZEPHYR_BASE}/scripts/gen_app_partitions.py
      -d ${OBJ_FILE_DIR}
      -o ${APP_SMEM_UNALIGNED_LD}
      ${NEWLIB_PART} ${MBEDTLS_PART}
      $<$<BOOL:${CMAKE_VERBOSE_MAKEFILE}>:--verbose>
      DEPENDS
      kernel
      ${ZEPHYR_LIBS_PROPERTY}
      WORKING_DIRECTORY ${PROJECT_BINARY_DIR}/
      COMMENT "Generating app_smem_unaligned linker section"
      )

    configure_linker_script(
      linker_app_smem_unaligned.cmd
      "-DLINKER_APP_SMEM_UNALIGNED"
      ${CODE_RELOCATION_DEP}
      ${APP_SMEM_UNALIGNED_DEP}
      ${APP_SMEM_UNALIGNED_LD}
      ${OFFSETS_H_TARGET}
      )

    add_custom_target(
      linker_app_smem_unaligned_script
      DEPENDS
      linker_app_smem_unaligned.cmd
      )

    set_property(TARGET
      linker_app_smem_unaligned_script
      PROPERTY INCLUDE_DIRECTORIES
      ${ZEPHYR_INCLUDE_DIRS}
      )

    set(APP_SMEM_UNALIGNED_LIB app_smem_unaligned_output_obj_renamed_lib)
    add_executable(       app_smem_unaligned_prebuilt misc/empty_file.c)
    target_link_libraries(app_smem_unaligned_prebuilt ${TOPT} ${PROJECT_BINARY_DIR}/linker_app_smem_unaligned.cmd ${zephyr_lnk} ${CODE_RELOCATION_DEP})
    set_property(TARGET   app_smem_unaligned_prebuilt PROPERTY LINK_DEPENDS ${PROJECT_BINARY_DIR}/linker_app_smem_unaligned.cmd)
    add_dependencies(     app_smem_unaligned_prebuilt linker_app_smem_unaligned_script ${OFFSETS_LIB})

    add_custom_command(
      OUTPUT ${APP_SMEM_ALIGNED_LD}
      COMMAND ${PYTHON_EXECUTABLE}
      ${ZEPHYR_BASE}/scripts/gen_app_partitions.py
      -e $<TARGET_FILE:app_smem_unaligned_prebuilt>
      -o ${APP_SMEM_ALIGNED_LD}
      ${NEWLIB_PART} ${MBEDTLS_PART}
      $<$<BOOL:${CMAKE_VERBOSE_MAKEFILE}>:--verbose>
      DEPENDS
      kernel
      ${ZEPHYR_LIBS_PROPERTY}
      app_smem_unaligned_prebuilt
      WORKING_DIRECTORY ${PROJECT_BINARY_DIR}/
      COMMENT "Generating app_smem_aligned linker section"
      )
  endif()

  ##CONSIDER
  if(CONFIG_USERSPACE AND CONFIG_ARM)
    configure_linker_script(
      linker_priv_stacks.cmd
      ""
      ${CODE_RELOCATION_DEP}
      ${APP_SMEM_ALIGNED_DEP}
      ${APP_SMEM_ALIGNED_LD}
      ${OFFSETS_H_TARGET}
      )

    add_custom_target(
      linker_priv_stacks_script
      DEPENDS
      linker_priv_stacks.cmd
      )

    set_property(TARGET
      linker_priv_stacks_script
      PROPERTY INCLUDE_DIRECTORIES
      ${ZEPHYR_INCLUDE_DIRS}
      )

    set(PRIV_STACK_LIB priv_stacks_output_obj_renamed_lib)
    add_executable(       priv_stacks_prebuilt misc/empty_file.c)
    target_link_libraries(priv_stacks_prebuilt ${TOPT} ${PROJECT_BINARY_DIR}/linker_priv_stacks.cmd ${zephyr_lnk} ${CODE_RELOCATION_DEP})
    set_property(TARGET   priv_stacks_prebuilt PROPERTY LINK_DEPENDS ${PROJECT_BINARY_DIR}/linker_priv_stacks.cmd)
    add_dependencies(     priv_stacks_prebuilt linker_priv_stacks_script ${OFFSETS_LIB})
  endif()
endmacro()



macro(toolchain_ld_prebuilt_configure)
  configure_linker_script(
    linker.cmd
    ""
    ${PRIV_STACK_DEP}
    ${APP_SMEM_ALIGNED_DEP}
    ${CODE_RELOCATION_DEP}
    ${OFFSETS_H_TARGET}
    )

  add_custom_target(
    ${LINKER_SCRIPT_TARGET}
    DEPENDS
    linker.cmd
    )

  # Give the '${LINKER_SCRIPT_TARGET}' target all of the include directories so
  # that cmake can successfully find the linker_script's header
  # dependencies.
  zephyr_get_include_directories_for_lang(C
    ZEPHYR_INCLUDE_DIRS
    STRIP_PREFIX # Don't use a -I prefix
    )
  set_property(TARGET
    ${LINKER_SCRIPT_TARGET}
    PROPERTY INCLUDE_DIRECTORIES
    ${ZEPHYR_INCLUDE_DIRS}
    )
endmacro()


  # FIXME: Is there any way to get rid of empty_file.c?
  add_executable(       ${ZEPHYR_PREBUILT_EXECUTABLE} misc/empty_file.c)
  target_link_libraries(${ZEPHYR_PREBUILT_EXECUTABLE} ${TOPT} ${PROJECT_BINARY_DIR}/linker.cmd ${PRIV_STACK_LIB} ${zephyr_lnk} ${CODE_RELOCATION_DEP})
  set_property(TARGET   ${ZEPHYR_PREBUILT_EXECUTABLE} PROPERTY LINK_DEPENDS ${PROJECT_BINARY_DIR}/linker.cmd)
  add_dependencies(     ${ZEPHYR_PREBUILT_EXECUTABLE} ${PRIV_STACK_DEP} ${LINKER_SCRIPT_TARGET} ${OFFSETS_LIB})
endmacro()


macro(toolchain_ld_final)
  # The second linker pass uses the same source linker script of the
  # first pass (LINKER_SCRIPT), but this time with a different output
  # file and preprocessed with the define LINKER_PASS2.
  configure_linker_script(
    linker_pass_final.cmd
    "-DLINKER_PASS2"
    ${PRIV_STACK_DEP}
    ${CODE_RELOCATION_DEP}
    ${ZEPHYR_PREBUILT_EXECUTABLE}
    ${OFFSETS_H_TARGET}
    )

  set(LINKER_PASS_FINAL_SCRIPT_TARGET linker_pass_final_script_target)
  add_custom_target(
    ${LINKER_PASS_FINAL_SCRIPT_TARGET}
    DEPENDS
    linker_pass_final.cmd
    )
  set_property(TARGET
    ${LINKER_PASS_FINAL_SCRIPT_TARGET}
    PROPERTY INCLUDE_DIRECTORIES
    ${ZEPHYR_INCLUDE_DIRS}
  )

  add_executable(       ${ZEPHYR_FINAL_EXECUTABLE} misc/empty_file.c ${GKSF})
  target_link_libraries(${ZEPHYR_FINAL_EXECUTABLE} ${GKOF} ${TOPT} ${PROJECT_BINARY_DIR}/linker_pass_final.cmd ${zephyr_lnk} ${CODE_RELOCATION_DEP})
  set_property(TARGET   ${ZEPHYR_FINAL_EXECUTABLE} PROPERTY LINK_DEPENDS ${PROJECT_BINARY_DIR}/linker_pass_final.cmd)
  add_dependencies(     ${ZEPHYR_FINAL_EXECUTABLE} ${PRIV_STACK_DEP} ${LINKER_PASS_FINAL_SCRIPT_TARGET})
endmacro()


# Load toolchain_ld-family macros
include(${ZEPHYR_BASE}/cmake/linker/${LINKER}/target_base.cmake)
include(${ZEPHYR_BASE}/cmake/linker/${LINKER}/target_baremetal.cmake)
include(${ZEPHYR_BASE}/cmake/linker/${LINKER}/target_cpp.cmake)
include(${ZEPHYR_BASE}/cmake/linker/${LINKER}/target_relocation.cmake)
include(${ZEPHYR_BASE}/cmake/linker/${LINKER}/target_userspace.cmake)
include(${ZEPHYR_BASE}/cmake/linker/${LINKER}/target_configure.cmake)
