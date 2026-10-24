# 3D Character Art Quality Standards

## Overall Quality Target

All character models must meet **professional, commercial game-production standards**.

Aim for the visual quality of assets created by experienced 3D character artists using Blender, ZBrush, Substance Painter, and modern real-time game engines.

Our visual direction is **stylized realism with high-end PBR rendering**: recognizable, anatomically believable marine creatures with appealing character design, smooth organic forms, rich surface materials, and polished lighting.

These are final-production assets, not placeholders, primitive mockups, or programmer art.

## Geometry and Modeling

- Use smooth, flowing, organic silhouettes with no unintended polygonal faceting.
- Apply smooth shading and appropriate normal handling.
- Use sufficient geometry to preserve silhouette quality at the intended gameplay camera distance.
- Use subdivision modeling or sculpting workflows where appropriate.
- Maintain clean, efficient topology suitable for animation and deformation.
- Avoid obvious intersections, disconnected anatomy, abrupt transitions, and primitive-looking body construction.
- Model distinguishing anatomical characteristics of each marine species.

## Materials and Shaders

- Use physically based rendering (PBR) materials.
- Configure base color, roughness, metallic, and normal information appropriately.
- Marine animals should have believable skin, scale, shell, and membrane materials.
- Use subtle surface variation, microdetails, and specular highlights.
- Support translucency, subsurface scattering, iridescence, or clearcoat where appropriate and supported by the target engine.
- Avoid flat, unlit, plastic-looking materials unless intentionally required by the character design.
- Prefer biologically plausible material properties over indiscriminate glossiness.

## Character Design

- Preserve recognizable real-world anatomy while allowing expressive, game-friendly stylization.
- Maintain a consistent visual quality and art direction across species.
- Emphasize readable silhouettes, memorable features, and expressive personalities.
- Use professionally integrated eyes, mouths, fins, tentacles, and appendages.
- Avoid crude geometric approximations or visibly assembled primitive shapes.

## Game Readiness

- Optimize meshes and texture resolutions for real-time rendering.
- Prepare animation-friendly geometry and rigging where appropriate.
- Use LODs when warranted by runtime requirements.
- Ensure exported materials preserve their appearance in the actual game engine.
- Prioritize visual quality at gameplay distance rather than excessive invisible detail.

## Quality Assurance

Before considering any model complete:

1. Inspect the silhouette from multiple angles.
2. Check for faceting, shading artifacts, and geometry intersections.
3. Inspect the character under different lighting conditions.
4. Confirm materials render correctly in the target engine.
5. Evaluate the model at actual gameplay distance.
6. Compare its quality and art direction against approved reference assets.
7. Correct deficiencies before marking the model complete.

**Never treat a technically valid model as automatically being an artistically acceptable model.**

If the available tools or generation method cannot achieve these standards, identify the limitations and recommend a more suitable asset creation pipeline rather than silently lowering the quality bar.