.PHONY: build clean test test-coverage fmt

COVERDIR ?= $(CURDIR)/.coverdata

VERSION := 0.1.0
PACKAGE_NAME_VERSION = oci-delta-$(VERSION)

build:
	go build -o oci-delta ./cmd/oci-delta

clean:
	rm -f oci-delta
	rm -rf $(COVERDIR)
	rm -rf $(CURDIR)/rpmbuild
	rm -rf $(CURDIR)/release_artifacts

test: build
	go test ./...
	python3 tests/test-synthetic.py
	tests/integration-test.sh

test-coverage:
	go build -cover -o oci-delta ./cmd/oci-delta
	rm -rf $(COVERDIR) && mkdir -p $(COVERDIR)/unit $(COVERDIR)/integration
	go test -cover ./... -args -test.gocoverdir=$(COVERDIR)/unit
	GOCOVERDIR=$(COVERDIR)/integration python3 tests/test-synthetic.py
	GOCOVERDIR=$(COVERDIR)/integration tests/integration-test.sh
	go tool covdata percent -i $(COVERDIR)/unit,$(COVERDIR)/integration

fmt:
	go fmt ./...

install:
	go install ./cmd/oci-delta
	install -Dm644 docs/man/oci-delta.1 $(DESTDIR)$(PREFIX)/share/man/man1/oci-delta.1

#
# RPM packaging
#

RPM_SPECFILE_IN=oci-delta.spec.in
RPM_SPECFILE=rpmbuild/SPECS/oci-delta.spec
RPM_TARBALL=rpmbuild/SOURCES/$(PACKAGE_NAME_VERSION).tar.gz

.PHONY: $(RPM_SPECFILE)
$(RPM_SPECFILE):
	mkdir -p $(CURDIR)/rpmbuild/SPECS
	sed -e "s/@@VERSION@@/$(VERSION)/g" $(RPM_SPECFILE_IN) > $(RPM_SPECFILE)
	go mod vendor
	./tools/rpm_spec_add_provides_bundle.sh $(RPM_SPECFILE)

define get_package_name
$(basename $(basename $(notdir $1)))
endef

define get_uncompressed_name
$(1:.tar.gz=.tar)
endef

$(RPM_TARBALL): $(RPM_SPECFILE)
	mkdir -p $(CURDIR)/rpmbuild/SOURCES
	git archive --prefix=$(call get_package_name,$@)/ --format=tar.gz HEAD > $@
	gunzip -f $@
	tar --delete --owner=0 --group=0 --file $(call get_uncompressed_name,$@) $(call get_package_name,$@)/$(notdir $(RPM_SPECFILE_IN))
	tar --append --owner=0 --group=0 --transform "s;^;$(call get_package_name,$@)/;" --file $(call get_uncompressed_name,$@) $(RPM_SPECFILE) vendor/
	tar --append --owner=0 --group=0 --transform "s;$(dir $(RPM_SPECFILE));$(call get_package_name,$@)/;" --file $(call get_uncompressed_name,$@) $(RPM_SPECFILE)
	gzip $(call get_uncompressed_name,$@)

.PHONY: srpm
srpm: $(RPM_SPECFILE) $(RPM_TARBALL)
	rpmbuild -bs \
		--define "_topdir $(CURDIR)/rpmbuild" \
		--with tests \
		$(RPM_SPECFILE)

.PHONY: rpm
rpm: $(RPM_SPECFILE) $(RPM_TARBALL)
	rpmbuild -bb \
		--define "_topdir $(CURDIR)/rpmbuild" \
		--with tests \
		$(RPM_SPECFILE)

.PHONY: scratch
scratch: $(RPM_SPECFILE) $(RPM_TARBALL)
	rpmbuild -bb \
		--define "_topdir $(CURDIR)/rpmbuild" \
		--without tests \
		--nocheck \
		$(RPM_SPECFILE)

.PHONY: release_artifacts
release_artifacts: $(RPM_TARBALL)
	mkdir -p release_artifacts
	cp $< release_artifacts/
	echo "release_artifacts/$(shell basename $<)"
