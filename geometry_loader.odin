package main

import "core:os"
import "core:strconv"
import "core:strings"

Geometry :: struct {
	indices:  [dynamic]u16,
	vertices: [dynamic]f32,
}

@(private = "file")
Section :: enum {
	Neither,
	Vertices,
	Indices,
}

load_geometry :: proc(path: string) -> Geometry {
	source_bytes, _ := os.read_entire_file(path)
	defer delete(source_bytes)
	source := string(source_bytes)

	geometry := Geometry {
		indices  = make([dynamic]u16),
		vertices = make([dynamic]f32),
	}

	current_section := Section.Neither

	for line in strings.split_lines_iterator(&source) {
		if line == "" || strings.starts_with(line, "#") {
			// The line is a comment or is empty
			continue
		}

		if line == "[vertices]" {
			current_section = .Vertices

			continue
		}
		if line == "[indices]" {
			current_section = .Indices

			continue
		}

		if current_section == .Vertices {
			components, _ := strings.split(line, " ")

			for component in components {
				if component == "" {
					continue
				}

				append(&geometry.vertices, f32(strconv.atof(component)))
			}
		}
		if current_section == .Indices {
			components, _ := strings.split(line, " ")

			for component in components {
				if component == "" {
					continue
				}

				append(&geometry.indices, u16(strconv.atoi(component)))
			}
		}
	}

	return geometry
}

destroy_geometry :: proc(geometry: Geometry) {
	delete(geometry.vertices)
	delete(geometry.indices)
}

