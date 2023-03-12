VEXE ?= v
VFLAGS ?=

.PHONY: all

all: bin/tipsy bin/syncs bin/gryncs

bin/tipsy: tipsy.v | bin
	$(VEXE) $(VFLAGS) -o ./bin/tipsy tipsy.v

bin/syncs: clients/syncs.v | bin
	$(VEXE) $(VFLAGS) -o ./bin/syncs clients/syncs.v

bin/gryncs: clients/gryncs.v | bin
	$(VEXE) $(VFLAGS) -o ./bin/gryncs clients/gryncs.v

bin:
	mkdir -p $@

clean:
	rm bin/tipsy bin/syncs bin/gryncs
