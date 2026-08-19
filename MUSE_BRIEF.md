# Muse brief 2 — finish what you started

You already did part of brief 1. Do not re-download BusinessMan. Do not rewrite the world. Do not touch soccer except if `JacobLook.animate` / `apply_team` signatures break strikers.

Godot 4.7.1. **Always run this scene:**

```
godot --path /Users/avewright/Projects/jacob_simulator res://scenes/main.tscn
```

Booting the project with no scene opens Super Strikers. That is the wrong game.

`GameState` autoload persists across Play/Stop. At the top of `scripts/main.gd` keep `in_car = false` unless you are restoring a save and immediately seating him.

---

## Already done (do not redo)

- `assets/characters/BusinessMan.glb` (Quaternius CC0). Clips: `CharacterArmature|Idle`, `|Walk`, `|Run`. Bones: `Head`, `Hips`, not `mixamorig_*`.
- `scripts/jacob_look.gd` loads BusinessMan first, Soldier only if the GLB is missing.
- `scripts/camry.gd` `try_enter()` snaps the car and force-enters in the lot. Same-frame exit is gated with `_enter_frame`.

---

## Still broken — this is the job

### 1. Movement / facing (highest priority)

`scripts/player.gd` is **unchanged**. `_cam_wish()` still uses `-camera.basis.z` and `look * -input_dir.y`. Mesh yaw is still:

```
atan2(wish.x, wish.z) + PI
```

`+ PI` was for Mixamo Soldier (faces −Z). BusinessMan is a different rig. That extra PI is the likely moonwalk / “inverted” feel.

**Do this in order:**

1. Put the camera **behind** Jacob looking at his back. `scripts/camera_rig.gd`: SpringArm must place `Camera3D` behind the look target, not in front of his face. `collision_mask` stays 0.
2. Wish: W must move him **away from the camera**, into the screen. Flatten look on XZ first, then `right = look.cross(Vector3.UP)`. Flip **one** sign if he walks toward the camera. Print one line while holding W: `look`, `wish`, `velocity` xz — they must agree.
3. Facing: drop `+ PI` first. If he still moonwalks, put it back. Only one of those is correct for BusinessMan. Soccer `striker.gd` still uses `+ PI`; only change it if strikers share this look and moonwalk too.
4. Do not stack more PI or invert look *and* input *and* yaw in the same pass.

Success: W = walk where you are looking. Mesh chest points that way. No moonwalk.

### 2. Face on the head

`_attach_face()` still uses Mixamo offsets (`z = 0.13 * unit` on `Head`). On BusinessMan the photo will likely sit on the wrong side of the skull.

- Bone is `Head` (already detected).
- Place the quad on the **front of the face**. If it is on the back of the head, negate Z (or rotate 180°).
- Scale the quad to the head, not a giant billboard.
- Keep chroma-key from `res://assets/image.png`.
- Delete the rambling comments in `_attach_face()`.

### 3. Prove E works

Do not add more snap branches. The enter path is already messy.

Play `main.tscn` (or reason the frame): spawn Jacob at `(16, 0, 3.2)`, car at `(16, 0, 0)`. On first E:

- `GameState.in_car == true`
- Jacob hidden (`enter_car`)
- camera `_target()` is the Camry
- W/S drive, second E (after 2 frames) exits beside the car

If E still no-ops, the player `_physics_process` is not running (`in_car` / `paused` / `process_mode`). Fix that. Do not ask the player to “walk closer.”

---

## Files

| Edit | Why |
|---|---|
| `scripts/player.gd` | wish + yaw for BusinessMan |
| `scripts/camera_rig.gd` | camera behind |
| `scripts/jacob_look.gd` | face placement, delete comment sludge |
| `scripts/camry.gd` | only if E still fails after prints |
| `scripts/soccer/striker.gd` | only if facing convention must match |

Do not edit `world_builder.gd`. Do not add markdown.

---

## Verify

```
godot --path /Users/avewright/Projects/jacob_simulator --headless --quit-after 8 res://scenes/main.tscn
```

No parse errors. Then play `main.tscn`:

1. Businessman (not Halo), face on the front of the head.
2. W walks into the look direction, mesh follows.
3. E drive, E exit.

Stop when those three pass. No new features.
