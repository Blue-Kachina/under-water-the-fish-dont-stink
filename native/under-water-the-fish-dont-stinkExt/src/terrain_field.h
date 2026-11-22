// TerrainField: the procedural seabed's density field (planning_procedural_world.md, phase 1).
//
// A seeded, CPU-only, deterministic signed field on a regular grid (positive = water, negative = rock), built from:
// a warped floor, plateaus, an edge ring, mesas, arches, carved tunnels and cavities, erosion and strata. Then the
// navigability pass (rule N): thin rock lips are rounded off, floating specks dropped, and the water is opened by a
// ball of `clearance` from the spawn (no sealed pockets, no slots narrower than the biggest body). Surface nets mesh
// it per chunk; an exact distance grid answers the game's queries (sdf, floor height, headroom, reachability).
//
// Everything is in the owner's local space (the Seabed's: y 0 is the flat sand). Integer-hash noise, fixed iteration
// order and per-sample independence keep it bit-identical across runs and machines (co-op builds the same world).

#ifndef TERRAIN_FIELD_H
#define TERRAIN_FIELD_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <godot_cpp/variant/packed_float32_array.hpp>
#include <godot_cpp/variant/packed_vector3_array.hpp>
#include <godot_cpp/variant/vector3.hpp>

#include <godot_cpp/variant/vector3i.hpp>

#include <cstdint>
#include <functional>
#include <vector>

namespace godot {

class TerrainField : public RefCounted {
	GDCLASS(TerrainField, RefCounted)

public:
	struct Params {
		uint32_t seed = 1;
		float cell = 1.0f;
		Vector3 origin = Vector3(-170, -6, -170);
		Vector3 size = Vector3(340, 56, 340);
		int chunk_cells = 32;
		int threads = 0;
		float sand_cut = -0.3f;
		float cull_radius = 1e9f;  // quads wholly beyond this (x, z) radius aren't meshed (the ring's far side)
		// Floor
		float floor_base = -0.8f, floor_amp1 = 7.0f, floor_freq1 = 0.011f, floor_amp2 = 1.6f, floor_freq2 = 0.07f;
		float relief_inner = 60.0f, relief_outer = 120.0f;
		// Warp
		float warp_xz = 15.0f, warp_y = 6.0f, warp_freq = 0.04f;
		// Edge ring
		float ring_height = 45.0f, ring_inner = 140.0f, ring_outer = 160.0f, ring_warp = 10.0f;
		// Plateaus
		float plat_freq = 0.0125f, plat_threshold = 0.2f, plat_min = 8.0f, plat_max = 20.0f, plat_inner = 90.0f;
		// Erosion and strata
		float ero_amp1 = 1.2f, ero_freq1 = 0.17f, ero_amp2 = 0.5f, ero_freq2 = 0.41f, ero_fbm = 0.6f, ero_fade = 3.0f;
		float strata_amp = 0.35f, strata_spacing = 4.8f;
		float blend = 4.0f;
		// Slab: a solid block up to `slab_top` (local y, 0 = off) that replaces the floor/plateau/ring heightfield; channels carve it.
		float slab_top = 0.0f, slab_amp = 0.0f, slab_freq = 0.02f;
		// Navigability
		bool nav = true;
		Vector3 spawn = Vector3(0, 10, 0);
		float clearance = 3.0f, lip = 1.0f;
		bool drop_specks = true;
		// Features (flat records)
		std::vector<float> mesas;     // ax az bx bz radius height flare overhang waist base_y (10)
		std::vector<float> arches;    // cx cy cz dirx dirz major minor (7)
		std::vector<float> tunnels;   // ax ay az bx by bz r (7)
		std::vector<float> cavities;  // cx cy cz rx ry rz (6)
		std::vector<float> clearings; // x z r (3)
		std::vector<float> channels;  // ax ay az bx by bz width_a width_b height_a height_b open (11): a chain carved from the slab
	};

private:
	Params p;
	int nx = 0, ny = 0, nz = 0;
	std::vector<float> field;    // the meshed field (m, approximate distance)
	std::vector<float> dist;     // exact signed distance (m) for queries
	std::vector<uint8_t> reach;  // 1: water the biggest body can reach from the spawn
	std::vector<float> floor_h;  // per column: the lowest floor (local y)
	std::vector<float> head;     // per column: open water above that floor (m)
	std::vector<float> tri_pos;  // every meshed triangle (9 floats) for scatter sampling
	std::vector<float> tri_nrm;
	bool built = false;

	inline int idx(int i, int j, int k) const { return (k * ny + j) * nx + i; }
	float sample(const std::vector<float> &g, float x, float y, float z) const;
	void run_threads(int count, const std::function<void(int, int)> &job) const;
	void edt(std::vector<float> &f) const;  // squared EDT in place (cells), f = 0 at features, big elsewhere
	void build_columns();

protected:
	static void _bind_methods();

public:
	void configure(const Dictionary &params);
	Dictionary generate();
	bool is_built() const { return built; }
	Vector3i chunk_grid() const;
	Dictionary build_chunk(int cx, int cz);
	void clear_surface_cache();

	float sdf(const Vector3 &pos) const;
	Vector3 gradient(const Vector3 &pos) const;
	float floor_y(float x, float z) const;
	float headroom(float x, float z) const;
	float open_above(const Vector3 &pos) const;
	bool is_reachable(const Vector3 &pos) const;
	bool segment_clear(const Vector3 &a, const Vector3 &b, float radius) const;
	PackedVector3Array push_out(const PackedVector3Array &points, float radius) const;
	Dictionary sample_surface(int count, int seed, float ny_min, float ny_max, float y_min, float y_max, float r_max) const;
	Dictionary bake_openness(float cell, float reach_m, float absorb) const;
	Dictionary bake_sun_shadow(const Vector3 &to_sun, float cell) const;
	int64_t checksum() const;
	Dictionary info() const;
};

} // namespace godot

#endif
