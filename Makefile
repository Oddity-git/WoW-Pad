# wowpad - x86 version.dll proxy for WoW 3.3.5a under Wine
# make's built-in CXX default (g++) would win over ?=, so override it explicitly
ifeq ($(origin CXX),default)
CXX      := i686-w64-mingw32-g++
endif
OBJDUMP  ?= i686-w64-mingw32-objdump
VERSION ?= 1.4.0

BUILD    := build
SRCS     := $(wildcard src/*.cpp)
OBJS     := $(patsubst src/%.cpp,$(BUILD)/%.o,$(SRCS))

CXXFLAGS := -O2 -std=c++17 -Wall -Wextra -Wno-cast-function-type \
            -fno-exceptions -fno-rtti \
            -DWIN32_LEAN_AND_MEAN -D_WIN32_WINNT=0x0601 -DUNICODE -D_UNICODE \
            -DWOWPAD_VERSION=\"$(VERSION)\"
LDFLAGS  := -shared -static -static-libgcc -static-libstdc++ \
            -Wl,--enable-stdcall-fixup -s
LIBS     := -lkernel32 -luser32 -lgdi32

.PHONY: all clean exports
all: $(BUILD)/version.dll

$(BUILD)/%.o: src/%.cpp $(wildcard src/*.h) | $(BUILD)
	$(CXX) $(CXXFLAGS) -c $< -o $@

$(BUILD)/version.dll: $(OBJS) src/version.def
	$(CXX) -o $@ $(OBJS) src/version.def $(LDFLAGS) $(LIBS)

$(BUILD):
	mkdir -p $@

exports: $(BUILD)/version.dll
	$(OBJDUMP) -p $< | sed -n '/\[Ordinal\/Name Pointer\] Table/,/^$$/p'
	$(OBJDUMP) -p $< | grep 'DLL Name'

clean:
	rm -rf $(BUILD)
