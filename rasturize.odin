package main

import "core:math"
import "core:slice"

Axis :: enum {
	X,
	Y,
	Z,
}
Angle: f64 = math.PI / 6
Ambient: f64 = 0.2
Exponent: f64 = 4

Eye := Vertex{-1, 0, 2}
Center := Vertex{0, 0, 0}
Up := Vertex{0, 1, 0}
Light := Vertex{0.1, 1, 0}

parallel_rasturize :: proc(
	pipeline: []f64,
	idx: [3]Index,
	vertices: [dynamic]Vertex,
	normals: [dynamic]Vertex,
	buf: []u8,
	depth: []u8,
	z_buf: []f64,
	rgb: [3]u8,
) {
	na, nb, nc := normals[idx[0].normal], normals[idx[1].normal], normals[idx[2].normal]
	va, vb, vc := vertices[idx[0].vertex], vertices[idx[1].vertex], vertices[idx[2].vertex]
	pa, pb, pc := pipe(pipeline, va), pipe(pipeline, vb), pipe(pipeline, vc)

	a := Coord{i32(pa.x / pa.w), i32(pa.y / pa.w)}
	b := Coord{i32(pb.x / pb.w), i32(pb.y / pb.w)}
	c := Coord{i32(pc.x / pc.w), i32(pc.y / pc.w)}
	az, bz, cz := pa.z / pa.w, pb.z / pb.w, pc.z / pc.w

	ensure_unique_apex(&a, &b, &c)
	area := triangle_area(coord_to_vertex(a), coord_to_vertex(b), coord_to_vertex(c))
	if area < 1 {return}

	start, end := bounds(a, b, c)
	// norm := normal(va, vb, vc)
	// df := diffuse(va, vb, vc)

	for x in start.x ..= end.x {
		for y in start.y ..= end.y {
			p := Coord{x, y}
			w1, w2 := derive_weights(
				coord_to_vertex(p),
				coord_to_vertex(a),
				coord_to_vertex(b),
				coord_to_vertex(c),
			)
			if !inside_triangle(w1, w2) {continue}

			w0 := 1 - w1 - w2
			z := (w0 * az) + (w1 * bz) + (w2 * cz)

			n := Vertex {
				x = (w0 * na.x) + (w1 * nb.x) + (w2 * nc.x),
				y = (w0 * na.y) + (w1 * nb.y) + (w2 * nc.y),
				z = (w0 * na.z) + (w1 * nb.z) + (w2 * nc.z),
			}
			interpolation := divide(n, magnitude(n))
			df := max(0, dot_product(interpolation, Light))

			sight := line_of_sight(va, vb, vc, w0, w1, w2)
			spec := specular(interpolation, Exponent, sight)

			brightness := min(1, Ambient + df + spec)
			gray := u8(brightness * 255)

			idx := (y * i32(Width)) + x
			if idx < 0 || idx >= i32(len(z_buf)) {continue}

			prev := z_buf[idx]
			if prev == 0 || z >= prev {
				z_buf[idx] = z
				set_pixel(p.x, p.y, buf, rgb)
				set_pixel(p.x, p.y, depth, [3]u8{gray, gray, gray})
			}
		}
	}
}

// n = (eye - center) / ‖eye - center‖
// l = (up × n) / ‖up × n‖
// m = (n × l) / ‖n × l‖

// NOTE:
// [i,j,k] = [l,m,n] * M

// NOTE:
// ⌈ x'⌉       ⎛ ⌈x⌉   ⌈Cx⌉ ⎞
// | y'| = M⁻¹ ⎜ |y| - |Cy| ⎟
// | z'|       ⎜ |z|   |Cz| ⎟
// ⌊ 1 ⌋       ⎝ ⌊1⌋   ⌊1 ⌋ ⎠

// M = lx mx nx
//     ly my ny
//     lz mz nz

// M⁻¹ = lx ly lz
//       mx my mz
//       nx ny nz

// ⌈ x'⌉   ⌈lx ly lz 0⌉ ⌈1  0  0  -Cx⌉ ⌈x⌉
// | y'| = |mx my mz 0| |0  1  0  -Cy| |y|
// | z'|   |nx ny nz 0| |0  0  1  -Cz| |z|
// ⌊ 1 ⌋   ⌊0  0  0  1⌋ ⌊0  0  0   1 ⌋ ⌊1⌋

modal :: proc(center: Vertex, eye: Vertex, up: Vertex, result: []f64) {
	n := divide(diff(eye, center), magnitude(diff(eye, center)))
	l := divide(cross_product(up, n), magnitude(cross_product(up, n)))
	m := divide(cross_product(n, l), magnitude(cross_product(n, l)))

	c := []f64{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, -center.x, -center.y, -center.z, 1}
	inverse := []f64{l.x, m.x, n.x, 0, l.y, m.y, n.y, 0, l.z, m.z, n.z, 0, 0, 0, 0, 1}
	compose(c, inverse, 4, result)
}

// 1  0   0    0
// 0  1   0    0
// 0  0   1    0
// 0  0  -1/f  1

perspective :: proc(eye: Vertex, center: Vertex) -> [16]f64 {
	focal_distance := magnitude(diff(eye, center))
	return [16]f64{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -1 / focal_distance, 0, 0, 0, 1}
}

// w/2   0    0   x + w/2
// 0    h/2   0   y + h/2
// 0     0    1    0
// 0     0    0    1

viewport :: proc(offset_x, offset_y: f64) -> [16]f64 {
	return [16]f64 {
		f64(Width) / 2,
		0,
		0,
		0,
		0,
		f64(Height) / 2,
		0,
		0,
		0,
		0,
		1,
		0,
		offset_x + (f64(Width) / 2),
		offset_y + (f64(Height) / 2),
		0,
		1,
	}
}

diffuse :: proc(a, b, c: Vertex) -> f64 {
	n := normal(a, b, c)
	return max(0, dot_product(n, Light))
}

specular :: proc(norm: Vertex, e: f64, sight: Vertex) -> f64 {
	r := reflection(norm)
	return math.pow_f64(max(0, dot_product(r, sight)), e)
}

line_of_sight :: proc(va, vb, vc: Vertex, w0, w1, w2: f64) -> Vertex {
	v := Vertex {
		x = (va.x * w0) + (w1 * vb.x) + (w2 * vc.x),
		y = (va.y * w0) + (w1 * vb.y) + (w2 * vc.y),
		z = (va.z * w0) + (w1 * vb.z) + (w2 * vc.z),
	}
	return divide(diff(Eye, v), magnitude(diff(Eye, v)))
}

reflection :: proc(norm: Vertex) -> Vertex {
	v := multiply(multiply(norm, 2), dot_product(norm, Light))
	return Vertex{v.x - Light.x, v.y - Light.y, v.z - Light.z}
}

pipe :: proc(pipeline: []f64, p: Vertex) -> Vec4 {
	v := []f64{p.x, p.y, p.z, 1}
	result := make([]f64, 4)
	defer delete(result)

	transform(pipeline, v, 4, result)
	return Vec4{x = result[0], y = result[1], z = result[2], w = result[3]}
}

bounds :: proc(a, b, c: Coord) -> (Coord, Coord) {
	return Coord {
		x = min(a.x, b.x, c.x),
		y = min(a.y, b.y, c.y),
	}, Coord{x = max(a.x, b.x, c.x), y = max(a.y, b.y, c.y)}
}

normalize :: proc(bounds: [2]f64, n: f64) -> f64 {
	min, max := bounds[0], bounds[1]
	return (n - min) / (max - min)
}

scanline_rasturize :: proc(triangle: Triangle, vertices: [dynamic]Vertex, buf: []u8) {
	points := []Coord {
		screen(vertices[triangle[0]]),
		screen(vertices[triangle[1]]),
		screen(vertices[triangle[2]]),
	}
	slice.sort_by(points, proc(a, b: Coord) -> bool {
		return a.y < b.y
	})
	a, b, c := points[0], points[1], points[2]

	if b.x > c.x {swap(&b, &c)}
	line(a, b, buf, Forest)
	line(a, c, buf, Blue)
	line(b, c, buf, Yellow)

	y := a.y
	for y <= b.y && y <= c.y {
		defer y += 1
		start := sample_at(y, a, b)
		end := sample_at(y, a, c)

		for x := start + 1; x < end; x += 1 {
			set_pixel(x, y, buf, Steel_Blue)
		}
	}
	if b.y > c.y {swap(&b, &c)}

	a = Coord {
		x = sample_at(y, a, c),
		y = y,
	}
	if a.x > b.x {swap(&a, &b)}

	floor := y
	for y := c.y; y >= floor; y -= 1 {
		start := sample_at(y, c, a)
		end := sample_at(y, c, b)

		for x := start + 1; x < end; x += 1 {
			set_pixel(x, y, buf, Mint)
		}
	}
}

sample_at :: proc(y: i32, a, b: Coord) -> i32 {
	ax, bx := a.x, b.x
	ay, by := a.y, b.y

	if ax > bx {
		swap(&ax, &bx)
		swap(&ay, &by)
	}
	t := f32(y - ay) / f32(by - ay)
	x := f32(ax) + (f32(bx - ax) * t)
	return i32(math.round_f32(x))
}

coord_to_vertex :: proc(c: Coord) -> Vertex {
	return Vertex{x = f64(c.x), y = f64(c.y)}
}
