all: test

dev: src
	odin build -collection:ygg=./src -file -out:bin/yggdrasil

release: src
	odin build -collection:ygg=./src -file -o:speed -out:bin/yggdrasil

test: dev
	odin test tests -collection:ygg=./src

example:
	odin build examples -collection:ygg=./src -file

.PHONY: clean
clean:
	rm -fr *.o bin/* 
