cmake_minimum_required(VERSION 3.4.1)

add_library( 
    native_tuner # This is the name of the library (libnative_tuner.so)
    SHARED       # It creates a .so file
    notefy.cpp   # The source file
)
