# Vehicles — Camry Sedan

Quaternius `Car` via Poly Pizza — CC0 (public domain)

- Poly Pizza page: https://poly.pizza/m/Cz6yDaUcM9
- Static GLB (analogous to BusinessMan): https://static.poly.pizza/59a67a6c-490e-472e-bae6-5a4d2541f1c7.glb
- Local: `res://assets/vehicles/sedan.glb` (169K) — baked Y-up, front +Z (Rx -90), Camry paint #8a0f18 via Blender.
- Godot import: `res://assets/vehicles/sedan.glb.import` (uid dpo73xllew81i).
- Fallback: `reference/truck_town/vehicles/meshes/meshes.glb` (minivan) — MIT. Procedural boxes in `camry.gd _build()` are kept as fallback (hidden when sedan loads).

Usage in `scripts/camry.gd`:

- `_build()` loads `SEDAN_PATH` (`res://assets/vehicles/sedan.glb`) as `PackedScene`, instances as `Sedan` (scale ~1.03 to hit length 4.35), otherwise shows procedural boxes (`Procedural` Node3D, hidden when sedan active).
- Keeps `CharacterBody3D` driving: W/S gas/brake, Space handbrake, E enter/exit with snap + `_enter_frame` gate (2 frames), and `in_car` logic.
- Collision unchanged: `BoxShape3D` 1.9×0.85×4.2 at y 0.55 in `scenes/vehicles/camry.tscn`.
- Wheels are part of the GLB (4 meshes) — no runtime CylinderMesh needed when sedan loads.
