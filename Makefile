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
