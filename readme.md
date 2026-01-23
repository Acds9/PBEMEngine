# ZEngine

A custom game engine built in [Jai](https://jai.community/t/welcome-to-jai-community/6) with Vulkan, developed for a [WeGo](https://en.wikipedia.org/wiki/Timekeeping_in_games#Simultaneously_executed_and_clock-based_turns) turn-based space strategy game.

## Overview

ZECS is built around a custom Entity Component System and a GPU-driven Vulkan renderer. The engine targets Homeworld 2-era visual complexity with modern rendering techniques, aiming for 240fps at 4K resolution.

The game design features one ship per player (rather than fleet command), prediction ghosts showing future positions, and an asynchronous multiplayer model supporting hundreds of players per match. Clients and servers exchange turn files rather than maintaining real-time connections.

## Technical Highlights

- **Custom ECS** — Compile-time code generation for queries and iteration
- **Vulkan 1.3+** — Bindless textures, buffer device addresses, multi-draw indirect
- **Clustered forward rendering** — Targeting ~1000 dynamic lights
- **GPU-driven pipeline** — Minimal CPU-side draw call overhead
- **Deterministic simulation** — Server runs headless, clients replay from compressed turn files

## Status

Under active development. Core rendering systems are being implemented.

## Building

Requires the Jai compiler and Vulkan SDK.
```
jai build.jai
```

## License

[TBD]