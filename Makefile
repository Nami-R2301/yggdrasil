all: dev

test: dev
	odin test tests

dev: examples/02_low_lvl_api.odin
	odin build examples/02_low_lvl_api.odin -file -out:bin/02_low_lvl_api

release: examples/02_low_lvl_api.odin
	odin build examples/02_low_lvl_api.odin -file -o:speed -out:bin/02_low_lvl_api

.PHONY: clean
clean:
	rm -fr *.o bin/* 
