cmake_minimum_required(VERSION 3.4.1)

add_library( 
    notefy # This is the name of the library
    SHARED       # It creates a .so file
    notefy.cpp # The source file
)
