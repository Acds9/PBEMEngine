# ZEngine

ZEngine (placeholder name) is a custom game engine built in [Jai](https://en.wikipedia.org/wiki/Jai_(programming_language)) developed for a [WeGo](https://en.wikipedia.org/wiki/Timekeeping_in_games#Simultaneously_executed_and_clock-based_turns) turn-based space strategy game.

## Overview

ZEngine is built around a custom Entity Component System called ZECS (also placeholder) and a GPU-driven Vulkan renderer. The engine targets Homeworld 2-era visual complexity with modern rendering techniques with the goal of achieving higher scene complexity and playercounts. 

The engine and game are intended to be tightly knit, with as few generalizations as possible and avoiding features or capabilities that will not be strictly necessary for the game itself. The goal is to keep complexity low and development speed high.
As such, many features common to more generalized engines (such as an editor window) are not planned at all. 

The engine began development mid-2025 as a part time project and is heavily WIP.

## Technical Highlights

- **ZECS** — Archetype-based ECS with heavy compile-time focus to leverage Jai's strong metaprogramming features. The composition of archetypes is known at compile time allowing the compiler to generate highly optimized queries.
- **Rendering** — A modern Vulkan renderer with a Clustered Forward/Forward+ system, a focus on bindless (multi-draw indirect, device buffer adresses, etc.), and GPU mesh and light culling.

## Status

Under active development. Core rendering systems are being implemented.