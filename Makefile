VEXE ?= v
VFLAGS ?=

.PHONY: all tipsy syncs gryncs

all: tipsy syncs gryncs

tipsy:
	$(VEXE) $(VFLAGS) -o ./bin/tipsy tipsy.v

syncs:
	$(VEXE) $(VFLAGS) -o ./bin/syncs ./clients/syncs.v

gryncs:
	$(VEXE) $(VFLAGS) -o ./bin/gryncs ./clients/gryncs.v
