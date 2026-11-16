// TerrainField (see terrain_field.h). Ideas after abyssal-garden's W_DENS (github.com/Noniv/abyssal-garden, MIT): the
// warped floor, plateaus, edge ring, extruded mesas, torus arches, Worley erosion and strata. The code and its numbers
// are our own; no lines are ported.

#include "terrain_field.h"

#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/packed_color_array.hpp>
#include <godot_cpp/variant/color.hpp>
#include <godot_cpp/variant/vector2.hpp>
#include <godot_cpp/variant/vector2i.hpp>
#include <godot_cpp/variant/packed_int32_array.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include <algorithm>
#include <cstring>
#include <chrono>
#include <cmath>
#include <thread>

using namespace godot;

namespace {

const float BIG = 1e20f;

// --- Integer-hash noise (deterministic across machines) --------------------------------------------------

inline uint32_t hash3(int x, int y, int z, uint32_t s) {
	uint32_t h = s * 0x9E3779B1u;
	h ^= (uint32_t)x * 0x85EBCA77u;
	h = (h << 13) | (h >> 19);
	h ^= (uint32_t)y * 0xC2B2AE3Du;
	h = (h << 13) | (h >> 19);
	h ^= (uint32_t)z * 0x27D4EB2Fu;
	h ^= h >> 15;
	h *= 0x2C1B3C6Du;
	h ^= h >> 12;
	h *= 0x297A2D39u;
	h ^= h >> 15;
	return h;
}

inline float unit(uint32_t h) { return (float)(h & 0xFFFFFFu) * (1.0f / 16777215.0f); }
inline float signed_unit(uint32_t h) { return unit(h) * 2.0f - 1.0f; }
inline float fade(float t) { return t * t * t * (t * (t * 6.0f - 15.0f) + 10.0f); }
inline float lerpf(float a, float b, float t) { return a + (b - a) * t; }
inline float clampf(float v, float a, float b) { return v < a ? a : (v > b ? b : v); }
inline float smoothstepf(float a, float b, float x) {
	float t = clampf((x - a) / (b - a), 0.0f, 1.0f);
	return t * t * (3.0f - 2.0f * t);
}
inline float smin(float a, float b, float k) {
	if (k <= 0.0f) {
		return a < b ? a : b;
	}
	float h = std::max(k - std::fabs(a - b), 0.0f) / k;
	return std::min(a, b) - h * h * k * 0.25f;
}
inline float smax(float a, float b, float k) { return -smin(-a, -b, k); }

float value2(float x, float z, uint32_t s) {
	float fx = std::floor(x), fz = std::floor(z);
	int ix = (int)fx, iz = (int)fz;
	float tx = fade(x - fx), tz = fade(z - fz);
	float a = signed_unit(hash3(ix, 0, iz, s)), b = signed_unit(hash3(ix + 1, 0, iz, s));
	float c = signed_unit(hash3(ix, 0, iz + 1, s)), d = signed_unit(hash3(ix + 1, 0, iz + 1, s));
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), tz);
}

float value3(float x, float y, float z, uint32_t s) {
	float fx = std::floor(x), fy = std::floor(y), fz = std::floor(z);
	int ix = (int)fx, iy = (int)fy, iz = (int)fz;
	float tx = fade(x - fx), ty = fade(y - fy), tz = fade(z - fz);
	float v[8];
	for (int n = 0; n < 8; n++) {
		v[n] = signed_unit(hash3(ix + (n & 1), iy + ((n >> 1) & 1), iz + ((n >> 2) & 1), s));
	}
	float x0 = lerpf(v[0], v[1], tx), x1 = lerpf(v[2], v[3], tx), x2 = lerpf(v[4], v[5], tx), x3 = lerpf(v[6], v[7], tx);
	return lerpf(lerpf(x0, x1, ty), lerpf(x2, x3, ty), tz);
}

float fbm2(float x, float z, int octaves, uint32_t s) {
	float sum = 0.0f, amp = 1.0f, norm = 0.0f;
	for (int o = 0; o < octaves; o++) {
		sum += value2(x, z, s + (uint32_t)o * 101u) * amp;
		norm += amp;
		amp *= 0.5f;
		x = x * 2.03f + 17.1f;
		z = z * 2.03f - 9.7f;
	}
	return sum / norm;
}

float fbm3(float x, float y, float z, int octaves, uint32_t s) {
	float sum = 0.0f, amp = 1.0f, norm = 0.0f;
	for (int o = 0; o < octaves; o++) {
		sum += value3(x, y, z, s + (uint32_t)o * 101u) * amp;
		norm += amp;
		amp *= 0.5f;
		x = x * 2.03f + 17.1f;
		y = y * 2.03f + 5.3f;
		z = z * 2.03f - 9.7f;
	}
	return sum / norm;
}

// Worley F1, in cell units (about 0..1).
float worley3(float x, float y, float z, uint32_t s) {
	float fx = std::floor(x), fy = std::floor(y), fz = std::floor(z);
	int ix = (int)fx, iy = (int)fy, iz = (int)fz;
	float best = 9.0f;
	for (int dz = -1; dz <= 1; dz++) {
		for (int dy = -1; dy <= 1; dy++) {
			for (int dx = -1; dx <= 1; dx++) {
				uint32_t h = hash3(ix + dx, iy + dy, iz + dz, s);
				float px = (float)(ix + dx) + unit(h);
				float py = (float)(iy + dy) + unit(h * 0x9E3779B1u + 1u);
				float pz = (float)(iz + dz) + unit(h * 0x85EBCA77u + 7u);
				float ddx = px - x, ddy = py - y, ddz = pz - z;
				float d = ddx * ddx + ddy * ddy + ddz * ddz;
				best = d < best ? d : best;
			}
		}
	}
	return std::sqrt(best);
}

inline float seg_dist2(float px, float pz, float ax, float az, float bx, float bz) {
	float abx = bx - ax, abz = bz - az;
	float len2 = abx * abx + abz * abz;
	float t = len2 > 0.0f ? clampf(((px - ax) * abx + (pz - az) * abz) / len2, 0.0f, 1.0f) : 0.0f;
	float dx = px - (ax + abx * t), dz = pz - (az + abz * t);
	return std::sqrt(dx * dx + dz * dz);
}

inline float capsule3(const Vector3 &p, const Vector3 &a, const Vector3 &b, float r) {
	Vector3 ab = b - a;
	float len2 = ab.dot(ab);
	float t = len2 > 0.0f ? clampf((p - a).dot(ab) / len2, 0.0f, 1.0f) : 0.0f;
	return (p - (a + ab * t)).length() - r;
}

inline float ellipsoid(const Vector3 &p, const Vector3 &r) {
	float k0 = Vector3(p.x / r.x, p.y / r.y, p.z / r.z).length();
	float k1 = Vector3(p.x / (r.x * r.x), p.y / (r.y * r.y), p.z / (r.z * r.z)).length();
	return k1 > 0.0f ? k0 * (k0 - 1.0f) / k1 : -std::min(r.x, std::min(r.y, r.z));
}

// splitmix64, for scatter sampling.
struct Dice {
	uint64_t state;
	explicit Dice(uint64_t s) : state(s * 0x9E3779B97F4A7C15ull + 0xD1B54A32D192ED03ull) {}
	uint64_t next() {
		uint64_t z = (state += 0x9E3779B97F4A7C15ull);
		z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ull;
		z = (z ^ (z >> 27)) * 0x94D049BB133111EBull;
		return z ^ (z >> 31);
	}
	float f() { return (float)(next() >> 40) * (1.0f / 16777216.0f); }
};

double now_ms() {
	return std::chrono::duration<double, std::milli>(std::chrono::steady_clock::now().time_since_epoch()).count();
}

std::vector<float> to_vec(const Variant &v) {
	std::vector<float> out;
	PackedFloat32Array a = v;
	out.resize(a.size());
	for (int64_t i = 0; i < a.size(); i++) {
		out[i] = a[i];
	}
	return out;
}

} // namespace

// --- Setup ------------------------------------------------------------------------------------------------

void TerrainField::configure(const Dictionary &d) {
	Params q;
	q.seed = (uint32_t)(int64_t)d.get("seed", 1);
	q.cell = std::max(0.25f, (float)d.get("cell", 1.0));
	q.origin = d.get("origin", q.origin);
	q.size = d.get("size", q.size);
	q.chunk_cells = std::max(4, (int)d.get("chunk_cells", 32));
	q.threads = (int)d.get("threads", 0);
	q.sand_cut = d.get("sand_cut", q.sand_cut);
	q.cull_radius = d.get("cull_radius", q.cull_radius);
#define TF_GET(name) q.name = (float)d.get(#name, q.name)
	TF_GET(floor_base);
	TF_GET(floor_amp1);
	TF_GET(floor_freq1);
	TF_GET(floor_amp2);
	TF_GET(floor_freq2);
	TF_GET(relief_inner);
	TF_GET(relief_outer);
	TF_GET(warp_xz);
	TF_GET(warp_y);
	TF_GET(warp_freq);
	TF_GET(ring_height);
	TF_GET(ring_inner);
	TF_GET(ring_outer);
	TF_GET(ring_warp);
	TF_GET(plat_freq);
	TF_GET(plat_threshold);
	TF_GET(plat_min);
	TF_GET(plat_max);
	TF_GET(plat_inner);
	TF_GET(ero_amp1);
	TF_GET(ero_freq1);
	TF_GET(ero_amp2);
	TF_GET(ero_freq2);
	TF_GET(ero_fbm);
	TF_GET(ero_fade);
	TF_GET(strata_amp);
	TF_GET(strata_spacing);
	TF_GET(blend);
	TF_GET(clearance);
	TF_GET(lip);
#undef TF_GET
	q.nav = d.get("nav", true);
	q.drop_specks = d.get("drop_specks", true);
	q.spawn = d.get("spawn", q.spawn);
	q.mesas = to_vec(d.get("mesas", PackedFloat32Array()));
	q.arches = to_vec(d.get("arches", PackedFloat32Array()));
	q.tunnels = to_vec(d.get("tunnels", PackedFloat32Array()));
	q.cavities = to_vec(d.get("cavities", PackedFloat32Array()));
	q.clearings = to_vec(d.get("clearings", PackedFloat32Array()));
	p = q;
	built = false;
}

void TerrainField::run_threads(int count, const std::function<void(int, int)> &job) const {
	int t = p.threads > 0 ? p.threads : (int)std::thread::hardware_concurrency();
	t = std::max(1, std::min(t, std::min(count, 32)));
	if (t == 1) {
		job(0, count);
		return;
	}
	std::vector<std::thread> pool;
	pool.reserve(t);
	for (int n = 0; n < t; n++) {
		int a = count * n / t, b = count * (n + 1) / t;
		pool.emplace_back([&job, a, b]() { job(a, b); });
	}
	for (auto &th : pool) {
		th.join();
	}
}

// Felzenszwalb-Huttenlocher squared distance transform, separable over x, y, z. `f` is 0 at features and BIG
// elsewhere; on return it holds the squared distance (in cells) to the nearest feature.
void TerrainField::edt(std::vector<float> &f) const {
	float *g = f.data();
	auto pass = [&](int n, int lines, const std::function<int64_t(int, int)> &at) {
		run_threads(lines, [&](int a, int b) {
			std::vector<float> src(n), out(n), zz(n + 1);
			std::vector<int> v(n);
			for (int line = a; line < b; line++) {
				for (int q = 0; q < n; q++) {
					src[q] = g[at(line, q)];
				}
				int k = 0;
				v[0] = 0;
				zz[0] = -BIG;
				zz[1] = BIG;
				for (int q = 1; q < n; q++) {
					float s = ((src[q] + (float)q * q) - (src[v[k]] + (float)v[k] * v[k])) / (2.0f * (q - v[k]));
					while (s <= zz[k]) {
						k--;
						s = ((src[q] + (float)q * q) - (src[v[k]] + (float)v[k] * v[k])) / (2.0f * (q - v[k]));
					}
					k++;
					v[k] = q;
					zz[k] = s;
					zz[k + 1] = BIG;
				}
				k = 0;
				for (int q = 0; q < n; q++) {
					while (zz[k + 1] < (float)q) {
						k++;
					}
					float dq = (float)(q - v[k]);
					out[q] = dq * dq + src[v[k]];
				}
				for (int q = 0; q < n; q++) {
					g[at(line, q)] = std::min(out[q], BIG);
				}
			}
		});
	};
	const int X = nx, Y = ny, Z = nz;
	pass(X, Y * Z, [X](int line, int q) { return (int64_t)line * X + q; });
	pass(Y, X * Z, [X, Y](int line, int q) {
		int i = line % X, k = line / X;
		return ((int64_t)k * Y + q) * X + i;
	});
	pass(Z, X * Y, [X, Y](int line, int q) {
		int i = line % X, j = line / X;
		return ((int64_t)q * Y + j) * X + i;
	});
}

Dictionary TerrainField::generate() {
	double t0 = now_ms();
	const float c = p.cell;
	nx = std::max(4, (int)std::ceil(p.size.x / c) + 1);
	ny = std::max(4, (int)std::ceil(p.size.y / c) + 1);
	nz = std::max(4, (int)std::ceil(p.size.z / c) + 1);
	const int64_t total = (int64_t)nx * ny * nz;
	field.assign(total, 0.0f);
	tri_pos.clear();
	tri_nrm.clear();
	const uint32_t S = p.seed;

	// Per column: the floor, the heightfield top (floor + plateau + ring), and a few noises shared by every sample.
	const int cols = nx * nz;
	std::vector<float> col_floor(cols), col_top(cols), col_n(cols);
	const int MAXC = 12;
	std::vector<uint8_t> cand_n(cols, 0);
	std::vector<uint8_t> cand(cols * MAXC);
	const int mesa_count = (int)(p.mesas.size() / 10);
	std::vector<float> mesa_reach(mesa_count);
	for (int m = 0; m < mesa_count; m++) {
		const float *r = &p.mesas[m * 10];
		mesa_reach[m] = r[4] * (1.0f + std::max(r[6], 0.0f) + std::max(r[7], 0.0f)) + p.blend + p.warp_xz * 0.7f + 3.0f;
	}
	const int clear_count = (int)(p.clearings.size() / 3);
	run_threads(nz, [&](int ka, int kb) {
		for (int k = ka; k < kb; k++) {
			for (int i = 0; i < nx; i++) {
				const int col = k * nx + i;
				const float x = p.origin.x + i * c, z = p.origin.z + k * c;
				const float wx = x + p.warp_xz * fbm2(x * p.warp_freq, z * p.warp_freq, 2, S + 11u);
				const float wz = z + p.warp_xz * fbm2(x * p.warp_freq + 31.7f, z * p.warp_freq - 12.3f, 2, S + 12u);
				const float r = std::sqrt(wx * wx + wz * wz);
				float open = 1.0f;
				for (int n = 0; n < clear_count; n++) {
					const float *cl = &p.clearings[n * 3];
					float dx = x - cl[0], dz = z - cl[1];
					open = std::min(open, smoothstepf(cl[2] * 0.6f, cl[2], std::sqrt(dx * dx + dz * dz)));
				}
				const float relief = smoothstepf(p.relief_inner, p.relief_outer, r) * open;
				float fl = p.floor_base;
				if (relief > 0.0f) {
					fl += relief * (p.floor_amp1 * fbm2(wx * p.floor_freq1, wz * p.floor_freq1, 3, S + 21u) +
										   p.floor_amp2 * fbm2(wx * p.floor_freq2, wz * p.floor_freq2, 3, S + 22u));
				}
				float top = fl;
				if (p.plat_max > 0.0f) {
					float mask = smoothstepf(p.plat_inner, p.plat_inner + 20.0f, r) * open;
					if (mask > 0.0f) {
						float n = fbm2(wx * p.plat_freq, wz * p.plat_freq, 3, S + 31u);
						float tall = lerpf(p.plat_min, p.plat_max, 0.5f + 0.5f * fbm2(wx * 0.007f, wz * 0.007f, 2, S + 32u));
						top += tall * smoothstepf(p.plat_threshold, p.plat_threshold + 0.05f, n) * mask;
					}
				}
				if (p.ring_height > 0.0f) {
					float rr = r + p.ring_warp * fbm2(wx * 0.02f, wz * 0.02f, 2, S + 41u);
					float rise = smoothstepf(p.ring_inner, p.ring_outer, rr);
					top += p.ring_height * rise * (0.85f + 0.15f * fbm2(wx * 0.03f, wz * 0.03f, 2, S + 42u));
				}
				col_floor[col] = fl;
				col_top[col] = top;
				col_n[col] = fbm2(x * 0.05f, z * 0.05f, 2, S + 51u);
				int nc = 0;
				for (int m = 0; m < mesa_count && nc < MAXC; m++) {
					const float *rec = &p.mesas[m * 10];
					if (seg_dist2(x, z, rec[0], rec[1], rec[2], rec[3]) < mesa_reach[m]) {
						cand[col * MAXC + nc++] = (uint8_t)m;
					}
				}
				cand_n[col] = (uint8_t)nc;
			}
		}
	});

	// A coarse 3D warp (4 cells), for the 3D features and the erosion.
	const int WS = 4;
	const int wx_n = nx / WS + 2, wy_n = ny / WS + 2, wz_n = nz / WS + 2;
	std::vector<float> warp((size_t)wx_n * wy_n * wz_n * 3);
	run_threads(wz_n, [&](int ka, int kb) {
		for (int k = ka; k < kb; k++) {
			for (int j = 0; j < wy_n; j++) {
				for (int i = 0; i < wx_n; i++) {
					float x = (p.origin.x + i * WS * c) * p.warp_freq, y = (p.origin.y + j * WS * c) * p.warp_freq,
						  z = (p.origin.z + k * WS * c) * p.warp_freq;
					size_t at = (((size_t)k * wy_n + j) * wx_n + i) * 3;
					warp[at] = p.warp_xz * 0.5f * fbm3(x, y, z, 2, S + 61u);
					warp[at + 1] = p.warp_y * fbm3(x + 19.1f, y, z - 7.7f, 2, S + 62u);
					warp[at + 2] = p.warp_xz * 0.5f * fbm3(x - 3.3f, y + 11.9f, z, 2, S + 63u);
				}
			}
		}
	});
	auto warp_at = [&](int i, int j, int k, float out[3]) {
		float gx = (float)i / WS, gy = (float)j / WS, gz = (float)k / WS;
		int ix = std::min((int)gx, wx_n - 2), iy = std::min((int)gy, wy_n - 2), iz = std::min((int)gz, wz_n - 2);
		float tx = gx - ix, ty = gy - iy, tz = gz - iz;
		for (int a = 0; a < 3; a++) {
			auto W = [&](int di, int dj, int dk) { return warp[((((size_t)(iz + dk)) * wy_n + (iy + dj)) * wx_n + (ix + di)) * 3 + a]; };
			float x00 = lerpf(W(0, 0, 0), W(1, 0, 0), tx), x10 = lerpf(W(0, 1, 0), W(1, 1, 0), tx);
			float x01 = lerpf(W(0, 0, 1), W(1, 0, 1), tx), x11 = lerpf(W(0, 1, 1), W(1, 1, 1), tx);
			out[a] = lerpf(lerpf(x00, x10, ty), lerpf(x01, x11, ty), tz);
		}
	};

	const int arch_count = (int)(p.arches.size() / 7);
	const int tunnel_count = (int)(p.tunnels.size() / 7);
	const int cavity_count = (int)(p.cavities.size() / 6);
	const float band = p.ero_amp1 + p.ero_amp2 + p.ero_fbm + p.strata_amp + 0.75f;
	const float TAU = 6.2831853f;
	double t_cols = now_ms();
	float *F = field.data();
	run_threads(nz, [&](int ka, int kb) {
		for (int k = ka; k < kb; k++) {
			for (int i = 0; i < nx; i++) {
				const int col = k * nx + i;
				const float x = p.origin.x + i * c, z = p.origin.z + k * c;
				const float top = col_top[col], fl = col_floor[col];
				const int nc = cand_n[col];
				for (int j = 0; j < ny; j++) {
					const float y = p.origin.y + j * c;
					float s = y - top;
					float w[3] = { 0.0f, 0.0f, 0.0f };
					bool warped = false;
					if (nc > 0 || arch_count > 0 || std::fabs(s) < band + p.blend) {
						warp_at(i, j, k, w);
						warped = true;
					}
					const float qx = x + w[0], qy = y + w[1], qz = z + w[2];
					for (int n = 0; n < nc; n++) {
						const float *m = &p.mesas[cand[col * MAXC + n] * 10];
						const float base = m[9], tall = m[5];
						float t = clampf((qy - base) / tall, 0.0f, 1.0f);
						float rad = m[4] * (1.0f + m[6] * (1.0f - t) * (1.0f - t) * (1.0f - t) - m[8] * 4.0f * t * (1.0f - t) +
												   m[7] * smoothstepf(0.62f, 1.0f, t));
						float d2 = seg_dist2(qx, qz, m[0], m[1], m[2], m[3]) - rad;
						float dy = qy - (base + tall + 2.0f * col_n[col]);
						s = smin(s, smax(d2, dy, 2.0f), p.blend);
					}
					for (int n = 0; n < arch_count; n++) {
						const float *a = &p.arches[n * 7];
						// Arches take a third of the warp, so their holes stay where the layout sized them.
						float vx = x + w[0] * 0.3f - a[0], vy = y + w[1] * 0.3f - a[1], vz = z + w[2] * 0.3f - a[2];
						float axial = vx * a[3] + vz * a[4];
						float inplane = -vx * a[4] + vz * a[3];
						float ring = std::sqrt(inplane * inplane + vy * vy) - a[5];
						float d = std::sqrt(ring * ring + axial * axial) - a[6];
						s = smin(s, d, p.blend * 0.5f);
					}
					if (warped && std::fabs(s) < band) {
						float lift = smoothstepf(0.5f, p.ero_fade, y - fl);
						if (lift > 0.0f) {
							float e = 0.0f;
							if (p.ero_amp1 > 0.0f) {
								e += p.ero_amp1 * (0.55f - worley3(qx * p.ero_freq1, qy * p.ero_freq1, qz * p.ero_freq1, S + 71u));
							}
							if (p.ero_amp2 > 0.0f) {
								e += p.ero_amp2 * (0.55f - worley3(qx * p.ero_freq2, qy * p.ero_freq2, qz * p.ero_freq2, S + 72u));
							}
							if (p.ero_fbm > 0.0f) {
								e += p.ero_fbm * fbm3(qx * 0.22f, qy * 0.22f, qz * 0.22f, 2, S + 73u);
							}
							if (p.strata_amp > 0.0f && p.strata_spacing > 0.0f) {
								e += p.strata_amp * std::sin(TAU * qy / p.strata_spacing + 1.5f * col_n[col]);
							}
							s += e * lift;
						}
					}
					const Vector3 pos(x, y, z);
					for (int n = 0; n < tunnel_count; n++) {
						const float *t = &p.tunnels[n * 7];
						s = std::max(s, -capsule3(pos, Vector3(t[0], t[1], t[2]), Vector3(t[3], t[4], t[5]), t[6]));
					}
					for (int n = 0; n < cavity_count; n++) {
						const float *cv = &p.cavities[n * 6];
						s = std::max(s, -ellipsoid(pos - Vector3(cv[0], cv[1], cv[2]), Vector3(cv[3], cv[4], cv[5])));
					}
					F[idx(i, j, k)] = s;
				}
			}
		}
	});
	double t_field = now_ms();

	std::vector<float> a(total), b;
	int dropped_lips = 0, specks = 0, sealed = 0;
	// Rule N, 1: thin lips and fins (rock thinner than 2 x lip) are rounded off.
	if (p.nav && p.lip > 0.0f) {
		for (int64_t n = 0; n < total; n++) {
			a[n] = F[n] < 0.0f ? BIG : 0.0f;
		}
		edt(a);
		const float core2 = (p.lip / c) * (p.lip / c);
		b.assign(total, BIG);
		for (int64_t n = 0; n < total; n++) {
			b[n] = (F[n] < 0.0f && a[n] > core2) ? 0.0f : BIG;
		}
		edt(b);
		for (int64_t n = 0; n < total; n++) {
			float v = std::sqrt(b[n]) * c - p.lip;
			if (F[n] < 0.0f && v > 0.0f) {
				dropped_lips++;
			}
			F[n] = std::max(F[n], v);
		}
	}
	// Floating specks: rock not joined to the bottom of the grid becomes water.
	if (p.drop_specks) {
		std::vector<uint8_t> seen(total, 0);
		std::vector<int64_t> stack;
		for (int k = 0; k < nz; k++) {
			for (int i = 0; i < nx; i++) {
				int64_t n = idx(i, 0, k);
				if (F[n] < 0.0f) {
					seen[n] = 1;
					stack.push_back(n);
				}
			}
		}
		while (!stack.empty()) {
			int64_t n = stack.back();
			stack.pop_back();
			int i = (int)(n % nx), j = (int)((n / nx) % ny), k = (int)(n / ((int64_t)nx * ny));
			const int nb[6][3] = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } };
			for (auto &d : nb) {
				int ii = i + d[0], jj = j + d[1], kk = k + d[2];
				if (ii < 0 || jj < 0 || kk < 0 || ii >= nx || jj >= ny || kk >= nz) {
					continue;
				}
				int64_t m = idx(ii, jj, kk);
				if (!seen[m] && F[m] < 0.0f) {
					seen[m] = 1;
					stack.push_back(m);
				}
			}
		}
		for (int64_t n = 0; n < total; n++) {
			if (F[n] < 0.0f && !seen[n]) {
				F[n] = 0.5f * c;
				specks++;
			}
		}
	}
	// Rule N, 2: open the water by a ball of `clearance` from the spawn. Water that ball can't reach (sealed pockets,
	// slots and creases narrower than it) is filled with rock, along the ball's own surface.
	reach.assign(total, 0);
	if (p.nav && p.clearance > 0.0f) {
		for (int64_t n = 0; n < total; n++) {
			a[n] = F[n] < 0.0f ? 0.0f : BIG;
		}
		edt(a);
		const float need2 = (p.clearance / c) * (p.clearance / c);
		int si = (int)std::lround((p.spawn.x - p.origin.x) / c), sj = (int)std::lround((p.spawn.y - p.origin.y) / c),
			sk = (int)std::lround((p.spawn.z - p.origin.z) / c);
		si = std::clamp(si, 0, nx - 1);
		sk = std::clamp(sk, 0, nz - 1);
		sj = std::clamp(sj, 0, ny - 1);
		while (sj < ny - 1 && a[idx(si, sj, sk)] <= need2) {
			sj++;
		}
		std::vector<int64_t> stack;
		int64_t start = idx(si, sj, sk);
		if (a[start] > need2) {
			reach[start] = 1;
			stack.push_back(start);
		}
		while (!stack.empty()) {
			int64_t n = stack.back();
			stack.pop_back();
			int i = (int)(n % nx), j = (int)((n / nx) % ny), k = (int)(n / ((int64_t)nx * ny));
			const int nb[6][3] = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } };
			for (auto &d : nb) {
				int ii = i + d[0], jj = j + d[1], kk = k + d[2];
				if (ii < 0 || jj < 0 || kk < 0 || ii >= nx || jj >= ny || kk >= nz) {
					continue;
				}
				int64_t m = idx(ii, jj, kk);
				if (!reach[m] && a[m] > need2) {
					reach[m] = 1;
					stack.push_back(m);
				}
			}
		}
		b.assign(total, BIG);
		for (int64_t n = 0; n < total; n++) {
			b[n] = reach[n] ? 0.0f : BIG;
		}
		edt(b);
		for (int64_t n = 0; n < total; n++) {
			float v = p.clearance - std::sqrt(b[n]) * c;
			if (F[n] >= 0.0f && v < 0.0f) {
				sealed++;
			}
			F[n] = std::min(F[n], v);
			reach[n] = F[n] >= 0.0f ? 1 : 0;
		}
	} else {
		for (int64_t n = 0; n < total; n++) {
			reach[n] = F[n] >= 0.0f ? 1 : 0;
		}
	}
	double t_nav = now_ms();

	// The exact signed distance, for the queries.
	for (int64_t n = 0; n < total; n++) {
		a[n] = F[n] < 0.0f ? 0.0f : BIG;
	}
	edt(a);
	b.assign(total, BIG);
	for (int64_t n = 0; n < total; n++) {
		b[n] = F[n] < 0.0f ? BIG : 0.0f;
	}
	edt(b);
	dist.resize(total);
	for (int64_t n = 0; n < total; n++) {
		dist[n] = F[n] >= 0.0f ? std::sqrt(std::min(a[n], 1e8f)) * c - 0.5f * c : -(std::sqrt(std::min(b[n], 1e8f)) * c - 0.5f * c);
	}
	std::vector<float>().swap(a);
	std::vector<float>().swap(b);
	build_columns();
	built = true;
	double t_end = now_ms();

	Dictionary out;
	out["dims"] = Vector3i(nx, ny, nz);
	out["ms_columns"] = t_cols - t0;
	out["ms_field"] = t_field - t_cols;
	out["ms_nav"] = t_nav - t_field;
	out["ms_dist"] = t_end - t_nav;
	out["ms_total"] = t_end - t0;
	out["lip_cells"] = dropped_lips;
	out["speck_cells"] = specks;
	out["sealed_cells"] = sealed;
	return out;
}

void TerrainField::build_columns() {
	floor_h.assign((size_t)nx * nz, p.floor_base);
	head.assign((size_t)nx * nz, 1e4f);
	const float c = p.cell;
	const float *F = field.data();
	for (int k = 0; k < nz; k++) {
		for (int i = 0; i < nx; i++) {
			int j = 0;
			float fl = p.origin.y;
			bool found = false;
			for (; j < ny - 1; j++) {
				float s0 = F[idx(i, j, k)], s1 = F[idx(i, j + 1, k)];
				if (s0 < 0.0f && s1 >= 0.0f) {
					fl = p.origin.y + (j + s0 / (s0 - s1)) * c;
					found = true;
					break;
				}
			}
			if (!found && F[idx(i, 0, k)] < 0.0f) {
				fl = p.origin.y + (ny - 1) * c;  // solid to the top
			}
			floor_h[k * nx + i] = fl;
			float hd = 1e4f;
			for (j = j + 1; j < ny - 1; j++) {
				float s0 = F[idx(i, j, k)], s1 = F[idx(i, j + 1, k)];
				if (s0 >= 0.0f && s1 < 0.0f) {
					hd = p.origin.y + (j + s0 / (s0 - s1)) * c - fl;
					break;
				}
			}
			head[k * nx + i] = hd;
		}
	}
}

// --- Meshing (surface nets) -------------------------------------------------------------------------------

Vector3i TerrainField::chunk_grid() const {
	if (!built) {
		return Vector3i();
	}
	int C = p.chunk_cells;
	return Vector3i((nx - 1 + C - 1) / C, 1, (nz - 1 + C - 1) / C);
}

void TerrainField::clear_surface_cache() {
	tri_pos.clear();
	tri_nrm.clear();
}

Dictionary TerrainField::build_chunk(int cx, int cz) {
	Dictionary out;
	if (!built) {
		return out;
	}
	const int C = p.chunk_cells;
	const int i0 = cx * C, k0 = cz * C;
	const int i1 = std::min(i0 + C, nx - 1), k1 = std::min(k0 + C, nz - 1);
	if (i0 >= i1 || k0 >= k1) {
		return out;
	}
	const float c = p.cell;
	const float *F = field.data();
	// Cells i0-1 .. i1 (inclusive) and k0-1 .. k1: their vertices, made on demand.
	const int W = i1 - i0 + 2, H = ny - 1, D = k1 - k0 + 2;
	std::vector<int> local((size_t)W * H * D, -2);  // -2 not made, -1 none
	std::vector<Vector3> vpos;
	std::vector<Vector3> vnrm;
	std::vector<float> vao;
	auto cell_vertex = [&](int i, int j, int k) -> int {
		if (i < 0 || j < 0 || k < 0 || i >= nx - 1 || j >= ny - 1 || k >= nz - 1) {
			return -1;
		}
		size_t li = ((size_t)(k - (k0 - 1)) * H + j) * W + (i - (i0 - 1));
		if (local[li] != -2) {
			return local[li];
		}
		float v[8];
		int mask = 0;
		for (int n = 0; n < 8; n++) {
			v[n] = F[idx(i + (n & 1), j + ((n >> 1) & 1), k + ((n >> 2) & 1))];
			if (v[n] < 0.0f) {
				mask |= 1 << n;
			}
		}
		if (mask == 0 || mask == 255) {
			local[li] = -1;
			return -1;
		}
		static const int E[12][2] = { { 0, 1 }, { 2, 3 }, { 4, 5 }, { 6, 7 }, { 0, 2 }, { 1, 3 }, { 4, 6 }, { 5, 7 }, { 0, 4 }, { 1, 5 }, { 2, 6 }, { 3, 7 } };
		float sx = 0, sy = 0, sz = 0;
		int cnt = 0;
		for (auto &e : E) {
			float a = v[e[0]], b = v[e[1]];
			if ((a < 0.0f) == (b < 0.0f)) {
				continue;
			}
			float t = a / (a - b);
			float ax = (float)(e[0] & 1), ay = (float)((e[0] >> 1) & 1), az = (float)((e[0] >> 2) & 1);
			float bx = (float)(e[1] & 1), by = (float)((e[1] >> 1) & 1), bz = (float)((e[1] >> 2) & 1);
			sx += ax + (bx - ax) * t;
			sy += ay + (by - ay) * t;
			sz += az + (bz - az) * t;
			cnt++;
		}
		Vector3 pos = p.origin + Vector3(i + sx / cnt, j + sy / cnt, k + sz / cnt) * c;
		Vector3 g(sample(field, pos.x + c, pos.y, pos.z) - sample(field, pos.x - c, pos.y, pos.z),
				sample(field, pos.x, pos.y + c, pos.z) - sample(field, pos.x, pos.y - c, pos.z),
				sample(field, pos.x, pos.y, pos.z + c) - sample(field, pos.x, pos.y, pos.z - c));
		float gl = g.length();
		Vector3 nrm = gl > 1e-6f ? g / gl : Vector3(0, 1, 0);
		// Ambient occlusion from the exact distance, a few steps out along the normal.
		float ao = 0.0f;
		const float steps[4] = { 1.0f, 2.0f, 4.0f, 8.0f };
		for (float st : steps) {
			ao += clampf(sample(dist, pos.x + nrm.x * st, pos.y + nrm.y * st, pos.z + nrm.z * st) / st, 0.0f, 1.0f);
		}
		int id = (int)vpos.size();
		vpos.push_back(pos);
		vnrm.push_back(nrm);
		vao.push_back(ao * 0.25f);
		local[li] = id;
		return id;
	};

	std::vector<int> used;  // vertex id -> output index
	PackedVector3Array out_v, out_n, faces;
	PackedColorArray out_c;
	PackedInt32Array out_i;
	auto emit = [&](int id) -> int {
		if (id >= (int)used.size()) {
			used.resize(id + 1, -1);
		}
		if (used[id] < 0) {
			used[id] = (int)out_v.size();
			out_v.push_back(vpos[id]);
			out_n.push_back(vnrm[id]);
			out_c.push_back(Color(vao[id], 0.0f, 0.0f, 1.0f));
		}
		return used[id];
	};
	auto quad = [&](int a, int b, int cc, int d, const Vector3 &outward) {
		if (a < 0 || b < 0 || cc < 0 || d < 0) {
			return;
		}
		if (vpos[a].y < p.sand_cut && vpos[b].y < p.sand_cut && vpos[cc].y < p.sand_cut && vpos[d].y < p.sand_cut) {
			return;
		}
		const float cr2 = p.cull_radius * p.cull_radius;
		auto far = [&](int v) { return vpos[v].x * vpos[v].x + vpos[v].z * vpos[v].z > cr2; };
		if (far(a) && far(b) && far(cc) && far(d)) {
			return;
		}
		Vector3 crossv = (vpos[b] - vpos[a]).cross(vpos[cc] - vpos[a]);
		if (crossv.dot(outward) > 0.0f) {  // Godot's front faces wind clockwise
			std::swap(b, d);
		}
		int ids[4] = { emit(a), emit(b), emit(cc), emit(d) };
		const int tri[6] = { 0, 1, 2, 0, 2, 3 };
		for (int t : tri) {
			out_i.push_back(ids[t]);
		}
		const int src[4] = { a, b, cc, d };
		for (int t : tri) {
			const Vector3 &q = vpos[src[t]];
			faces.push_back(q);
			tri_pos.push_back(q.x);
			tri_pos.push_back(q.y);
			tri_pos.push_back(q.z);
			const Vector3 &nn = vnrm[src[t]];
			tri_nrm.push_back(nn.x);
			tri_nrm.push_back(nn.y);
			tri_nrm.push_back(nn.z);
		}
	};
	for (int k = k0; k < k1; k++) {
		for (int j = 0; j < ny - 1; j++) {
			for (int i = i0; i < i1; i++) {
				float s0 = F[idx(i, j, k)];
				bool r0 = s0 < 0.0f;
				// x edge
				if (j >= 1 && k >= 1 && (F[idx(i + 1, j, k)] < 0.0f) != r0) {
					quad(cell_vertex(i, j - 1, k - 1), cell_vertex(i, j, k - 1), cell_vertex(i, j, k), cell_vertex(i, j - 1, k),
							Vector3(r0 ? 1.0f : -1.0f, 0, 0));
				}
				// y edge
				if (i >= 1 && k >= 1 && (F[idx(i, j + 1, k)] < 0.0f) != r0) {
					quad(cell_vertex(i - 1, j, k - 1), cell_vertex(i, j, k - 1), cell_vertex(i, j, k), cell_vertex(i - 1, j, k),
							Vector3(0, r0 ? 1.0f : -1.0f, 0));
				}
				// z edge
				if (i >= 1 && j >= 1 && k + 1 < nz && (F[idx(i, j, k + 1)] < 0.0f) != r0) {
					quad(cell_vertex(i - 1, j - 1, k), cell_vertex(i, j - 1, k), cell_vertex(i, j, k), cell_vertex(i - 1, j, k),
							Vector3(0, 0, r0 ? 1.0f : -1.0f));
				}
			}
		}
	}
	if (out_i.is_empty()) {
		return out;
	}
	out["vertices"] = out_v;
	out["normals"] = out_n;
	out["colors"] = out_c;
	out["indices"] = out_i;
	out["faces"] = faces;
	return out;
}

// --- Queries ----------------------------------------------------------------------------------------------

float TerrainField::sample(const std::vector<float> &g, float x, float y, float z) const {
	const float c = p.cell;
	float gx = (x - p.origin.x) / c, gy = (y - p.origin.y) / c, gz = (z - p.origin.z) / c;
	float ox = 0.0f, oy = 0.0f, oz = 0.0f;  // how far outside the grid (m)
	if (gx < 0.0f) { ox = -gx * c; gx = 0.0f; }
	if (gy < 0.0f) { oy = -gy * c; gy = 0.0f; }
	if (gz < 0.0f) { oz = -gz * c; gz = 0.0f; }
	if (gx > nx - 1.001f) { ox = (gx - (nx - 1.001f)) * c; gx = nx - 1.001f; }
	if (gy > ny - 1.001f) { oy = (gy - (ny - 1.001f)) * c; gy = ny - 1.001f; }
	if (gz > nz - 1.001f) { oz = (gz - (nz - 1.001f)) * c; gz = nz - 1.001f; }
	int i = (int)gx, j = (int)gy, k = (int)gz;
	float tx = gx - i, ty = gy - j, tz = gz - k;
	const float *G = g.data();
	float c00 = lerpf(G[idx(i, j, k)], G[idx(i + 1, j, k)], tx), c10 = lerpf(G[idx(i, j + 1, k)], G[idx(i + 1, j + 1, k)], tx);
	float c01 = lerpf(G[idx(i, j, k + 1)], G[idx(i + 1, j, k + 1)], tx), c11 = lerpf(G[idx(i, j + 1, k + 1)], G[idx(i + 1, j + 1, k + 1)], tx);
	float v = lerpf(lerpf(c00, c10, ty), lerpf(c01, c11, ty), tz);
	float out = std::sqrt(ox * ox + oy * oy + oz * oz);
	return v >= 0.0f ? v + out : v + out;  // outside the grid only adds distance (rock below stays rock-ish)
}

float TerrainField::sdf(const Vector3 &pos) const {
	return built ? sample(dist, pos.x, pos.y, pos.z) : 1e4f;
}

Vector3 TerrainField::gradient(const Vector3 &pos) const {
	if (!built) {
		return Vector3(0, 1, 0);
	}
	const float h = p.cell;
	Vector3 g(sample(dist, pos.x + h, pos.y, pos.z) - sample(dist, pos.x - h, pos.y, pos.z),
			sample(dist, pos.x, pos.y + h, pos.z) - sample(dist, pos.x, pos.y - h, pos.z),
			sample(dist, pos.x, pos.y, pos.z + h) - sample(dist, pos.x, pos.y, pos.z - h));
	float l = g.length();
	return l > 1e-6f ? g / l : Vector3(0, 1, 0);
}

float TerrainField::floor_y(float x, float z) const {
	if (!built) {
		return p.floor_base;
	}
	float gx = (x - p.origin.x) / p.cell, gz = (z - p.origin.z) / p.cell;
	if (gx < 0.0f || gz < 0.0f || gx > nx - 1.001f || gz > nz - 1.001f) {
		return p.floor_base;
	}
	int i = (int)gx, k = (int)gz;
	float tx = gx - i, tz = gz - k;
	const float *H = floor_h.data();
	return lerpf(lerpf(H[k * nx + i], H[k * nx + i + 1], tx), lerpf(H[(k + 1) * nx + i], H[(k + 1) * nx + i + 1], tx), tz);
}

float TerrainField::headroom(float x, float z) const {
	if (!built) {
		return 1e4f;
	}
	int i = (int)std::lround((x - p.origin.x) / p.cell), k = (int)std::lround((z - p.origin.z) / p.cell);
	if (i < 0 || k < 0 || i >= nx || k >= nz) {
		return 1e4f;
	}
	return head[k * nx + i];
}

float TerrainField::open_above(const Vector3 &pos) const {
	if (!built) {
		return 1e4f;
	}
	const float top = p.origin.y + (ny - 1) * p.cell;
	float y = pos.y;
	while (y < top) {
		float d = sample(dist, pos.x, y, pos.z);
		if (d < 0.0f) {
			return y - pos.y;
		}
		y += std::max(d, p.cell * 0.5f);
	}
	return 1e4f;
}

bool TerrainField::is_reachable(const Vector3 &pos) const {
	if (!built) {
		return true;
	}
	int i = (int)std::lround((pos.x - p.origin.x) / p.cell), j = (int)std::lround((pos.y - p.origin.y) / p.cell),
		k = (int)std::lround((pos.z - p.origin.z) / p.cell);
	if (i < 0 || j < 0 || k < 0 || i >= nx || j >= ny || k >= nz) {
		return j >= 0;
	}
	return reach[idx(i, j, k)] != 0;
}

bool TerrainField::segment_clear(const Vector3 &a, const Vector3 &b, float radius) const {
	if (!built) {
		return true;
	}
	Vector3 d = b - a;
	float len = d.length();
	if (len < 1e-5f) {
		return sdf(a) >= radius;
	}
	d /= len;
	float t = 0.0f;
	while (t <= len) {
		float s = sdf(a + d * t) - radius;
		if (s < 0.0f) {
			return false;
		}
		t += std::max(s, p.cell * 0.5f);
	}
	return sdf(b) >= radius;
}

PackedVector3Array TerrainField::push_out(const PackedVector3Array &points, float radius) const {
	PackedVector3Array out;
	out.resize(points.size());
	for (int64_t n = 0; n < points.size(); n++) {
		Vector3 q = points[n];
		float s = built ? sdf(q) : 1e4f;
		out.set(n, s < radius ? gradient(q) * (radius - s) : Vector3());
	}
	return out;
}

Dictionary TerrainField::sample_surface(int count, int seed, float ny_min, float ny_max, float y_min, float y_max, float r_max) const {
	Dictionary out;
	PackedVector3Array pts, nrms;
	const size_t tris = tri_pos.size() / 9;
	std::vector<double> cum;
	std::vector<uint32_t> keep;
	double acc = 0.0;
	for (size_t t = 0; t < tris; t++) {
		const float *q = &tri_pos[t * 9];
		Vector3 a(q[0], q[1], q[2]), b(q[3], q[4], q[5]), cc(q[6], q[7], q[8]);
		Vector3 cr = (b - a).cross(cc - a);
		float area = cr.length() * 0.5f;
		if (area <= 1e-6f) {
			continue;
		}
		Vector3 fn = -cr / (area * 2.0f);  // clockwise winding: the outward normal is -cross
		Vector3 mid = (a + b + cc) / 3.0f;
		if (fn.y < ny_min || fn.y > ny_max || mid.y < y_min || mid.y > y_max || std::sqrt(mid.x * mid.x + mid.z * mid.z) > r_max) {
			continue;
		}
		acc += area;
		cum.push_back(acc);
		keep.push_back((uint32_t)t);
	}
	if (keep.empty() || count <= 0) {
		out["points"] = pts;
		out["normals"] = nrms;
		out["area"] = 0.0;
		return out;
	}
	Dice dice((uint64_t)(int64_t)seed);
	for (int n = 0; n < count; n++) {
		double u = (double)dice.f() * acc;
		size_t at = (size_t)(std::lower_bound(cum.begin(), cum.end(), u) - cum.begin());
		at = std::min(at, keep.size() - 1);
		const float *q = &tri_pos[keep[at] * 9];
		const float *nn = &tri_nrm[keep[at] * 9];
		float r1 = std::sqrt(dice.f()), r2 = dice.f();
		float wa = 1.0f - r1, wb = r1 * (1.0f - r2), wc = r1 * r2;
		pts.push_back(Vector3(q[0] * wa + q[3] * wb + q[6] * wc, q[1] * wa + q[4] * wb + q[7] * wc, q[2] * wa + q[5] * wb + q[8] * wc));
		Vector3 nv(nn[0] * wa + nn[3] * wb + nn[6] * wc, nn[1] * wa + nn[4] * wb + nn[7] * wc, nn[2] * wa + nn[5] * wb + nn[8] * wc);
		nrms.push_back(nv.normalized());
	}
	out["points"] = pts;
	out["normals"] = nrms;
	out["area"] = acc;
	return out;
}

// --- Light bakes (phase 5) --------------------------------------------------------------------------------

Dictionary TerrainField::bake_openness(float cell, float reach_m, float absorb) const {
	Dictionary out;
	if (!built || cell <= 0.0f) {
		return out;
	}
	const int ox = (int)std::ceil(p.size.x / cell) + 1, oy = (int)std::ceil(p.size.y / cell) + 1, oz = (int)std::ceil(p.size.z / cell) + 1;
	std::vector<float> open((size_t)ox * oy * oz), sky((size_t)ox * oy * oz, 0.0f);
	auto at = [&](int i, int j, int k) { return ((size_t)k * oy + j) * ox + i; };
	run_threads(oz, [&](int ka, int kb) {
		for (int k = ka; k < kb; k++) {
			for (int j = 0; j < oy; j++) {
				for (int i = 0; i < ox; i++) {
					Vector3 q = p.origin + Vector3(i, j, k) * cell;
					open[at(i, j, k)] = sample(dist, q.x, q.y, q.z);
				}
			}
		}
	});
	// Skylight, swept down from the top: each layer is the (1,2,1)-blurred layer above, absorbed by the water a
	// little and by rock wholly.
	std::vector<float> layer((size_t)ox * oz, 1.0f), tmp((size_t)ox * oz);
	const float keep = 1.0f - clampf(absorb, 0.0f, 1.0f);
	for (int j = oy - 1; j >= 0; j--) {
		for (int k = 0; k < oz; k++) {
			for (int i = 0; i < ox; i++) {
				float l = layer[k * ox + std::max(i - 1, 0)], m = layer[k * ox + i], r = layer[k * ox + std::min(i + 1, ox - 1)];
				tmp[k * ox + i] = (l + 2.0f * m + r) * 0.25f;
			}
		}
		for (int k = 0; k < oz; k++) {
			for (int i = 0; i < ox; i++) {
				float u = tmp[std::max(k - 1, 0) * ox + i], m = tmp[k * ox + i], d = tmp[std::min(k + 1, oz - 1) * ox + i];
				float v = (u + 2.0f * m + d) * 0.25f;
				float o = open[at(i, j, k)];
				v *= o < 0.0f ? 0.0f : keep;
				layer[k * ox + i] = v;
				sky[at(i, j, k)] = v;
			}
		}
	}
	PackedByteArray data;
	data.resize((int64_t)ox * oy * oz * 2);
	uint8_t *w = data.ptrw();
	for (int k = 0; k < oz; k++) {
		for (int j = 0; j < oy; j++) {
			for (int i = 0; i < ox; i++) {
				size_t n = at(i, j, k);
				w[n * 2] = (uint8_t)std::lround(clampf(open[n] / reach_m, 0.0f, 1.0f) * 255.0f);
				w[n * 2 + 1] = (uint8_t)std::lround(clampf(sky[n], 0.0f, 1.0f) * 255.0f);
			}
		}
	}
	out["data"] = data;
	out["size"] = Vector3i(ox, oy, oz);
	out["origin"] = p.origin;
	out["cell"] = cell;
	return out;
}

Dictionary TerrainField::bake_sun_shadow(const Vector3 &to_sun, float cell) const {
	Dictionary out;
	if (!built || cell <= 0.0f || to_sun.y <= 0.05f) {
		return out;
	}
	Vector3 L = to_sun.normalized();
	const float top = p.origin.y + (ny - 1) * p.cell, bottom = p.origin.y;
	const int sx = (int)std::ceil(p.size.x / cell) + 1, sz = (int)std::ceil(p.size.z / cell) + 1;
	PackedFloat32Array data;
	data.resize((int64_t)sx * sz);
	float *w = data.ptrw();
	run_threads(sz, [&](int ka, int kb) {
		for (int k = ka; k < kb; k++) {
			for (int i = 0; i < sx; i++) {
				// The sun's line through (x, 0, z): from the grid's top down to its bottom, the first rock hit.
				Vector3 p0 = Vector3(p.origin.x + i * cell, 0.0f, p.origin.z + k * cell);
				float t = top / L.y, t_end = bottom / L.y;
				float hit = -1e4f;
				while (t > t_end) {
					Vector3 q = p0 + L * t;
					float d = sample(dist, q.x, q.y, q.z);
					if (d < 0.0f) {
						hit = q.y;
						break;
					}
					t -= std::max(d, p.cell * 0.5f);
				}
				w[k * sx + i] = hit;
			}
		}
	});
	out["data"] = data;
	out["size"] = Vector2i(sx, sz);
	out["origin"] = Vector2(p.origin.x, p.origin.z);
	out["cell"] = cell;
	out["to_sun"] = L;
	return out;
}

int64_t TerrainField::checksum() const {
	uint64_t h = 1469598103934665603ull;
	for (float v : field) {
		uint32_t bits;
		std::memcpy(&bits, &v, 4);
		h = (h ^ bits) * 1099511628211ull;
	}
	return (int64_t)(h & 0x7FFFFFFFFFFFFFFFull);
}

Dictionary TerrainField::info() const {
	Dictionary out;
	out["dims"] = Vector3i(nx, ny, nz);
	out["cell"] = p.cell;
	out["origin"] = p.origin;
	out["triangles"] = (int64_t)(tri_pos.size() / 9);
	out["built"] = built;
	return out;
}

void TerrainField::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configure", "params"), &TerrainField::configure);
	ClassDB::bind_method(D_METHOD("generate"), &TerrainField::generate);
	ClassDB::bind_method(D_METHOD("is_built"), &TerrainField::is_built);
	ClassDB::bind_method(D_METHOD("chunk_grid"), &TerrainField::chunk_grid);
	ClassDB::bind_method(D_METHOD("build_chunk", "cx", "cz"), &TerrainField::build_chunk);
	ClassDB::bind_method(D_METHOD("clear_surface_cache"), &TerrainField::clear_surface_cache);
	ClassDB::bind_method(D_METHOD("sdf", "pos"), &TerrainField::sdf);
	ClassDB::bind_method(D_METHOD("gradient", "pos"), &TerrainField::gradient);
	ClassDB::bind_method(D_METHOD("floor_y", "x", "z"), &TerrainField::floor_y);
	ClassDB::bind_method(D_METHOD("headroom", "x", "z"), &TerrainField::headroom);
	ClassDB::bind_method(D_METHOD("open_above", "pos"), &TerrainField::open_above);
	ClassDB::bind_method(D_METHOD("is_reachable", "pos"), &TerrainField::is_reachable);
	ClassDB::bind_method(D_METHOD("segment_clear", "a", "b", "radius"), &TerrainField::segment_clear);
	ClassDB::bind_method(D_METHOD("push_out", "points", "radius"), &TerrainField::push_out);
	ClassDB::bind_method(D_METHOD("sample_surface", "count", "seed", "ny_min", "ny_max", "y_min", "y_max", "r_max"), &TerrainField::sample_surface);
	ClassDB::bind_method(D_METHOD("bake_openness", "cell", "reach", "absorb"), &TerrainField::bake_openness);
	ClassDB::bind_method(D_METHOD("bake_sun_shadow", "to_sun", "cell"), &TerrainField::bake_sun_shadow);
	ClassDB::bind_method(D_METHOD("checksum"), &TerrainField::checksum);
	ClassDB::bind_method(D_METHOD("info"), &TerrainField::info);
}
