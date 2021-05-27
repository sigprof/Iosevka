# Makefile for building the release of Cosevka fonts (based on Iosevka).

# Default target.
all: release
.PHONY: all

# List of TTF packages that should be built.
TTF_PACKAGES =				\
	cosevka-basic			\
	cosevka-basic-semiwide		\
	cosevka-basic-wide		\
	cosevka-basic-extrawide		\
	cosevka-basic-ultrawide		\
	cosevka-fixed			\
	cosevka-code

# List of TTC packages that should be built.
TTC_PACKAGES = cosevka

# Some TTF files get undesired width parts added to the file names; these parts
# need to be removed while building the font release archives.
TTF_REMOVE_PART-cosevka-basic-semiwide	= semiextended
TTF_REMOVE_PART-cosevka-basic-wide	= extended
TTF_REMOVE_PART-cosevka-basic-extrawide	= extraextended
TTF_REMOVE_PART-cosevka-basic-ultrawide	= ultraextended

# Function which builds the file name transform patterns for GNU tar to remove
# undesired width parts from file names.
TTF_TRANSFORM = $(if $(TTF_REMOVE_PART-$(1)), $(strip \
	--transform='s,-$(TTF_REMOVE_PART-$(1))\.ttf$$,-regular.ttf,' \
	--transform='s,-$(TTF_REMOVE_PART-$(1))\([^-]\+\)\.ttf$$,-\1.ttf,'))

# Determine the version number from Git tags.
GIT_VERSION := $(shell git describe --tags --match='cosevka-*')
VERSION := $(if $(GIT_VERSION),$(patsubst cosevka-%,%,$(GIT_VERSION)),unknown)

# Lists of file names for release archives.
TTF_ARCHIVES = $(patsubst %,release-archives/ttf-%-$(VERSION).tar.xz,$(TTF_PACKAGES))
TTC_ARCHIVES = $(patsubst %,release-archives/ttc-%-$(VERSION).tar.xz,$(TTC_PACKAGES))
ALL_ARCHIVES = $(TTF_ARCHIVES) $(TTC_ARCHIVES)

# GNU tar is required.
TAR = tar

# GNU tar options to generate reproducible archives.
TAR_FLAGS = --format=gnu --sort=name --numeric-owner --owner=0 --group=0 \
	$(if $(SOURCE_DATE_EPOCH),--mtime="@$(SOURCE_DATE_EPOCH)")

# Create required directories.
$(shell mkdir -p .build release-archives)

.PHONY: release
release: release-archives/SHA256SUM

# Generate the `SHA256SUM` file for release archives.
release-archives/SHA256SUM: $(ALL_ARCHIVES)
	cd release-archives && sha256sum $(sort $(notdir $(ALL_ARCHIVES))) > SHA256SUM

# Pack the Super-TTC file into the corresponding release archive.
release-archives/ttc-%-$(VERSION).tar.xz: .build/.build.stamp
	$(TAR) -c -f $@ --xz $(TAR_FLAGS) -C dist/.super-ttc $*.ttc

# Pack the set of hinted TTF files into the corresponding release archive,
# possibly changing the file names in the process.  The order of files in the
# archive still corresponds to the original file names, so it may not look
# sorted, but it's still stable, so the archive is reproducible.
release-archives/ttf-%-$(VERSION).tar.xz: .build/.build.stamp
	$(TAR) -c -f $@ --xz $(TAR_FLAGS) $(call TTF_TRANSFORM,$*) -C dist/$*/ttf $(sort $(notdir $(wildcard dist/$*/ttf/*.ttf)))

# Build all font files by invoking the Iosevka build system.
#
# `TZ=UTC` is a workaround for a bug in the `ot-builder` package (the TTF
# timestamp conversion code may give wrong results in some time zones).
# `@echo` is needed to fix the log output, because the Iosevka build system
# forgets to print the last newline character before exiting.
.build/.build.stamp: private-build-plans.toml node_modules
	env TZ=UTC npm run build -- $(addprefix ttf::,$(TTF_PACKAGES)) $(addprefix super-ttc::,$(TTC_PACKAGES))
	@echo
	@touch .build/.build.stamp

# Convert build plans from YAML to TOML.
private-build-plans.toml: private-build-plans.yaml utility/yaml-to-toml.js node_modules
	node utility/yaml-to-toml.js -o private-build-plans.toml private-build-plans.yaml

# Install the required Node.js packages.
#
# `npm ci` always removes existing `node_modules`, therefore its timestamp will
# be up to date after a successful run, so it is possible to run `npm ci`
# before invoking this Makefile.
node_modules: package.json package-lock.json
	@echo "npm ci"
	@npm ci || { \
		test -e node_modules && { \
			echo '*Error* `npm ci` failed,  marking `node_modules` as stale'; \
			touch -d '1970-01-01 00:00:01 UTC' node_modules || { \
				echo '*Error* Marking as stale failed, removing `node_modules`'; \
				rm -rf node_modules; \
			}; \
		}; \
		exit 1; \
	}

.PHONY: clean
clean:
	-test -f node_modules/verda/bin/verda && { npm run clean; echo; } ||:
	-rm -rf .build dist private-build-plans.toml

# TODO: `npm run clean` does not remove `font-src/**/*.js`.

.PHONY: distclean
distclean: clean
	-rm -rf .build dist node_modules release-archives

# Delete modified target files if the command returned a non-zero exit code.
# In a perfect world this should be the default behavior, but for compatibility
# reasons it needs to be requested explicitly.
.DELETE_ON_ERROR:
