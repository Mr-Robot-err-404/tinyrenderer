package main

import "core:math"
import "core:slice"

Axis :: enum {
	X,
	Y,
	Z,
}
Normal_Mode :: enum {
	Flat,   // face normal from cross product
	Smooth, // interpolated vertex normals
	Map,    // tangent-space normal map
}
Color_Mode :: enum {
	Solid,   // random per-triangle RGB
	Diffuse, // UV-sampled diffuse texture
}
Angle: f64 = math.PI / 6
Ambient: f64 = 0.2
Exponent: f64 = 4

Eye := Vertex{-1, 0, 3}
Center := Vertex{0, 0, 0}
Up := Vertex{0, 1, 0}
Light := Vertex{1, 1, 1}

normal_mode  := Normal_Mode.Map
color_mode   := Color_Mode.Diffuse
use_specular := false
use_lighting := false

Point :: struct {
	screen: Coord,
	z:      f64,
	normal: Vertex,
	world:  Vertex,
	uv:     Vertex,
}

parallel_rasturize :: proc(
	pipeline: []f64,
	modal_view: []f64,
	idx: [3]Index,
	vertices: [dynamic]Vertex,
	normals: [dynamic]Vertex,
	textures: [dynamic]Vertex,
	n_tga: TGA,
	diff_tga: TGA,
	spec_tga: TGA,
	buf: []u8,
	depth: []u8,
	z_buf: []f64,
	rgb: [3]u8,
) {
	va, vb, vc := vertices[idx[0].vertex], vertices[idx[1].vertex], vertices[idx[2].vertex]
	pa, pb, pc := pipe(pipeline, va), pipe(pipeline, vb), pipe(pipeline, vc)

	a := Point {
		normal = normalize(pipe(modal_view, normals[idx[0].normal])),
		world  = pa,
		screen = Coord{i32(pa.x / pa.w), i32(pa.y / pa.w)},
		z      = pa.z / pa.w,
		uv     = textures[idx[0].texture],
	}
	b := Point {
		normal = normalize(pipe(modal_view, normals[idx[1].normal])),
		world  = pb,
		screen = Coord{i32(pb.x / pb.w), i32(pb.y / pb.w)},
		z      = pb.z / pb.w,
		uv     = textures[idx[1].texture],
	}
	c := Point {
		normal = normalize(pipe(modal_view, normals[idx[2].normal])),
		world  = pc,
		screen = Coord{i32(pc.x / pc.w), i32(pc.y / pc.w)},
		z      = pc.z / pc.w,
		uv     = textures[idx[2].texture],
	}

	ensure_unique_apex(&a, &b, &c)
	start, end := bounds(a.screen, b.screen, c.screen)

	flat_norm := normal(va, vb, vc)
	flat_df := max(0, dot_product(flat_norm, Light))

	to_eye := diff(Eye, va)
	if dot_product(flat_norm, to_eye) <= 0 {return}

	for x in start.x ..= end.x {
		for y in start.y ..= end.y {
			p := Coord{x, y}
			w1, w2 := derive_weights(
				coord_to_vertex(p),
				coord_to_vertex(a.screen),
				coord_to_vertex(b.screen),
				coord_to_vertex(c.screen),
			)
			if !inside_triangle(w1, w2) {continue}
			idx := (y * i32(Width)) + x
			if idx < 0 || idx >= i32(len(z_buf)) {continue}

			w0 := 1 - w1 - w2
			z := (w0 * a.z) + (w1 * b.z) + (w2 * c.z)

			n: Vertex
			df: f64
			color := rgb
			exp := Exponent

			switch normal_mode {
			case .Flat:
				n = flat_norm
				if use_lighting {df = flat_df}
			case .Smooth:
				n = Vertex {
					x = (w0 * a.normal.x) + (w1 * b.normal.x) + (w2 * c.normal.x),
					y = (w0 * a.normal.y) + (w1 * b.normal.y) + (w2 * c.normal.y),
					z = (w0 * a.normal.z) + (w1 * b.normal.z) + (w2 * c.normal.z),
				}
				if use_lighting {df = max(0, dot_product(n, Light))}
			case .Map:
				n = uv_normal_mapping(uv_interpolation(a, b, c, w0, w1, w2, n_tga))
				n = divide(n, magnitude(n))
				if use_lighting {df = max(0, dot_product(n, Light))}
			}

			if color_mode == .Diffuse {
				color = uv_interpolation(a, b, c, w0, w1, w2, diff_tga)
			} else if use_lighting {
				color = White
			}

			spec: f64 = 0
			if use_specular {
				sight := line_of_sight(va, vb, vc, w0, w1, w2)
				spec_rgb := uv_interpolation(a, b, c, w0, w1, w2, spec_tga)
				exp = f64(spec_rgb[0]) / 4.0
				spec = specular(n, exp, sight)
			}

			brightness: f64 = 1.0
			if use_lighting {brightness = min(1, Ambient + df + spec)}
			pixel := [3]u8 {
				u8(f64(color[0]) * brightness),
				u8(f64(color[1]) * brightness),
				u8(f64(color[2]) * brightness),
			}
			gray := u8(brightness * 255)

			prev := z_buf[idx]
			if prev == math.NEG_INF_F64 || z > prev {
				z_buf[idx] = z
				set_pixel(p.x, p.y, buf, pixel)
				set_pixel(p.x, p.y, depth, [3]u8{gray, gray, gray})
			}
		}
	}
}
uv_interpolation :: proc(a, b, c: Point, w0, w1, w2: f64, tga: TGA) -> [3]u8 {
	u := (w0 * a.uv.x) + (w1 * b.uv.x) + (w2 * c.uv.x)
	v := (w0 * a.uv.y) + (w1 * b.uv.y) + (w2 * c.uv.y)
	x := i32(u * f64(tga.width))
	y := i32(v * f64(tga.height))
	return sample_tga(x, y, tga)
}

uv_normal_mapping :: proc(rgb: [3]u8) -> Vertex {
	// 0..255 -> 0..1 -> 0..2 -> -1..1
	return Vertex {
		x = (f64(rgb[0]) / 255) * 2 - 1,
		y = (f64(rgb[1]) / 255) * 2 - 1,
		z = (f64(rgb[2]) / 255) * 2 - 1,
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
	result := [4]f64{}
	transform(pipeline, v, 4, result[:])
	return Vec4{x = result[0], y = result[1], z = result[2], w = result[3]}
}

bounds :: proc(a, b, c: Coord) -> (Coord, Coord) {
	return Coord {
		x = min(a.x, b.x, c.x),
		y = min(a.y, b.y, c.y),
	}, Coord{x = max(a.x, b.x, c.x), y = max(a.y, b.y, c.y)}
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
