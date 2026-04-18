.PHONY: all dotfiles install restow test shellcheck

all: install

install dotfiles:
	./dot install

restow:
	./dot restow

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
