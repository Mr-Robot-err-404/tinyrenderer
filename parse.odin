package main

import "core:os"
import "core:strconv"
import "core:strings"

Geometry :: enum {
	Vertex,
	Face,
	Normal,
	Unknown,
}

parse_obj :: proc(
	filename: string,
	vertices: ^[dynamic]Vertex,
	indices: ^[dynamic][3]Index,
	normals: ^[dynamic]Vertex,
) {
	data, ok := os.read_entire_file(filename)
	if !ok {panic("failed to read file")}

	defer delete(data, context.allocator)
	it := string(data)

	for line in strings.split_lines_iterator(&it) {
		parts := strings.fields(line, context.allocator)
		if len(parts) < 4 {continue}

		switch geometry(parts) {
		case Geometry.Vertex:
			vertex, ok := parse_vertex(parts)
			if !ok {continue}
			append_elem(vertices, vertex)
		case Geometry.Face:
			f, ok := parse_faces(parts)
			if !ok {continue}
			append_elem(indices, f)
		case Geometry.Normal:
			v, ok := parse_vertex(parts)
			if !ok {continue}
			append_elem(normals, v)
		case Geometry.Unknown:
			continue
		}
	}
}

geometry :: proc(parts: []string) -> Geometry {
	if parts[0] == "v" {return Geometry.Vertex}
	if parts[0] == "f" {return Geometry.Face}
	if parts[0] == "vn" {return Geometry.Normal}
	return Geometry.Unknown
}

parse_faces :: proc(parts: []string) -> ([3]Index, bool) {
	i, ok := face(parts[1])
	j, okay := face(parts[2])
	k, fine := face(parts[3])
	if !ok || !okay || !fine {return [3]Index{}, false}
	return [3]Index{i, j, k}, true
}
face :: proc(s: string) -> (Index, bool) {
	f := strings.split(strings.trim_space(s), "/")
	if len(f) < 3 {return Index{}, false}

	v, ok := strconv.parse_int(f[0])
	n, okay := strconv.parse_int(f[2])
	if !ok || !okay {
		return Index{}, false
	}
	return Index{vertex = v - 1, normal = n - 1}, true
}

parse_vertex :: proc(parts: []string) -> (Vertex, bool) {
	x, ok := strconv.parse_f64(parts[1])
	y, okay := strconv.parse_f64(parts[2])
	z, good := strconv.parse_f64(parts[3])
	if !ok || !okay || !good {return Vertex{}, false}
	return Vertex{x = x, y = y, z = z}, true
}
