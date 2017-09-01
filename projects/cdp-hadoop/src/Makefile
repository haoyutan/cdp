all: build

clean:
	rm -rf download-packages hadoop-ctl install-cdp-hadoop

build: clean
	bash download-packages.sh __make__
	bash hadoop-ctl.sh __make__
	bash install-cdp-hadoop.sh __make__
