.PHONY: all dotfiles test shellcheck

all: dotfiles

dotfiles:
	# adding symbolic links to dotfiles in ~
	@for file in $(shell find $(CURDIR) -name ".*" -not -name "readme.md" -not -name ".gitignore" -not -name ".travis.yml" -not -name ".git" -not -name ".*.swp" -not -name ".gnupg"); do \
		if [ -f $$file ]; then \
			f=$$(basename $$file); \
			ln -sfn $$file $(HOME)/$$f; \
		fi \
	done;

test: shellcheck

shellcheck:
	docker run --rm -it \
		-v $(CURDIR):/usr/src:ro \
		--workdir /usr/src \
		andreccosta/shellcheck ./test.sh
