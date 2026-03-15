all: examples static dynamic

STBTT_LIB=/home/nami/third_party/Odin/vendor/stb/lib/stb_truetype.a

test_c: static ./bindings/c/main.c
	gcc ./bindings/c/main.c ./bin/ygg-static.a $(STBTT_LIB) -o ./bin/c_bindings -lpthread -ldl -lm -lglfw && ./bin/c_bindings

static: examples
	odin build ./examples -build-mode:static -no-entry-point -reloc-mode:pic -collection:ygg=./src -out:bin/ygg-static

dynamic:
	odin build ./src -build-mode:shared -no-entry-point -reloc-mode:pic -collection:ygg=./src -out:bin/ygg-dynamic

tests:
	odin test tests -collection:ygg=./src

examples:
	odin build examples -collection:ygg=./src -file -out:bin/example

.PHONY: clean
clean:
	rm -fr *.o bin/* 
