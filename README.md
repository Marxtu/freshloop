# FreshLoop — Smart Running Route Generator

A Flutter app that **designs** running routes for you: given a start point and a target
distance, it generates loop routes ranked by a quality score over **air quality**,
**elevation**, and **scenery/greenery**, with along-route photos — then lets you follow
the route with live GPS tracking and export a report.

Final project for *Design and Implementation of Mobile Applications* (Politecnico di
Milano, Prof. Luciano Baresi).

## Status

Design phase. No application code yet — see the design docs below.

## Documentation

- **Design (SSOT):** [`docs/level-2-architecture/running-route-generator-2026-05-30.md`](docs/level-2-architecture/running-route-generator-2026-05-30.md)
- **Foundation (course analysis):** [`docs/level-1-foundation/course-materials-analysis-2026-05-30.md`](docs/level-1-foundation/course-materials-analysis-2026-05-30.md)

## Tech stack

Flutter · flutter_bloc · http · geolocator · flutter_map (OSM) · go_router · Firebase · share_plus

## Secrets

API keys are never committed. Copy the `.example` templates to local config (gitignored).
See the design doc §13.7.
