all: test
	odin run examples/02_low_lvl_api.odin -file  

dev: examples/02_low_lvl_api.odin
	odin build examples/02_low_lvl_api.odin -file -out:bin/02_low_lvl_api

release: examples/02_low_lvl_api.odin
	odin build examples/02_low_lvl_api.odin -file -o:speed -out:bin/02_low_lvl_api

test: dev
	odin test tests

.PHONY: clean
clean:
	rm -fr *.o bin/* 
