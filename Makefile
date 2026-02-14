.PHONY: all dotfiles install test shellcheck

all: dotfiles

install: dotfiles

dotfiles:
	# adding symbolic links to dotfiles in ~
	@for file in $(shell find $(CURDIR) -name ".*" -not -name "readme.md" -not -name ".gitignore" -not -name ".travis.yml" -not -name ".git" -not -name ".*.swp" -not -name ".gnupg"); do \
		if [ -f $$file ]; then \
			f=$$(basename $$file); \
			ln -sfn $$file $(HOME)/$$f; \
		fi \
	done;

test: shellcheck

INTERACTIVE := $(shell [ -t 0 ] && echo 1 || echo 0)
ifeq ($(INTERACTIVE), 1)
	DOCKER_FLAGS += -t
endif

shellcheck:
	docker run --rm -i $(DOCKER_FLAGS) \
		-v $(CURDIR):/usr/src:ro \
		--workdir /usr/src \
		andreccosta/shellcheck ./test.sh
