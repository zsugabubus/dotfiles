CC:=gcc
CFLAGS:=-Wall -Ofast -std=c99 -Werror -Wextra
CLIBS:=-lxcb

TARGET:=workspaces-bar

SRCDIR:=src
OUTDIR:=scripts

RM:=/usr/bin/rm
STRIP:=/usr/bin/strip
STRIPFLAGS:=-s -R .comment -R .gnu.version --strip-unneeded

.PHONY: all
all: $(TARGET)

.PHONY: $(TARGET)
$(TARGET): %: $(OUTDIR)/% Makefile

$(OUTDIR)/%: $(SRCDIR)/%.c Makefile
	$(CC) $(CFLAGS) $(CLIBS) $< -o $@
	$(STRIP) $(STRIPFLAGS) $@

.PHONY: clean
clean:
	$(RM) $(TARGET)
