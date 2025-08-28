all: test
	odin run examples/02_low_lvl_api.odin -collection:yggdrasil=./src -file  

dev: examples/02_low_lvl_api.odin
	odin build examples/02_low_lvl_api.odin -collection:yggdrasil=./src -file -out:bin/02_low_lvl_api

release: examples/02_low_lvl_api.odin
	odin build examples/02_low_lvl_api.odin -collection:yggdrasil=./src -file -o:speed -out:bin/02_low_lvl_api

test: dev
	odin test tests -collection:yggdrasil=./src

.PHONY: clean
clean:
	rm -fr *.o bin/* 
