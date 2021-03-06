

################################################################################


BUILD               = $(shell git rev-parse HEAD)

PLATFORMS           = linux_amd64 linux_386 linux_arm darwin_amd64 darwin_386 freebsd_amd64 freebsd_386

FLAGS_all           = GOPATH=$(GOPATH)
FLAGS_linux_amd64   = $(FLAGS_all) GOOS=linux GOARCH=amd64
FLAGS_linux_386     = $(FLAGS_all) GOOS=linux GOARCH=386
FLAGS_linux_arm     = $(FLAGS_all) GOOS=linux GOARCH=arm
FLAGS_darwin_amd64  = $(FLAGS_all) GOOS=darwin GOARCH=amd64
FLAGS_darwin_386    = $(FLAGS_all) GOOS=darwin GOARCH=386
FLAGS_freebsd_amd64 = $(FLAGS_all) GOOS=freebsd GOARCH=amd64
FLAGS_freebsd_386   = $(FLAGS_all) GOOS=freebsd GOARCH=386
FLAGS_windows_386   = $(FLAGS_all) GOOS=windows GOARCH=386
FLAGS_windows_amd64 = $(FLAGS_all) GOOS=windows GOARCH=amd64

EXTENSION_windows_386=.exe
EXTENSION_windows_amd64=.exe

msg=@printf "\n\033[0;01m>>> %s\033[0m\n" $1


################################################################################


.DEFAULT_GOAL := build

build: guard-VERSION deps
	$(call msg,"Build binary")
	$(FLAGS_all) go build -ldflags "-X main.Version=${VERSION} -X main.Build=${BUILD}" -o docker-volume-glusterfs$(EXTENSION_$GOOS_$GOARCH) *.go
	./docker-volume-glusterfs -version
.PHONY: build

deps:
	$(call msg,"Get dependencies")
	go get -t ./...
	go get github.com/golang/lint/golint
	go get github.com/Sirupsen/logrus
	go get github.com/coreos/go-systemd/activation
	go get github.com/opencontainers/runc/libcontainer/user
	go get -d github.com/Microsoft/go-winio
.PHONY: deps

install: guard-VERSION build
	$(call msg,"Install docker-volume-glusterfs")
	mkdir -p /usr/local/bin/
	cp docker-volume-glusterfs /usr/local/bin/
.PHONY:	install

uninstall:
	$(call msg,"Uninstall docker-volume-glusterfs")
	rm -f /usr/local/bin/docker-volume-glusterfs
.PHONY:	uninstall

test: deps
	$(call msg,"Run tests")
	$(FLAGS_all) go test $(wildcard ../*.go)
.PHONY: test

clean:
	$(call msg,"Clean directory")
	rm -f docker-volume-glusterfs
	rm -rf dist
.PHONY: clean

build-all: deps guard-VERSION $(foreach PLATFORM,$(PLATFORMS),dist/$(PLATFORM)/.built)
.PHONY: build-all

dist: guard-VERSION build-all \
$(foreach PLATFORM,$(PLATFORMS),dist/docker-volume-glusterfs-$(VERSION)-$(PLATFORM).zip) \
$(foreach PLATFORM,$(PLATFORMS),dist/docker-volume-glusterfs-$(VERSION)-$(PLATFORM).tar.gz)
.PHONY:	dist 

release: guard-VERSION dist
	$(call msg,"Create and push release")
	git tag -a "v$(VERSION)" -m "Release $(VERSION)"
	git push --tags
.PHONY: tag-release


################################################################################


dist/%/.built:
	$(call msg,"Build binary for $*")
	rm -f $@
	mkdir -p $(dir $@)
	$(FLAGS_$*) go build -ldflags "-X main.Version=${VERSION} -X main.Build=${BUILD}" -o dist/$*/docker-volume-glusterfs$(EXTENSION_$*) $(wildcard ../*.go)
	touch $@

dist/docker-volume-glusterfs-$(VERSION)-%.zip:
	$(call msg,"Create ZIP for $*")
	rm -f $@
	mkdir -p $(dir $@)
	zip -j $@ dist/$*/* -x .built

dist/docker-volume-glusterfs-$(VERSION)-%.tar.gz:
	$(call msg,"Create TAR for $*")
	rm -f $@
	mkdir -p $(dir $@)
	tar czf $@ -C dist/$* --exclude=.built .

guard-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
		exit 1; \
	fi


################################################################################
