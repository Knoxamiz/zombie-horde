class_name SurfaceSpawnResolver
extends RefCounted

## Shared z-aware placement helper for hazards, pickups, and other street-level spawns.


static func random_z(
	rng: RandomNumberGenerator,
	zones: Array[Dictionary],
	min_z: float,
	max_z: float
) -> float:
	if rng == null or zones.is_empty():
		return randf_range(min_z, max_z)

	var ranges: Array[Dictionary] = []
	var total_length: float = 0.0
	for zone in zones:
		var z0: float = maxf(float(zone.get("z0", 0.0)), min_z)
		var z1: float = minf(float(zone.get("z1", z0)), max_z)
		if z1 <= z0:
			continue
		total_length += z1 - z0
		ranges.append({"z0": z0, "z1": z1, "end_weight": total_length})

	if ranges.is_empty() or total_length <= 0.0:
		return rng.randf_range(min_z, max_z)

	var pick: float = rng.randf_range(0.0, total_length)
	for range_spec in ranges:
		if pick <= float(range_spec.get("end_weight", 0.0)):
			return rng.randf_range(
				float(range_spec.get("z0", min_z)),
				float(range_spec.get("z1", max_z))
			)
	var final_range: Dictionary = ranges[ranges.size() - 1]
	return rng.randf_range(
		float(final_range.get("z0", min_z)),
		float(final_range.get("z1", max_z))
	)


static func y_at_z(zones: Array[Dictionary], z: float, fallback: float) -> float:
	for zone in zones:
		var z0: float = float(zone.get("z0", 0.0))
		var z1: float = float(zone.get("z1", z0))
		if z < z0 - 0.05 or z > z1 + 0.05:
			continue
		if bool(zone.get("is_ramp", false)):
			var start_y: float = float(zone.get("start_y", fallback))
			var end_y: float = float(zone.get("end_y", start_y))
			var t: float = 0.0 if z1 <= z0 else clampf((z - z0) / (z1 - z0), 0.0, 1.0)
			return lerpf(start_y, end_y, t)
		return float(zone.get("y", fallback))
	return fallback


static func has_overlap(zones: Array[Dictionary], min_z: float, max_z: float) -> bool:
	if zones.is_empty():
		return true
	for zone in zones:
		var z0: float = maxf(float(zone.get("z0", 0.0)), min_z)
		var z1: float = minf(float(zone.get("z1", z0)), max_z)
		if z1 > z0:
			return true
	return false
