# Define the C compiler and flags
CC = gcc
# Define compiler flags
# -Wall enables all warnings, then -Wno-unused-function disables just this one.
CFLAGS = -Wall -g -Wno-unused-function

# Define the final executable name
EXEC = compiler

# Define source files that need to be compiled
SRCS = parser.tab.c lex.yy.c

# Default target: build the compiler
all: clean $(EXEC) test

# Rule to link the final executable
$(EXEC): $(SRCS)
	$(CC) $(CFLAGS) -o $(EXEC) $(SRCS) -lfl

# Rule to generate the parser from the bison file
parser.tab.c: parser.y
	bison -d parser.y

# Rule to generate the lexer from the flex file
lex.yy.c: lexer.l parser.tab.h
	flex lexer.l

# Phony targets are actions, not files
.PHONY: test clean

# The 'test' target runs all input files through the compiler
test: $(EXEC)
	@echo "--- Running Tests ---"
	@mkdir -p output
	@$(MAKE) --no-print-directory $(patsubst input/%.svgl,output/%.svg,$(wildcard input/*.svgl))
	@echo "--- Tests completed. Check output/ folder. ---"

# Rule for processing a single input file
output/%.svg: input/%.svgl $(EXEC)
	@echo "Compiling $< -> $@"
	@./$(EXEC) < $< > $@ 2> $@.err
	@# Check if the error file has content. If it does, show an error.
	@if [ -s $@.err ]; then \
		echo "ERROR during compilation of $<. See details in $@.err"; \
	else \
		rm -f $@.err; \
	fi
	@# Create a .txt copy for easy viewing in a text editor
	@cp $@ $@.txt

# The 'clean' target removes all generated files
clean:
	@echo "Cleaning up generated files..."
	rm -f $(EXEC) parser.tab.c parser.tab.h lex.yy.c
	rm -rf output