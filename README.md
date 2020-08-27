# Boomerang CICD Worker

This is the Boomerang CICD Worker that runs the build, test, and deploy activities for the out of the bose Component Modes.

This is based on the Gen 2 worker design for CICD, meaning that there are fixed commands that punch out to shell scripts. This will evolve over time to match the Gen 3 design.

Depends on:

- [Boomerang Worker CLI](https://github.ibm.com/Boomerang-Workers/boomerang.worker.base)
- [Boomerang Worker Core](https://github.ibm.com/Boomerang-Workers/boomerang.worker.base)

## Design

There are three commands in this worker that are tightly coupled with their implementation

- Build: `/commands/build.js`
- Test: `/commands/test.js`
- Deploy: `/commands/deploy.js`

In turn, these commands rely on the bash scripts located in the `/scripts` directory.

## How to Build and Push

`VERSION=5.1.1 && docker build -t tools.boomerangplatform.net:8500/ise/bmrg-worker-cicd:$VERSION . && docker push tools.boomerangplatform.net:8500/ise/bmrg-worker-cicd:$VERSION`
