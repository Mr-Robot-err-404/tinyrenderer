package main

import "core:testing"

@(test)
test_viewport :: proc(t: ^testing.T) {
	vp := viewport(0, 0)

	// origin {0,0,0,1} -> {400, 400, 0}
	r0 := make([]f64, 4)
	transform(vp[:], []f64{0, 0, 0, 1}, 4, r0)
	testing.expectf(t, abs(r0[0] - 400) < 0.001, "origin x should be ~400, got %v", r0[0])
	testing.expectf(t, abs(r0[1] - 400) < 0.001, "origin y should be ~400, got %v", r0[1])

	// {1,0,0,1} -> {800, 400, 0}
	r1 := make([]f64, 4)
	transform(vp[:], []f64{1, 0, 0, 1}, 4, r1)
	testing.expectf(t, abs(r1[0] - 800) < 0.001, "{{1,0,0}} x should be ~800, got %v", r1[0])
	testing.expectf(t, abs(r1[1] - 400) < 0.001, "{{1,0,0}} y should be ~400, got %v", r1[1])

	// {0,1,0,1} -> {400, 800, 0}
	r2 := make([]f64, 4)
	transform(vp[:], []f64{0, 1, 0, 1}, 4, r2)
	testing.expectf(t, abs(r2[0] - 400) < 0.001, "{{0,1,0}} x should be ~400, got %v", r2[0])
	testing.expectf(t, abs(r2[1] - 800) < 0.001, "{{0,1,0}} y should be ~800, got %v", r2[1])
}

@(test)
test_perspective :: proc(t: ^testing.T) {
	eye := Vertex{-1, 0, 2}
	center := Vertex{0, 0, 0}
	up := Vertex{0, 1, 0}

	view := make([]f64, 16)
	modal(center, eye, up, view)
	pp := perspective(eye, center)
	persp_view := make([]f64, 16)
	compose(pp[:], view, 4, persp_view)

	// origin -> {0, 0, 0, w=1}
	r0 := make([]f64, 4)
	transform(persp_view, []f64{0, 0, 0, 1}, 4, r0)

	testing.expectf(t, abs(r0[0]) < 0.0001, "origin x should be ~0, got %v", r0[0])
	testing.expectf(t, abs(r0[1]) < 0.0001, "origin y should be ~0, got %v", r0[1])
	testing.expectf(t, abs(r0[3] - 1) < 0.0001, "origin w should be ~1, got %v", r0[3])

	// {1,0,0} -> {0.894427, 0, -0.447214, w=1.2}
	r1 := make([]f64, 4)
	transform(persp_view, []f64{1, 0, 0, 1}, 4, r1)
	testing.expectf(
		t,
		abs(r1[0] - 0.894427) < 0.0001,
		"{{1,0,0}} x should be ~0.894427, got %v",
		r1[0],
	)
	testing.expectf(t, abs(r1[1]) < 0.0001, "{{1,0,0}} y should be ~0, got %v", r1[1])
	testing.expectf(t, abs(r1[3] - 1.2) < 0.0001, "{{1,0,0}} w should be ~1.2, got %v", r1[3])
}

@(test)
test_pipeline :: proc(t: ^testing.T) {
	eye := Vertex{-1, 0, 2}
	center := Vertex{0, 0, 0}
	up := Vertex{0, 1, 0}

	view := make([]f64, 16)
	modal(center, eye, up, view)

	pp := perspective(eye, center)
	vp := viewport(0, 0)
	persp := make([]f64, 16)
	compose(vp[:], pp[:], 4, persp)

	pipeline := make([]f64, 16)
	compose(persp, view, 4, pipeline)

	// origin -> {400, 400, 0}
	r0 := pipe(pipeline, Vertex{0, 0, 0})
	testing.expectf(t, abs(f64(r0.x) - 400) < 1, "origin x should be ~400, got %v", r0.x)
	testing.expectf(t, abs(f64(r0.y) - 400) < 1, "origin y should be ~400, got %v", r0.y)

	// {1,0,0} -> {698.142, 400, ...}
	r1 := pipe(pipeline, Vertex{1, 0, 0})
	testing.expectf(t, abs(f64(r1.x) - 698) < 1, "{{1,0,0}} x should be ~698, got %v", r1.x)
	testing.expectf(t, abs(f64(r1.y) - 400) < 1, "{{1,0,0}} y should be ~400, got %v", r1.y)

	// {0,1,0} -> {400, 800, ...}
	r2 := pipe(pipeline, Vertex{0, 1, 0})
	testing.expectf(t, abs(f64(r2.x) - 400) < 1, "{{0,1,0}} x should be ~400, got %v", r2.x)
	testing.expectf(t, abs(f64(r2.y) - 800) < 1, "{{0,1,0}} y should be ~800, got %v", r2.y)
}
