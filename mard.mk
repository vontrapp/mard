# TODO upload rule
# TODO sane defaults for search paths?
# i think so...
# TODO include paths using only .h files, and doing so recursively
# TODO vpaths recursive, too
# TODO maybe do something different with board? maybe not generate makefile? maybe eval?
# TODO see if we can get rid of --allow-multiple-definition
# Here's some info on multiple defs errors:
# http://www.avrfreaks.net/index.php?name=PNphpBB2&file=printview&t=97763&start=0
# TODO could search $(HARDWARE)/cores/* for possible build_cores, and select from that a list of possible BOARDs and select the first?
#   probably not...

include board.mk

define DEFEVAL
ifndef $(1)
$(1)=$(2)
endif
endef

SETDEFAULT=$(eval $(call DEFEVAL,$(1),$(2)))
$(call SETDEFAULT,ARDUINO,/usr/share/arduino)
$(call SETDEFAULT,BOARD,$(CURBOARD))
$(call SETDEFAULT,BOARD,uno)
$(call SETDEFAULT,HARDWARE,$(ARDUINO)/hardware/arduino)
$(call SETDEFAULT,ALIBPATH,$(ARDUINO)/libraries)
$(call SETDEFAULT,TARGET,$(notdir $(CURDIR)))

CORE:=$(HARDWARE)/cores/$(BUILD_CORE)

# object lists for libraries
ALIBSEARCH=$(firstword $(wildcard $(addsuffix /$(1),$(ALIBPATH))))
ALIBINCPATH:=$(foreach alib,$(ALIBS),$(call ALIBSEARCH,$(alib)))
PATHSRC=$(filter %.c %.cpp,$(wildcard $(addsuffix /*,$(1))))
SRCO=$(addsuffix .o,$(basename $(1)))
ALIBSRC=$(call PATHSRC,$(call ALIBSEARCH,$(1)))
ALIBO=$(call SRCO,$(call ALIBSRC,$(1)))
COREO:=$(call SRCO,$(call PATHSRC,$(CORE)))

# alib and core ojects search paths
$(foreach file,$(basename $(notdir $(COREO))),$(eval vpath $(file).% $(CORE)))
$(foreach alib,$(ALIBS),$(foreach file,$(basename $(notdir $(call ALIBO,$(alib)))),$(eval vpath $(file).% $(call ALIBSEARCH,$(alib)))))

INCLUDES:=$(addprefix -I,$(CORE) $(ALIBINCPATH))

CPPFLAGS =-Wall
CPPFLAGS+=-mmcu=$(BUILD_MCU) -DF_CPU=$(BUILD_F_CPU) -DARDUINO=18
CPPFLAGS+=$(INCLUDES)
CPPFLAGS+=-Os#optimize
CPPFLAGS+=-ffunction-sections -fdata-sections
#CPPFLAGS+=-g#debug

CFLAGS=-std=gnu99
CXXFLAGS=-fno-exceptions -x c++
PDEFLAGS=$(addprefix -include $(CORE)/,$(addsuffix .h,$(basename $(COREH))))

LDFLAGS=-Os -Wl,--gc-sections -mmcu=$(BUILD_MCU) -Wl,--allow-multiple-definition

CC=avr-gcc
CXX=avr-g++
AR=avr-ar
OBJCOPY=avr-objcopy
OBJDUMP=avr-objdump
ASIZE=avr-size

ARD_OBJS := $(patsubst $(CORE)/%.c,%.o,$(wildcard $(CORE)/*.c))
ARD_OBJS := $(ARD_OBJS) $(patsubst $(CORE)/%.cpp,%.o,$(wildcard $(CORE)/*.cpp))

$(TARGET).$(BOARD).hex:

%.$(BOARD).elf: %.o $(addsuffix .a,$(ALIBS)) core.a
	$(CC) $(LDFLAGS) -o $@ $+

%.hex: %.elf
	$(OBJCOPY) -O ihex -R .eeprom $< $@

%.o: %.pde board.mk
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) $(PDEFLAGS) -o $@ -c $<

core.a: core.a($(notdir $(COREO)))
$(foreach alib,$(ALIBS),$(eval $(alib).a: $(alib).a($(notdir $(call ALIBO,$(alib))))))

board.mk:
	@echo Making $@ for $(BOARD)
	grep -q ^$(BOARD)\\. $(HARDWARE)/boards.txt
	echo CURBOARD=$(BOARD) > board.mk
	grep ^$(BOARD)\\. $(HARDWARE)/boards.txt |\
cut -d. -f2- |\
sed -e 's/^.*=/\U&/; s/\.\(.*=\)/_\1/g' | tee -a $@

ifneq ($(BOARD),$(CURBOARD))
board.mk: clean
endif

.PHONY: clean clean-all upload .FORCE
clean:
	rm -f *.a *.o $(TARGET).$(BOARD).elf $(TARGET).$(BOARD).hex

# clean up all (known) boards
clean-all:
	rm -f *.elf *.hex
