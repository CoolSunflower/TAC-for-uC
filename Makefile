# Makefile for Micro C Compiler (Phase 1)

# Compiler and Tools
CXX = g++
BISON = bison
FLEX = flex

# Flags
# CXXFLAGS: Flags for C++ compilation (-g for debug symbols)
CXXFLAGS = -std=c++11 -g
# LDFLAGS: Flags for linking (usually empty unless specifying library paths)
LDFLAGS =
# LDLIBS: Libraries to link against (-lfl for flex library)
LDLIBS = -lfl
# BISONFLAGS: Flags for Bison (-d to generate the header file)
BISONFLAGS = -d
# FLEXFLAGS: Flags for Flex (none needed currently)
FLEXFLAGS =

# Source Files
PARSER_SRC = a9_220101003.y
LEXER_SRC  = a9_220101003.l
TRANSLATOR_SRC = a9_220101003.cpp
TRANSLATOR_HDR = a9_220101003.h

# Generated Files (Basenames)
# Note: Bison needs explicit -o for .cpp output, header follows from -d
PARSER_GEN_BASE = a9_220101003.tab
PARSER_GEN_CPP = $(PARSER_GEN_BASE).cpp
PARSER_GEN_HPP = $(PARSER_GEN_BASE).hpp
# Note: Flex needs explicit -o for .cpp output
LEXER_GEN_BASE = lex.yy
LEXER_GEN_CPP = $(LEXER_GEN_BASE).cpp

# Object Files
# Compiler implicitly creates <basename>.o from <basename>.cpp if -o is omitted with -c
PARSER_OBJ = $(PARSER_GEN_BASE).o
LEXER_OBJ  = $(LEXER_GEN_BASE).o
TRANSLATOR_OBJ = a9_220101003.o
OBJS = $(PARSER_OBJ) $(LEXER_OBJ) $(TRANSLATOR_OBJ)

# Target Executable
TARGET = microc_compiler

# Default Goal: Build the executable
all: $(TARGET)

# Rule to link the final executable
# The -o flag is REQUIRED here to name the output executable
$(TARGET): $(OBJS)
	$(CXX) $(LDFLAGS) $(OBJS) $(LDLIBS) -o $(TARGET)
	@echo "Build complete. Executable: $(TARGET)"

# --- Compilation Rules ---
# Compile the generated parser source code.
# Depends on its source, its header, and the translator header.
# Omitting -o $(PARSER_OBJ) makes g++ create $(PARSER_GEN_BASE).o by default.
$(PARSER_OBJ): $(PARSER_GEN_CPP) $(PARSER_GEN_HPP) $(TRANSLATOR_HDR)
	$(CXX) $(CXXFLAGS) -c $(PARSER_GEN_CPP)

# Compile the generated lexer source code.
# Depends on its source and the parser's generated header.
# Omitting -o $(LEXER_OBJ) makes g++ create $(LEXER_GEN_BASE).o by default.
$(LEXER_OBJ): $(LEXER_GEN_CPP) $(PARSER_GEN_HPP)
	$(CXX) $(CXXFLAGS) -c $(LEXER_GEN_CPP)

# Compile the translator source code.
# Depends on its source and its header.
# Omitting -o $(TRANSLATOR_OBJ) makes g++ create a9_220101003.o by default.
$(TRANSLATOR_OBJ): $(TRANSLATOR_SRC) $(TRANSLATOR_HDR)
	$(CXX) $(CXXFLAGS) -c $(TRANSLATOR_SRC)

# --- Generation Rules ---
# Rule to generate parser source and header from Bison file.
# Bison needs '-o <output.cpp>' to name the C++ output correctly.
# The header file name is derived automatically by Bison's -d flag.
# Both generated files depend on the .y file.
$(PARSER_GEN_CPP) $(PARSER_GEN_HPP): $(PARSER_SRC)
	$(BISON) $(BISONFLAGS) -o $(PARSER_GEN_CPP) $(PARSER_SRC)

# Rule to generate lexer source from Flex file.
# Flex needs '-o <output.cpp>' to name the C++ output correctly.
# Depends on the .l file and also the parser's header file (for tokens/YYSTYPE).
$(LEXER_GEN_CPP): $(LEXER_SRC) $(PARSER_GEN_HPP)
	$(FLEX) $(FLEXFLAGS) -o $(LEXER_GEN_CPP) $(LEXER_SRC)

# --- Cleanup Rule ---
# Remove generated files and the executable
clean:
	@echo "Cleaning up generated files..."
	rm -f $(TARGET) $(OBJS) $(PARSER_GEN_CPP) $(PARSER_GEN_HPP) $(LEXER_GEN_CPP)

# Phony targets are not files
.PHONY: all clean

