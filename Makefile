ENABLED=jobs/internal.yaml
TESTS=$(addprefix test_,$(ENABLED))
BASH_SCRIPTS:=$(shell find jobs -name '*.sh')

all: $(ENABLED)

.ONESHELL:
SHELL = /bin/bash
venv: requirements.txt
	if [ ! -d venv ] ; then \
		virtualenv --python=python2.7 venv; \
		source ./venv/bin/activate && \
			pip install -r ./requirements.txt >install.log; \
	fi

## define JOBS_[internal] to update just them
.ONESHELL:
SHELL = /bin/bash
$(ENABLED): venv
	$(eval JOBS := $(JOBS_$(@:jobs/%.yaml=%)))
	if [ "${JOBS}" != "none" ] ; then \
		source ./venv/bin/activate && \
			./venv/bin/jenkins-jobs --conf jenkins_jobs.ini \
			--ignore-cache update $@ ${JOBS}; \
	else \
		echo "$(@) skipped. JOBS_$(@:jobs/%.yaml=%) set to none"; \
	fi

.ONESHELL:
SHELL = /bin/bash
$(TESTS): venv
	$(eval CONFIG_FILE := $(@:test_%=%))
	source ./venv/bin/activate && \
		./venv/bin/jenkins-jobs --conf jenkins_jobs.ini test \
			-o config $(CONFIG_FILE)

# check for syntax errors
syntaxcheck: shellcheck

shellcheck:
	@echo -n "Checking for shell syntax errors"; \
	for SCRIPT in $(BASH_SCRIPTS); do \
		test -r $${SCRIPT} || continue ; \
		bash -n $${SCRIPT} || exit ; \
		echo -n "."; \
	done; \
	echo " done."; \

# run this in parallel!! -j is your friend
test: $(TESTS)

# get rid of test files
clean:
	rm -rf config install.log install.err

# also get rid of pip environment
dist-clean: clean
	rm -rf bin include lib local reports venv
	rm -f builddeps.list preferences sources.list

.PHONY: all $(ENABLED) $(TESTS)
