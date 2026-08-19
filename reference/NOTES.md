# Pulled-in resources

These are in the repo so we can steal from them instead of guessing. `reference/` is ignored by Godot import (see `.gdignore`) so it does not clutter the game project.

## Truck Town (official Godot demo)

- **Path:** `reference/truck_town/`
- **Open it:** File → Import in Godot, or `godot --path reference/truck_town`
- **Upstream:** https://github.com/godotengine/godot-demo-projects/tree/master/3d/truck_town
- **Docs:** https://docs.godotengine.org/en/4.7/classes/class_vehiclebody3d.html
- **License:** MIT (Godot demo projects). Ambient/model credits are in that folder's `README.md`.

What we want from it:
- `vehicles/vehicle.gd` — real `VehicleBody3D` (engine_force, steering, brake). Camry is still a `CharacterBody3D` arcade car.
- Engine pitch from speed, impact sounds on sudden velocity change.
- Follow camera in `vehicles/follow_camera.gd`.

What we already copied into the game:
- `assets/audio/truck_town/engine.wav`
- `assets/audio/truck_town/impact_1.wav`
- `assets/audio/truck_town/impact_2.wav`
- Camry now uses those for engine loop + hit thumps.

Next step when driving still feels fake: replace `scripts/camry.gd` with a VehicleBody3D setup modeled on `car_base.tscn`.

## Mixamo + MixaBridge

- **Plugin:** `addons/mixabridge/` (enabled in Project Settings → Plugins)
- **Upstream:** https://github.com/uzairdeveloper223/mixabridge
- **License:** MIT (Uzair Mughal). Not affiliated with Adobe.
- **Drop folder:** `assets/characters/mixamo/` — put FBX here after you download from Mixamo.

Mixamo itself cannot be vendored. You download in a browser (free Adobe login):

1. https://www.mixamo.com — Characters → pick a regular man (not Vanguard / Soldier).
2. Download the character **FBX, T-pose, with skin**.
3. Animations tab: **Idle**, **Walking**, **Running**, optionally **Entering Car**. Download each as **FBX, without skin, in-place**.
4. Drop files in `assets/characters/mixamo/`.
5. In Godot, open the **MixaBridge** bottom panel: select the character FBX, link an AnimationPlayer, add the anim FBXs, Process All.
6. Point `JacobLook` at that new scene instead of hiding the Halo soldier.

Until those FBXs are in the folder, Jacob uses the Soldier mesh (visor hidden, navy tint, face photo). Do **not** hide `vanguard_Mesh` and replace it with bone boxes — that made him invisible.

## Bugs we already hit

- Hiding the soldier mesh + BoneAttachment primitives = no Jacob on screen.
- `GameState.in_car` is an autoload. Re-running the scene without New Game left him hidden and already "in" the car.
- SpringArm colliding with hedges/buildings flipped the camera in front of Jacob, so WASD felt inverted.
- Mission `try_interact` was stealing E before the Camry. Car is checked first now. Enter range is 12m.

## Other links we are using as the north star

| Thing | URL |
|---|---|
| Godot 4.7 docs | https://docs.godotengine.org/en/4.7/ |
| Import 3D scenes | https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/index.html |
| AnimationTree | https://docs.godotengine.org/en/4.7/tutorials/animation/animation_tree.html |
| Official demos | https://github.com/godotengine/godot-demo-projects |
| Kenney (CC0 props/cars/UI/sfx) | https://kenney.nl |
| Quaternius | https://quaternius.com |
| Poly Haven (HDRI / textures) | https://polyhaven.com |
| GDQuest | https://www.gdquest.com |
