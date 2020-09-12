CFLAGS := -Wall -Ofast -std=c99 -Werror -Wextra -pedantic -D_GNU_SOURCE
CLIBS_volume := -lasound

SRCS = $(wildcard $(SRCDIR)/*.c)
BINS = $(patsubst $(SRCDIR)/%.c,%,$(SRCS))
TARGETS = $(BINS) config

SRCDIR := src
# XXX: Binaries should go to ~/.local/lib/arch-id/.
OUTDIR := scripts

RM := rm -f
STRIP := strip
STRIPFLAGS := -s -R .comment -R .gnu.version --strip-unneeded

all : $(TARGETS)

$(BINS) : %: $(OUTDIR)/%

config : config.in ./genconfig
	./genconfig

$(OUTDIR)/% : $(SRCDIR)/%.c
	$(CC) $(CFLAGS) $(CLIBS_$(notdir $(basename $@))) $< $(SRCDIR)/fourmat/fourmat.c -o $@
	$(STRIP) $(STRIPFLAGS) $@

clean :
	$(RM) $(addprefix $(OUTDIR)/,$(BINS)) config

.PHONY : all clean $(BINS)
