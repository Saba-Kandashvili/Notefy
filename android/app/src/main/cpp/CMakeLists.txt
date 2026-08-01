cmake_minimum_required(VERSION 3.4.1)

find_package(oboe REQUIRED CONFIG)

add_library( 
    native_tuner # This is the name of the library (libnative_tuner.so)
    SHARED       # It creates a .so file
    notefy.cpp   # The source file
    synth_engine.cpp
)

# Optimization flags for release builds
target_compile_options(native_tuner PRIVATE
    -O3
    -ffast-math
    -fno-rtti
)

# Enable NEON SIMD for ARM (important for audio processing performance)
if(ANDROID_ABI STREQUAL "armeabi-v7a")
    target_compile_options(native_tuner PRIVATE -mfpu=neon)
endif()

# Link against the standard C++ library
target_link_libraries(native_tuner
    log
    oboe::oboe
)
