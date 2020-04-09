# Boomerang CICD Worker

Depends on: [Boomerang Base Worker](https://github.ibm.com/Boomerang-Workers/boomerang.worker.base)

This is the Boomerang CICD Worker that runs the build, test, and deploy activities for the out of the bose Component Modes.

## Design

There are three commands in this worker that are tightly coupled with their implementation
- Build: `commands/build.js`
- Test: `commands/test.js`
- Deploy: `commands/deploy.js`

In turn, these commands rely on the bash scripts located in the cicd directory.

## How to Build and Push

`VERSION=5.0.0 && docker build -t tools.boomerangplatform.net:8500/ise/bmrg-worker-cicd:$VERSION . && docker push tools.boomerangplatform.net:8500/ise/bmrg-worker-cicd:$VERSION`