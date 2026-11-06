# v0.7.3: Diagonal camera and softer shadows

This release changes how the game looks from the 3D camera. Combat, damage and movement rules are unchanged.

## Camera

- The camera is turned 45 degrees, so the lane runs diagonally up the screen, from the blue base at the bottom left to the red base at the top right.
- The camera now keeps your hero centred, including at the edges of the lane.
- Heroes face left or right based on where they are heading on screen.
- Arrow keys and screen-edge panning follow the screen, so up moves the view straight up.
- Sunlight, shadows and brush turn with the camera, so they look the same from the new angle.

## Shadows

- Shadows are shorter, softer and half as dark. A unit's shadow is now about half its height instead of about its full height.
- Low quality still turns shadows off.

## Known limits

- The minimap stays horizontal, so a point to the right on the map is up and to the right on screen.
- The diagonal view shows more empty sky around the bridge.
- Heroes have one drawn facing, mirrored left or right, so you see their front or side when they walk up the screen.
- High quality costs slightly more with softer shadows: about 61 frames per second in a live fight instead of about 64 on the test machine.

## Multiplayer

Everyone in a room must be on v0.7.3, because rooms only accept players on the same version. The network protocol is still 14, and existing progression is preserved.
