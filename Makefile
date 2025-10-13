all: test example

test:
	odin test tests -collection:ygg=./src

example:
	odin build examples -collection:ygg=./src -file -out:bin/example

.PHONY: clean
clean:
	rm -fr *.o bin/* 
