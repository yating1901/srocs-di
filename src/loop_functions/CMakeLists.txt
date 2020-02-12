add_library(di_srocs_loop_functions MODULE
   di_srocs_loop_functions.h
   di_srocs_loop_functions.cpp)

target_link_libraries(di_srocs_loop_functions
   ${SROCS_ENTITIES_LIBRARY})

