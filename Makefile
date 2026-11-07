PODMAN=podman

CONFS_DISABLED=ar100

CONFS_EXIST:=$(patsubst kalico/test/configs/%.config,%,$(wildcard kalico/test/configs/*.config))
CONFS:=$(filter-out $(CONFS_DISABLED),$(CONFS_EXIST))

DICTS:=$(foreach x,$(CONFS),dicts/$x.dict)

KALICO_VERSION:=$(shell git -C $(CURDIR)/kalico describe --always --long --tags)

all: dicts.tar.zstd

dicts.tar.zstd: $(DICTS)
	tar -c -v --zstd \
		--owner build:1000 --group build:1000 \
		--no-acls --no-selinux --no-xattrs \
		-f $@ dicts/

containerenv: buildarea.container
	[[ -d $(CURDIR)/dicts ]] || mkdir $(CURDIR)/dicts
	$(PODMAN) run --rm -it --userns keep-id \
		-v $(CURDIR)/kalico:/mnt/kalico:O \
		-v $(CURDIR)/scripts:/mnt/scripts:ro,z \
		-w $(CURDIR)/dicts:/mnt/dicts:rw,z \
		-w /mnt \
		$(file < buildarea.container)

dicts/%.dict: kalico/test/configs/%.config | buildarea.container
	[[ -d $(CURDIR)/dicts ]] || mkdir $(CURDIR)/dicts
	$(PODMAN) run --rm --userns keep-id \
		-v $(CURDIR)/kalico:/mnt/kalico:O \
		-v $(CURDIR)/scripts:/mnt/scripts:ro,z \
		-v $(CURDIR)/dicts:/mnt/dicts:rw,z \
		-w /mnt \
		-e FAKE_GIT_DESCRIBE=$(KALICO_VERSION) \
		$(file < buildarea.container) \
		./scripts/makedict $* ./dicts

%.container: %.container.d/Containerfile
	$(PODMAN) build $*.container.d --iidfile $@

.PHONY: all containerenv
