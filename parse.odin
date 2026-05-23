package main

import "core:os"
import "core:strconv"
import "core:strings"

Geometry :: enum {
	Vertex,
	Face,
	Unknown,
}

parse_obj :: proc(filename: string, vertices: ^map[Vertex]u32, faces: ^map[Triangle]u32) {
	data, ok := os.read_entire_file(filename)
	if !ok {panic("failed to read file")}

	defer delete(data, context.allocator)
	it := string(data)

	idx: u32 = 0
	j: u32 = 0

	for line in strings.split_lines_iterator(&it) {
		parts := strings.split(strings.trim_space(line), " ", context.allocator)
		if len(parts) < 4 {continue}

		switch geometry(parts) {
		case Geometry.Vertex:
			vertex, ok := parse_vertex(parts)
			if !ok {continue}
			vertices[vertex] = idx
			idx += 1
		case Geometry.Face:
			f, ok := parse_faces(parts)
			if !ok {continue}
			faces[f] = j
			j += 1
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

parse_faces :: proc(parts: []string) -> (Triangle, bool) {
	i, ok := face(parts[1])
	j, okay := face(parts[2])
	k, fine := face(parts[3])
	if !ok || !okay || !fine {return Triangle{}, false}
	return Triangle{i32(i - 1), i32(j - 1), i32(k - 1)}, true
}
face :: proc(s: string) -> (i64, bool) {
	f := strings.split(strings.trim_space(s), "/")
	if len(f) < 3 {return 0, false}
	return strconv.parse_i64(f[0])
}

parse_vertex :: proc(parts: []string) -> (Vertex, bool) {
	x, ok := strconv.parse_f64(parts[1])
	y, okay := strconv.parse_f64(parts[2])
	z, good := strconv.parse_f64(parts[3])
	if !ok || !okay || !good {return Vertex{}, false}
	return Vertex{x = x, y = y, z = z}, true
}
