# roblox headless ai animation pipeline (azul edition)

A tuff ass programmatic animation pipeline for roblox studio. basically lets you use AI thru the mcp or your own scripts to automatically add frame-based markers and upload animations directly to roblox, completely bypassing the manual ui.

oh yeah and this project is built on top of a fork of the Blender-to-Roblox animation importer by cautioned, basically adding a headless orchestration layer.

> [!NOTE]
> **just looking for the AI orchestration module without the blender plugin?**
> check out the [standalone ai cutscene pipeline](https://github.com/Infrear/roblox-ai-cutscene-pipeline?tab=readme-ov-file) repository which is released under a MIT license.

## how it works

instead of manually adding markers in seconds or clicking through the roblox upload dialog, this pipeline lets an AI (or your own scripts) do the heavy lifting:

1. **import:** you import an animation from blender using the included plugin. the plugin captures your blender framerate and stores it directly on the animation as a `SourceFPS` attribute.
2. **author events (frame-based):** you tell your AI agent what markers to add at which **frames** (for example: "add 'FadeIn' at frame 90"), and the pipeline converts the frame accurately to seconds based on the original framerate.
3. **headless upload:** the pipeline programmatically uploads the animation using the modern `CreateAssetAsync` (and updates via `CreateAssetVersionAsync`), skipping the manual upload dialog entirely and returning the asset ID.

## installation (for regular users)

if you just want to install the plugin and get going, you don't need any command line tools at all:
1. download the `BlenderAnimationsAI.rbxmx` file from the github releases.
2. open your plugins folder in roblox studio and just drop the file in there. that's literally it!

## installation (for developers)

if you want to mess with the code and push your own updates, here's how you install the source:

1. **roblox studio:** as of august 2026, im pretty sure you gotta have the "Lua Asset Creation" beta feature enabled in studio for `CreateAssetAsync` to function properly.
2. **blender setup:** install the blender addon from the original creator's [github releases](https://github.com/cautioned/blender-animations-plugin/releases).
3. **roblox syncing:** this project is fully structured for both **azul** and **rojo**.
   - if you're on azul, just sync it directly into your place by running:
     ```bash
     azul --sync-dir ./
     ```
   - if you're on rojo, there's a `default.project.json` ready for you to use.
4. **building the plugin:** if you make changes and want to compile a fresh `.rbxmx` plugin file to release, just right-click the `build_roblox_plugin.ps1` file and hit "run with powershell". it automatically downloads the rojo compiler (if you don't have it), builds the plugin for you, and even drops it into your studio plugins folder automatically.
5. **mcp server:** to drive the pipeline via AI, you need an mcp server running locally with `execute_luau` capabilities to inject commands directly into your active studio window.

## usage (ai orchestration)

once the plugin is installed and an animation is saved to `AnimSaves`, your AI agent can execute commands like this via `execute_luau`:

```lua
local CIP = require(game.ServerScriptService.BlenderAnimationsInternal.Services.CutscenePipeline)

-- add an event at frame 90
CIP:addEvent("Camera Wake Up", "FadeIn", 90)

-- upload and get the Asset ID automatically
local assetId, err = CIP:upload("Camera Wake Up")
print("uploaded to:", assetId)
```

---

# original plugin info
*the following is preserved from the original Blender Animations Plugin by yaboi cautioned.*

A powerful Roblox Studio plugin that enables seamless animation workflow between Blender and Roblox, featuring real-time sync, advanced rigging tools, and comprehensive animation management.

### Features
- **Live Sync**: Enable live sync for real-time updates between Blender and Roblox
- **Bone Sync**: Create bones in Blender and sync them in studio as motor6ds.
- **Bone Toggles**: Use the Tools tab to enable/disable specific bones
- **Animation Scaling**: Adjust scale factors in the Tools tab
- **Camera Controls**: Attach a camera to a part, such as the head. Useful for viewport animations.
- **Easing Transfer**: Easing transfers losslessly between Roblox and Blender where possible.

### License
This project is licensed under the GNU General Public License v3.0 - see the LICENSE file for details.
