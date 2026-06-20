package main

import "core:math"
import "core:slice"

Axis :: enum {
	X,
	Y,
	Z,
}
Angle: f64 = math.PI / 6

parallel_rasturize :: proc(
	triangle: Triangle,
	vertices: [dynamic]Vertex,
	buf: []u8,
	depth: []u8,
	z_buf: []f64,
	rgb: [3]u8,
) {
	rx, ry, rz :=
		rotation_matrix(Angle, Axis.X),
		rotation_matrix(Angle, Axis.Y),
		rotation_matrix(Angle, Axis.Z)

	result := make([]f64, 9)
	compose(ry[:], rx[:], 3, result)

	transformation := make([]f64, 9)
	compose(result, rz[:], 3, transformation)

	va, vb, vc := vertices[triangle[0]], vertices[triangle[1]], vertices[triangle[2]]
	points := []Coord {
		screen(transform(transformation, va)),
		screen(transform(transformation, vb)),
		screen(transform(transformation, vc)),
	}
	bnd := z_bounds(vertices)

	a, b, c := points[0], points[1], points[2]
	ensure_unique_apex(&a, &b, &c)
	area := triangle_area(coord_to_vertex(a), coord_to_vertex(b), coord_to_vertex(c))
	if area < 1 {return}

	start, end := bounds(a, b, c)
	for x in start.x ..= end.x {
		for y in start.y ..= end.y {
			p := Coord {
				x = x,
				y = y,
			}
			w1, w2 := derive_weights(
				coord_to_vertex(p),
				coord_to_vertex(a),
				coord_to_vertex(b),
				coord_to_vertex(c),
			)
			if !inside_triangle(w1, w2) {continue}

			w0 := 1 - w1 - w2
			z := (w0 * va.z) + (w1 * vb.z) + (w2 * vc.z)
			gray := u8(normalize(bnd, z) * 255)

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

modal :: proc(center: Vertex, eye: Vertex, up: Vertex) {
	n := divide(diff(eye, center), magnitude(diff(eye, center)))
	l := divide(cross_product(up, n), magnitude(cross_product(up, n)))
	m := divide(cross_product(n, l), magnitude(cross_product(n, l)))
}

// 1  0   0    0
// 0  1   0    0
// 0  0   1    0
// 0  0  -1/f  1

perspective :: proc() -> [16]f64 {
	return [16]f64{1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1, -1 / Focal_Distance, 0, 0, 0, 1}
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

z_bounds :: proc(vertices: [dynamic]Vertex) -> [2]f64 {
	min: f64 = math.F64_MAX
	max: f64 = -math.F64_MAX

	for v in vertices {
		if v.z < min {min = v.z}
		if v.z > max {max = v.z}
	}
	return [2]f64{min, max}
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
