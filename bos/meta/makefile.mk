# Copyright (C) 2015-2022
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program; if not, write to the Free Software Foundation,
# Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

#----------------------------
MAKEFLAGS += -rR
#----------------------------
NAME ?= DEMO
ICON ?=
DESCRIPTION ?=
COMPRESSED ?= NO
ARCHIVED ?= NO
BSSHEAP_LOW ?= D052C6
BSSHEAP_HIGH ?= D13FD8
STACK_HIGH ?= D1A87E
ifeq ($(BOS_APP),YES)
INIT_LOC ?= 0
else
INIT_LOC ?= D1A881
endif
OUTPUT_MAP ?= YES
CFLAGS ?= -Wall -Wextra -Oz
CXXFLAGS ?= -Wall -Wextra -Oz
LTOFLAGS ?= $(CFLAGS)
LTO ?= YES
SRCDIR ?= src
OBJDIR ?= bosobj
BINDIR ?= bosbin
GFXDIR ?= src/gfx
CPP_EXTENSION = cpp
C_EXTENSION = c
CUSTOM_FILE_FILE ?= stdio_file.h
DEPS ?=
HAS_UPPERCASE_NAME ?= YES
HAS_PRINTF ?= YES
HAS_CUSTOM_FILE ?= NO
HAS_LIBC ?= YES
HAS_LIBCXX ?= YES
PREFER_OS_CRT ?= NO
PREFER_OS_LIBC ?= YES
LIBLOAD_OPTIONAL ?=
COMPRESSED_MODE ?= zx7
#----------------------------
CEDEV_TOOLCHAIN ?= $(shell cedev-config --prefix)
CEDEV_TOOLCHAIN_BOS ?= $(CEDEV_TOOLCHAIN)/bos
#----------------------------

# define some common makefile things
empty :=
space := $(empty) $(empty)
comma := ,

# configure defaults
DEBUGMODE := NDEBUG
CCDEBUG := -g0
LDDEBUG := 0
LDPREFER_OS_CRT := 0
LDPREFER_OS_LIBC := 0
LDHAS_PRINTF := 0
LDHAS_LIBC := 0
LDHAS_LIBCXX := 0

# verbosity
V ?= 0
ifeq ($(V),0)
Q = @
FASMG_V := -n
else
Q =
FASMG_V := -v$(V)
endif

BIN ?= $(CEDEV_TOOLCHAIN)/bin
# get the os specific items
ifeq ($(OS),Windows_NT)
SHELL = cmd.exe
NATIVEPATH = $(subst /,\,$1)
FASMG = $(call NATIVEPATH,$(BIN)/fasmg.exe)
CONVBIN = $(call NATIVEPATH,$(BIN)/convbin.exe)
CONVIMG = $(call NATIVEPATH,$(BIN)/convimg.exe)
CEMUTEST = $(call NATIVEPATH,$(BIN)/cemu-autotester.exe)
CC = $(call NATIVEPATH,$(BIN)/ez80-clang.exe)
LINK = $(call NATIVEPATH,$(BIN)/ez80-link.exe)
RM = ( del /q /f $1 2>nul || call )
RMDIR = ( rmdir /s /q $1 2>nul || call )
NATIVEMKDR = ( mkdir $1 2>nul || call )
QUOTE_ARG = "$(subst ",',$1)"#'
else
NATIVEPATH = $(subst \,/,$1)
FASMG = $(call NATIVEPATH,$(BIN)/fasmg)
CONVBIN = $(call NATIVEPATH,$(BIN)/convbin)
CONVIMG = $(call NATIVEPATH,$(BIN)/convimg)
CEMUTEST = $(call NATIVEPATH,$(BIN)/cemu-autotester)
CC = $(call NATIVEPATH,$(BIN)/ez80-clang)
LINK = $(call NATIVEPATH,$(BIN)/ez80-link)
RM = rm -f $1
RMDIR = rm -rf $1
NATIVEMKDR = mkdir -p $1
QUOTE_ARG = '$(subst ','\'',$1)'#'
endif

MKDIR = $(call NATIVEMKDR,$(call QUOTE_ARG,$(call NATIVEPATH,$1)))
UPDIR_ADD = $(subst ../,_../,$(subst \,/,$1))
UPDIR_RM = $(subst _../,../,$(subst \,/,$1))

FASMG_LIB = $(patsubst %,"%",$(subst ",\",$(subst \,\\,$(call NATIVEPATH,$1))))
FASMG_FILES = $(subst $(space),$(comma) ,$(patsubst %,"%",$(subst ",\",$(subst \,\\,$(call NATIVEPATH,$1)))))#"
LINKER_SCRIPT ?= $(CEDEV_TOOLCHAIN_BOS)/meta/linker_script

# ensure native paths
SRCDIR := $(call NATIVEPATH,$(SRCDIR))
OBJDIR := $(call NATIVEPATH,$(OBJDIR))
BINDIR := $(call NATIVEPATH,$(BINDIR))
GFXDIR := $(call NATIVEPATH,$(GFXDIR))

# generate default names
TARGETBIN ?= $(NAME).bin
TARGETMAP ?= $(NAME).map
ICONIMG := $(wildcard $(call NATIVEPATH,$(ICON)))

# startup routines
ifeq ($(BOS_APP),YES)
LDFLAGS += -i $(call QUOTE_ARG,BOS_APP:)
endif
LDCRT0 = $(call NATIVEPATH,$(CEDEV_TOOLCHAIN_BOS)/lib/crt/crt0.src)
LDBCLTO = $(OBJDIR)/lto.bc
LDLTO = $(OBJDIR)/lto.src

# source: http://blog.jgc.org/2011/07/gnu-make-recursive-wildcard-function.html
rwildcard = $(strip $(foreach d,$(wildcard $1/*),$(call rwildcard,$d,$2) $(filter $(subst %%,%,%$(subst *,%,$2)),$d)))

# compatibility with older makefiles
EXTRA_HEADERS += $(EXTRA_USERHEADERS)
EXTRA_C_SOURCES += $(EXTRA_CSOURCES)
EXTRA_CXX_SOURCES += $(EXTRA_CPPSOURCES)
EXTRA_ASM_SOURCES += $(EXTRA_ASMSOURCES)

# find source files
CSOURCES = $(sort $(call rwildcard,$(SRCDIR),*.$(C_EXTENSION)) $(EXTRA_C_SOURCES))
CPPSOURCES = $(sort $(call rwildcard,$(SRCDIR),*.$(CPP_EXTENSION)) $(EXTRA_CXX_SOURCES))
ASMSOURCES = $(sort $(call rwildcard,$(SRCDIR),*.asm) $(EXTRA_ASM_SOURCES))

ifneq ($(filter debug,$(MAKECMDGOALS)),)
LTO := NO
endif
ifeq ($(LTO),YES)
LINK_CSOURCES = $(call UPDIR_ADD,$(CSOURCES:%.$(C_EXTENSION)=$(OBJDIR)/%.$(C_EXTENSION).bc))
LINK_CPPSOURCES = $(call UPDIR_ADD,$(CPPSOURCES:%.$(CPP_EXTENSION)=$(OBJDIR)/%.$(CPP_EXTENSION).bc))
LINK_ASMSOURCES = $(ASMSOURCES)
LTOFILES = $(LINK_CSOURCES) $(LINK_CPPSOURCES)
LDFILES = $(LDCRT0) $(LDLTO) $(LINK_ASMSOURCES)
DEPFILES = $(wildcard $(LINK_CSOURCES:%.bc=%.d) $(LINK_CPPSOURCES:%.bc=%.d))
else
LINK_CSOURCES = $(call UPDIR_ADD,$(CSOURCES:%.$(C_EXTENSION)=$(OBJDIR)/%.$(C_EXTENSION).src))
LINK_CPPSOURCES = $(call UPDIR_ADD,$(CPPSOURCES:%.$(CPP_EXTENSION)=$(OBJDIR)/%.$(CPP_EXTENSION).src))
LINK_ASMSOURCES = $(ASMSOURCES)
LDFILES = $(LDCRT0) $(LINK_CSOURCES) $(LINK_CPPSOURCES) $(LINK_ASMSOURCES)
DEPFILES = $(wildcard $(LINK_CSOURCES:%.src=%.d) $(LINK_CPPSOURCES:%.src=%.d))
endif

# find all required/optional libload libraries
LIBLOAD_LIBS ?= $(wildcard $(CEDEV_TOOLCHAIN_BOS)/lib/libload/*.lib) $(EXTRA_LIBLOAD_LIBS)
LIBLOAD_LIBS := $(filter-out %libload.lib,$(LIBLOAD_LIBS))
REQ_LIBLOAD := $(filter-out $(addprefix %,$(addsuffix .lib,$(LIBLOAD_OPTIONAL))),$(LIBLOAD_LIBS))
OPT_LIBLOAD := $(filter $(addprefix %,$(addsuffix .lib,$(LIBLOAD_OPTIONAL))),$(LIBLOAD_LIBS))
REQ_LIBLOAD := $(call FASMG_LIB,$(REQ_LIBLOAD))
OPT_LIBLOAD := $(call FASMG_LIB,$(OPT_LIBLOAD))
OPT_LIBLOAD := $(foreach lib,$(OPT_LIBLOAD),$(lib)$(space)optional)
LDLIBS := $(subst $(space),$(comma)$(space),$(strip $(REQ_LIBLOAD)$(space)$(OPT_LIBLOAD)))
LDLIBS := $(subst $(comma)$(space)optional,$(space)optional,$(LDLIBS))

# check if there is an icon present that to convert
ifneq ($(ICONIMG),)
ICONSRC ?= $(call NATIVEPATH,$(OBJDIR)/icon.src)
ifneq ($(DESCRIPTION),)
ICON_CONV ?= $(CONVIMG) --icon $(call QUOTE_ARG,$(ICONIMG)) --icon-output $(call QUOTE_ARG,$(ICONSRC)) --icon-format asm --icon-description $(DESCRIPTION)
else
ICON_CONV ?= $(CONVIMG) --icon $(call QUOTE_ARG,$(ICONIMG)) --icon-output $(call QUOTE_ARG,$(ICONSRC)) --icon-format asm
endif
LDICON ?= $(call FASMG_FILES,$(ICONSRC))$(comma)$(space)
else
ifneq ($(DESCRIPTION),)
ICONSRC ?= $(call NATIVEPATH,$(OBJDIR)/icon.src)
ICON_CONV ?= $(CONVIMG) --icon-output $(call QUOTE_ARG,$(ICONSRC)) --icon-format asm --icon-description $(DESCRIPTION)
LDICON ?= $(call FASMG_FILES,$(ICONSRC))$(comma)$(space)
endif
endif

# set default 'make gfx' target
ifneq ($(wildcard $(GFXDIR)/.),)
MAKE_GFX ?= cd $(GFXDIR) && $(CONVIMG)
endif

# output debug map file
ifeq ($(OUTPUT_MAP),YES)
LDMAPFLAG := -i map
endif
ifeq ($(HAS_CUSTOM_FILE),YES)
DEFCUSTOMFILE := -DHAS_CUSTOM_FILE=1 -DCUSTOM_FILE_FILE=\"$(CUSTOM_FILE_FILE)\"
endif

# convert to linker crt/libc define
ifeq ($(PREFER_OS_CRT),YES)
LDPREFER_OS_CRT := 1
endif
ifeq ($(PREFER_OS_LIBC),YES)
LDPREFER_OS_LIBC := 1
endif
ifeq ($(HAS_LIBC),YES)
LDHAS_LIBC := 1
endif
ifeq ($(HAS_LIBCXX),YES)
LDHAS_LIBCXX := 1
endif
ifeq ($(HAS_PRINTF),YES)
LDHAS_PRINTF := 1
endif

# define the c/c++ flags used by clang
EZLLVMFLAGS = -mllvm -profile-guided-section-prefix=false
EZCOMMONFLAGS = -nostdinc -isystem $(call NATIVEPATH,$(CEDEV_TOOLCHAIN_BOS)/include) -I$(SRCDIR) -fno-threadsafe-statics -Xclang -fforce-mangle-main-argc-argv $(EZLLVMFLAGS) -D$(DEBUGMODE) $(DEFCUSTOMFILE) $(CCDEBUG)
EZCFLAGS = $(EZCOMMONFLAGS) $(CFLAGS)
EZCXXFLAGS = $(EZCOMMONFLAGS) -isystem $(call NATIVEPATH,$(CEDEV_TOOLCHAIN_BOS)/include/c++) -fno-exceptions -fno-use-cxa-atexit $(CXXFLAGS)
EZLTOFLAGS = $(EZLLVMFLAGS) $(LTOFLAGS)

# these are the fasmg linker flags
FASMGFLAGS = \
	$(FASMG_V) \
	$(call QUOTE_ARG,$(call NATIVEPATH,$(CEDEV_TOOLCHAIN_BOS)/meta/ld.alm)) \
	-i $(call QUOTE_ARG,DEBUG := $(LDDEBUG)) \
	-i $(call QUOTE_ARG,HAS_PRINTF := $(LDHAS_PRINTF)) \
	-i $(call QUOTE_ARG,HAS_LIBC := $(LDHAS_LIBC)) \
	-i $(call QUOTE_ARG,HAS_LIBCXX := $(LDHAS_LIBCXX)) \
	-i $(call QUOTE_ARG,PREFER_OS_CRT := $(LDPREFER_OS_CRT)) \
	-i $(call QUOTE_ARG,PREFER_OS_LIBC := $(LDPREFER_OS_LIBC)) \
	-i $(call QUOTE_ARG,include $(call FASMG_FILES,$(LINKER_SCRIPT))) \
	-i $(call QUOTE_ARG,range .bss $$$(BSSHEAP_LOW) : $$$(BSSHEAP_HIGH)) \
	-i $(call QUOTE_ARG,provide __stack = $$$(STACK_HIGH)) \
	-i $(call QUOTE_ARG,locate .header at $$$(INIT_LOC)) \
	$(LDMAPFLAG) \
	-i $(call QUOTE_ARG,source $(LDICON)$(call FASMG_FILES,$(LDFILES))) \
	-i $(call QUOTE_ARG,library $(LDLIBS)) \
	$(EXTRA_LDFLAGS)

.PHONY: all clean version gfx debug

# this rule is trigged to build everything
all: $(BINDIR)/$(TARGETBIN)

# this rule is trigged to build debug everything
debug: DEBUGMODE = DEBUG
debug: LDDEBUG = 1
debug: CCDEBUG = -gdwarf-5 -g3
debug: $(BINDIR)/$(TARGETBIN)

$(BINDIR)/$(TARGETBIN): $(LDFILES) $(ICONSRC) $(MAKEFILE_LIST) $(DEPS)
	$(Q)$(call MKDIR,$(@D))
	$(Q)echo [linking] $(call NATIVEPATH,$@)
	$(Q)$(FASMG) $(FASMGFLAGS) $(call NATIVEPATH,$@)
ifeq ($(COMPRESSED),YES)
	$(Q)echo [compressing] $(call NATIVEPATH,$@.zx7)
	$(Q)$(CONVBIN) -i $(call NATIVEPATH,$@) -o $(call NATIVEPATH,$@.zx7) -j bin -k bin -e zx7
	$(Q)$(FASMGLD) -i $(call QUOTE_ARG,DATA_FILE = $(call QUOTE_ARG,$@.zx7)) $(call NATIVEPATH,$(CEDEV_TOOLCHAIN_BOS)/lib/compressed_rex.asm) $(call NATIVEPATH,$@)
endif
ifneq ($(ICONSRC),)
$(ICONSRC): $(ICONIMG) $(MAKEFILE_LIST) $(DEPS)
	$(Q)$(call MKDIR,$(@D))
	$(Q)echo [convimg] $(or $(ICONIMG),description)
	$(Q)$(ICON_CONV)
endif

clean:
	$(Q)$(EXTRA_CLEAN)
	$(Q)$(call RMDIR,$(OBJDIR) $(BINDIR))
	$(Q)echo Removed built binaries and objects.

gfx:
	$(Q)$(MAKE_GFX)

test:
	$(Q)$(CEMUTEST) $(call NATIVEPATH,$(CURDIR)/autotest.json)

version:
	$(Q)echo CE C/C++ Toolchain $(shell cedev-config --version)

.SECONDEXPANSION:

# no lto
$(OBJDIR)/%.$(C_EXTENSION).src: $$(call UPDIR_RM,$$*).$(C_EXTENSION) $(EXTRA_HEADERS) $(MAKEFILE_LIST) $(DEPS)
	$(Q)$(call MKDIR,$(@D))
	$(Q)echo [compiling] $(call NATIVEPATH,$<)
	$(Q)$(CC) -S -MD $(EZCFLAGS) $(call QUOTE_ARG,$<) -o $(call QUOTE_ARG,$@)

$(OBJDIR)/%.$(CPP_EXTENSION).src: $$(call UPDIR_RM,$$*).$(CPP_EXTENSION) $(EXTRA_HEADERS) $(MAKEFILE_LIST) $(DEPS)
	$(Q)$(call MKDIR,$(@D))
	$(Q)echo [compiling] $(call NATIVEPATH,$<)
	$(Q)$(CC) -S -MD $(EZCXXFLAGS) $(call QUOTE_ARG,$<) -o $(call QUOTE_ARG,$@)

# lto
$(LDLTO): $(LDBCLTO)
	$(Q)$(CC) -S $(EZLTOFLAGS) $(call QUOTE_ARG,$(addprefix $(CURDIR)/,$<)) -o $(call QUOTE_ARG,$(addprefix $(CURDIR)/,$@))

$(LDBCLTO): $(LTOFILES)
	$(Q)echo [lto opt] $(call NATIVEPATH,$@)
	$(Q)$(LINK) $(foreach d,$^,$(call QUOTE_ARG,$(addprefix $(CURDIR)/,$d))) -o $(call QUOTE_ARG,$(addprefix $(CURDIR)/,$@))

$(OBJDIR)/%.$(C_EXTENSION).bc: $$(call UPDIR_RM,$$*).$(C_EXTENSION) $(EXTRA_HEADERS) $(MAKEFILE_LIST) $(DEPS)
	$(Q)$(call MKDIR,$(@D))
	$(Q)echo [compiling] $(call NATIVEPATH,$<)
	$(Q)$(CC) -MD -c -emit-llvm $(EZCFLAGS) $(call QUOTE_ARG,$<) -o $(call QUOTE_ARG,$@)

$(OBJDIR)/%.$(CPP_EXTENSION).bc: $$(call UPDIR_RM,$$*).$(CPP_EXTENSION) $(EXTRA_HEADERS) $(MAKEFILE_LIST) $(DEPS)
	$(Q)$(call MKDIR,$(@D))
	$(Q)echo [compiling] $(call NATIVEPATH,$<)
	$(Q)$(CC) -MD -c -emit-llvm $(EZCXXFLAGS) $(call QUOTE_ARG,$<) -o $(call QUOTE_ARG,$@)

ifeq ($(filter clean gfx test version,$(MAKECMDGOALS)),)
-include $(DEPFILES)
endif
