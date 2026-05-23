package main

import "core:os"
import "core:strconv"
import "core:strings"

Geometry :: enum {
	Vertex,
	Face,
	Unknown,
}

parse_obj :: proc(filename: string, vertices: ^map[Vertex]u32) {
	data, ok := os.read_entire_file(filename)
	if !ok {panic("failed to read file")}

	defer delete(data, context.allocator)
	it := string(data)
	idx: u32 = 0

	for line in strings.split_lines_iterator(&it) {
		parts := strings.split(strings.trim_space(line), " ", context.allocator)
		if len(parts) < 4 {continue}

		switch geometry(parts) {
		case Geometry.Vertex:
			vertex, ok := parse_vertex(parts)
			if !ok {
				continue
			}
			vertices[vertex] = idx
			idx += 1
		case Geometry.Face:
		case Geometry.Unknown:
			continue
		}
	}
}

geometry :: proc(parts: []string) -> Geometry {
	if parts[0] == "v" {return Geometry.Vertex}
	if parts[0] == "f" {return Geometry.Face}
	return Geometry.Unknown
}

parse_vertex :: proc(parts: []string) -> (Vertex, bool) {
	x, ok := strconv.parse_f64(parts[1])
	y, okay := strconv.parse_f64(parts[2])
	z, good := strconv.parse_f64(parts[3])
	if !ok || !okay || !good {return Vertex{}, false}
	return Vertex{x = x, y = y, z = z}, true
}
