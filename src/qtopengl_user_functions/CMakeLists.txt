#
# Create the DC QtOpenGL user functions library
#
add_library(di_qtopengl_user_functions MODULE
  di_qtopengl_user_functions.h
  di_qtopengl_user_functions.cpp)

target_link_libraries(di_qtopengl_user_functions
  ${SROCS_ENTITIES_LIBRARY}
  ${ARGOS_QTOPENGL_LIBRARY})
