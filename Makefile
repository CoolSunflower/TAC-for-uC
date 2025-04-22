CXX := g++
BISON := bison
FLEX := flex
CXXFLAGS := -std=c++17 -Isrc -Ibuild # Include src and build directories
LDFLAGS :=

TARGET := microC_translator

# Default target
all: $(TARGET)

# Link the executable
$(TARGET): build/a9_220101003.o build/a9_220101003.tab.o build/lex.yy.o
	$(CXX) $(LDFLAGS) $^ -o $@

# Compile main C++ source
build/a9_220101003.o: src/a9_220101003.cpp build/a9_220101003.tab.hpp src/a9_220101003.h
	@mkdir -p build # Ensure build directory exists
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile Bison generated C++ file
build/a9_220101003.tab.o: build/a9_220101003.tab.cpp build/a9_220101003.tab.hpp
	@mkdir -p build
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Compile Flex generated C++ file
build/lex.yy.o: build/lex.yy.cpp build/a9_220101003.tab.hpp
	@mkdir -p build
	$(CXX) $(CXXFLAGS) -c $< -o $@

# Generate Bison parser files (header and source)
build/a9_220101003.tab.cpp build/a9_220101003.tab.hpp: src/a9_220101003.y src/a9_220101003.h
	@mkdir -p build
	$(BISON) -d -o build/a9_220101003.tab.cpp src/a9_220101003.y

# Generate Flex scanner file
build/lex.yy.cpp: src/a9_220101003.l build/a9_220101003.tab.hpp
	@mkdir -p build
	$(FLEX) -o build/lex.yy.cpp src/a9_220101003.l

# Clean rule
clean:
	rm -rf build $(TARGET)

# Phony targets
.PHONY: all clean