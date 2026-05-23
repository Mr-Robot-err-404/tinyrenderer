package main

import "core:fmt"

log_parts :: proc(parts: []string) {
	for s in parts {
		fmt.printf("%s:", s)
	}
	fmt.println()
}
log_vertex :: proc(vertex: Vertex) {
	fmt.printf("%f:", vertex.x)
	fmt.printf("%f:", vertex.y)
	fmt.printf("%f\n", vertex.z)
}
log_coord :: proc(coord: Coord) {
	fmt.printf("%d:", coord.x)
	fmt.printf("%d\n", coord.y)
}
