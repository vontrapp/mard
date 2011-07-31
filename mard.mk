BOARD=atmega328

include board.mk

HARDWARE=/usr/share/arduino/hardware/arduino
CORE:=$(HARDWARE)/cores/$(BUILD_CORE)
ALIBPATH=/usr/share/arduino/libraries libs
ALIBS=Wire MeetAndroid

# object lists for libraries
ALIBSEARCH=$(firstword $(wildcard $(addsuffix /$(1),$(ALIBPATH))))
ALIBINCPATH:=$(foreach AL,$(ALIBS),$(call ALIBSEARCH,$(AL)))
PATHSRC=$(filter %.c %.cpp,$(wildcard $(addsuffix /*,$(1))))
SRCO=$(addsuffix .o,$(basename $(1)))
ALIBSRC=$(call PATHSRC,$(call ALIBSEARCH,$(1)))
ALIBO=$(call SRCO,$(call ALIBSRC,$(1)))
COREO:=$(call SRCO,$(call PATHSRC,$(CORE)))

# alib and core ojects search paths
$(foreach file,$(basename $(notdir $(COREO))),$(eval vpath $(file).% $(CORE)))
$(foreach alib,$(ALIBS),$(foreach file,$(basename $(notdir $(call ALIBO,$(alib)))),$(eval vpath $(file).% $(call ALIBSEARCH,$(alib)))))

INCLUDES:=$(addprefix -I,$(CORE) $(ALIBINCPATH) /usr/lib/avr/include/util)

CPPFLAGS =-Wall
CPPFLAGS+=-mmcu=$(BUILD_MCU) -DF_CPU=$(BUILD_F_CPU) -DARDUINO=18
CPPFLAGS+=$(INCLUDES)
CPPFLAGS+=-Os#optimize
CPPFLAGS+=-ffunction-sections -fdata-sections 
#CPPFLAGS+=-g#debug

CFLAGS=-std=gnu99
CXXFLAGS=-fno-exceptions -x c++

LDFLAGS=-Os -Wl,--gc-sections -mmcu=$(BUILD_MCU) -Wl,--allow-multiple-definition

CC=avr-gcc
CXX=avr-g++
AR=avr-ar

ARD_OBJS := $(patsubst $(CORE)/%.c,%.o,$(wildcard $(CORE)/*.c))
ARD_OBJS := $(ARD_OBJS) $(patsubst $(CORE)/%.cpp,%.o,$(wildcard $(CORE)/*.cpp))

bikecompy.elf: bikecompy.o $(addsuffix .a,$(ALIBS)) core.a
	$(CC) $(LDFLAGS) -o $@ $+

%.o: %.pde board.mk
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ -c $<

core.a: core.a($(notdir $(COREO)))
$(foreach alib,$(ALIBS),$(eval $(alib).a: $(alib).a($(notdir $(call ALIBO,$(alib))))))

board.mk:
	@echo Making $@ for $(BOARD)
	@grep ^$(BOARD)\\. $(HARDWARE)/boards.txt
	grep ^$(BOARD)\\. $(HARDWARE)/boards.txt |\
cut -d. -f2- |\
sed -e 's/^.*=/\U&/; s/\.\(.*=\)/_\1/g' > $@

.PHONY: clean upload
clean:
	rm -f *.a *.o bikecompy.hex bikecompy
