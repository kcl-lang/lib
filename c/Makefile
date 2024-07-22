# Directories
KCL_LIB_PATH = $(PWD)/target/release
KCL_LIB = -L$(KCL_LIB_PATH) -Wl,-rpath,$(KCL_LIB_PATH) -lkcl_lib_c
INCLUDE_DIR = include
LIB_DIR = lib
SRC_DIR = src
BUILD_DIR = build

# Example directories
EXAMPLES=$(wildcard ./examples/*.c)
EXAMPLE_OBJECTS=$(EXAMPLES:.c=.o)
EXAMPLE_TARGETS=$(EXAMPLES:.c=)

# Source Files
LIB_SOURCES = $(LIB_DIR)/pb_common.c $(LIB_DIR)/pb_decode.c $(LIB_DIR)/pb_encode.c $(LIB_DIR)/spec.pb.c
LIB_OBJECTS = $(addprefix $(BUILD_DIR)/, $(notdir $(LIB_SOURCES:.c=.o)))

# Static lib output
STATIC_LIB = $(LIB_DIR)/libkcl_lib_c.a

# CC flags
CCFLAGS=-I./include
CXXFLAGS=-I./include -std=c++14

all: cargo $(STATIC_LIB)

debug: CFLAGS += -g
debug: all

.PHONY: fmt
fmt:
	cargo fmt
	find . -name '*.cpp' -exec clang-format -i --style=WebKit --verbose {} \;
	find . -name '*.c' -exec clang-format -i --style=WebKit --verbose {} \;

.PHONY: cargo
cargo:
	cargo build -r

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/%.o: $(LIB_DIR)/%.c | $(BUILD_DIR)
	$(CC) $(CCFLAGS) -c $< -o $@

$(STATIC_LIB): $(LIB_OBJECTS)
	ar rcs $@ $^

.PHONY: examples
examples: $(STATIC_LIB) $(EXAMPLE_TARGETS)

$(EXAMPLE_TARGETS): % : %.o
	$(CC) $(CCFLAGS) -o $@ $^ $(KCL_LIB) $(STATIC_LIB)

%.o: %.c
	$(CC) $(CCFLAGS) -c $< -o $@

run: examples
	./examples/exec_api

.PHONY: clean
clean:
	rm -rf $(BUILD_DIR) *.o $(EXECUTABLE) $(STATIC_LIB)
	rm -rf $(EXAMPLE_OBJECTS)
	rm -rf $(EXAMPLE_TARGETS)
