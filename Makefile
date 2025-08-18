all: dev

dev: test.odin
	odin build test.odin -file

release: test.odin
	odin build -O2 test.odin -file

clean:
	rm -fr *.o test
