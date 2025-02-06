vet_flags = -warnings-as-errors \
			-vet-unused-variables \
			-vet-unused-imports \
			-vet-tabs \
			-vet-style \
			-vet-semicolon \
			-vet-cast

start:
	@mkdir -p build
	@odin run . -out:./build/app ${vet_flags} -debug

start_release:
	@mkdir -p build
	@odin run . -out:./build/app ${vet_flags} -o:speed

clean:
	@rm -rf build/*
