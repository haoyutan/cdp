all: magic_script

magic_script:
	@if [ ! -d "magic-script" ]; then \
	    echo "Downloading MagicScript from GitHub..."; \
	    git clone https://github.com/haoyutan/magic-script.git magic-script; \
	fi

clean:
	rm -rf magic-script
