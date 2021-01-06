# Boomerang CICD Worker

This is the Boomerang CICD Worker that runs the build, test, and deploy activities for the out of the bose Component Modes.

This is based on the Gen 3 worker design for Boomerang Flow, meaning that there are fixed commands that punch out to shell scripts.

Depends on:

- [Boomerang Worker CLI & Core](https://github.com/boomerang-io/worker.interfaces)
- [Boomerang Worker Flow](https://github.com/boomerang-io/worker.flow)

## Design

There are three commands in this worker that are tightly coupled with their implementation

- Build: `/commands/build.js`
- Test: `/commands/test.js`
- Deploy: `/commands/deploy.js`

In turn, these commands rely on the bash scripts located in the `/scripts` directory.

## How to Build and Push

`VERSION=6.0.2 && docker build -t tools.boomerangplatform.net:8500/ise/bmrg-worker-cicd:$VERSION . && docker push tools.boomerangplatform.net:8500/ise/bmrg-worker-cicd:$VERSION`
