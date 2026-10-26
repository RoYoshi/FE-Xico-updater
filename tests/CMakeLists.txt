find_package(Python3 REQUIRED COMPONENTS Interpreter)
add_executable(test-native-updater
    test_native_updater.cpp
    ../src/native_operation.cpp
    ../src/utils.cpp ../src/utils.h
    ../src/components/console/console.cpp ../src/components/console/console.h
)
target_include_directories(test-native-updater PRIVATE ../src ../src/components/console)
target_compile_definitions(test-native-updater PRIVATE
    FIXTURE_PATH="${CMAKE_CURRENT_SOURCE_DIR}/mock_process.py"
    PYTHON_PATH="${Python3_EXECUTABLE}")
target_link_libraries(test-native-updater PRIVATE Qt6::Test Qt6::Widgets Qt6::Qml Qt6::DBus KF6::ColorScheme KF6::I18n)
add_test(NAME native-updater COMMAND test-native-updater)
set_tests_properties(native-updater PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen" TIMEOUT 30)
