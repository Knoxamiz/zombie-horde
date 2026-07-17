# Race Navigation

Zombie Horde uses two complementary navigation layers. They have different
responsibilities and neither replaces the other.

## Authored race course

Every `RaceMapDefinition` owns ordered `race_path_points`. At runtime,
`RaceNavigationWorld` creates a child `Path3D` named `RaceCoursePath` from
those points. This is the authoritative course: a zombie's route navigator
advances only through the next authored segment and steers toward a point
ahead on that segment.

This is essential for elevated, looping, and stacked maps. A runner cannot
skip to a nearby deck, take a shortcut through empty space, or choose the
wrong side of a wall merely because it is closer to the final goal.

## Godot navigation and avoidance

Walkable collision surfaces opt into `race_navigation_surfaces`. The runtime
builder turns those surfaces into `NavigationRegion3D` instances and connects
touching pieces with `NavigationLink3D`. `NavigationAgent3D` receives the
current course checkpoint and performs local RVO crowd and vehicle avoidance.

Navigation avoidance can adjust a runner around nearby obstacles. It must not
replace or redirect the authored race course. New maps therefore need both:

1. Ordered `race_path_points` from spawn through every turn to finish.
2. Walkable `MapSurfacePiece` or kit collision marked as a navigation surface.

The direct navigation contract test verifies both layers and confirms that a
runtime `RaceCoursePath` matches every map definition.
