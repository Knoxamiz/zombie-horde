class_name NpcNavigationProfile
extends Resource

## Inspector-owned navigation tuning for a race map.
##
## The profile keeps route sequencing, path queries, avoidance, and local
## movement behavior together. A map can tune its own geometry without adding
## branches to Zombie or changing another map's race behavior.

@export_category("Route Sequencing")
@export_range(0.5, 12.0, 0.1) var checkpoint_reach_radius: float = 3.0
@export_range(0.0, 1.0, 0.05) var checkpoint_lane_spread: float = 0.58
@export_range(0.0, 1.0, 0.05) var finish_lane_spread: float = 0.82

@export_category("Path Queries")
@export_range(0.05, 2.0, 0.01) var target_refresh_interval: float = 0.20
@export_range(0.05, 4.0, 0.05) var target_refresh_distance: float = 0.65
@export_range(0.1, 4.0, 0.05) var path_desired_distance: float = 0.45
@export_range(0.1, 6.0, 0.05) var target_desired_distance: float = 0.9

@export_category("Avoidance")
@export_range(0.1, 2.0, 0.01) var agent_radius: float = 0.42
@export_range(0.5, 16.0, 0.1) var neighbor_distance: float = 4.5
@export_range(1, 64, 1) var max_neighbors: int = 12
@export_range(0.1, 5.0, 0.05) var time_horizon_agents: float = 1.4
@export_range(0.0, 1.0, 0.01) var avoidance_blend: float = 0.72

@export_category("Diagnostics")
@export var diagnostics_enabled: bool = false
