# Known issues

**Controller healing in combat isn't reliable yet.**
With a controller, switching spell pages (LB/RB) and casting from the grid may stop working once combat starts. **Mouse click-healing, mouse-wheel and hover keys are not affected.**
A redesigned controller mode is in progress: hold or tap a button to heal, A/B/X/Y to cast, the d-pad to move, plus a proper button-mapping screen. It's being tested before release.

**Layout changes wait until combat ends.**
Moving, resizing and roster rebuilds are blocked by the game during combat and apply as soon as you leave it.

**Demo squares are previews only.**
They can't cast or target. Turn the demo off with `/hr demo off` to heal your real group.

**Buff and debuff indicators only show what the client reports.**
Unknown casters or durations are not guessed. A shield icon means the shield is present, not how much it has left.

**Only tested on WoW Forever.**
Other clients or other raid-frame addons may conflict.

**If the frames or controller ever get stuck,** type `/reload`.

**Found a bug?** Open an issue at https://github.com/waterys419/HealingRain/issues with what you did, step by step, and any Lua error text.
