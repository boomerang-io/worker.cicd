const { log, utils, CICDError } = require("@boomerang-io/worker-core");
const shell = require("shelljs");

// TODO: Move enums to a shared constants file to be used for other commands
const ComponentMode = {
  Nodejs: "nodejs",
  Python: "python",
  Java: "java",
  Jar: "lib.jar",
  Helm: "helm.chart"
};

const SystemMode = {
  Java: "java",
  Wheel: "lib.wheel",
  Jar: "lib.jar",
  NPM: "lib.npm",
  Nodejs: "nodejs",
  Python: "python",
  Helm: "helm.chart",
  Docker: "docker"
};

// Freeze so they can't be modified at runtime
Object.freeze(ComponentMode);
Object.freeze(SystemMode);

function exec(command) {
  return new Promise(function(resolve, reject) {
    log.debug("Command directory:", shell.pwd().toString());
    log.debug("Command to execute:", command);
    shell.exec(command, config, function(code, stdout, stderr) {
      if (code) {
        reject(new CICDError(code, stderr));
      }
      resolve(stdout ? stdout : stderr);
    });
  });
}

function parseVersion(version, appendBuildNumber) {
  const parsedVersion = version;
  // Trim build number
  if (appendBuildNumber === false) {
    log.sys("Stripping build number from version...");
    parsedVersion = version.substr(0, version.lastIndexOf("-"));
  }
  log.debug("  Version:", parsedVersion);
  return parsedVersion;
}

module.exports = {
  async java() {
    log.debug("Starting Boomerang CICD Java build activity...");

    //Destructure and get properties ready.
    const taskParms = utils.resolveInputParameters();
    // const { path, script } = taskParms;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    const version = parseVersion(taskParms["version"], taskParms["build-number-append"]);

    try {
      await exec(`${shellDir}/common/initialize.sh ${taskParms["languageVersion"]}`);
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParms["languageVersion"]}`);
      await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh ${taskParms["buildTool"]} ${taskParms["buildToolVersion"]}`);

      shell.cd("/data/workspace");
      log.ci("Compile & Package Artifact(s)");
      await exec(`${shellDir}/build/compile-java.sh ${taskParms["buildTool"]} ${taskParms["buildToolVersion"]} ${version} ${JSON.stringify(taskParms["repoUrl"])} ${taskParms["repoId"]} ${taskParms["repoUser"]} "${taskParms["repoPassword"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Java build activity");
    }
  },
  async java() {
    log.debug("Starting Boomerang CICD Java build activity...");

    //Destructure and get properties ready.
    const taskParms = utils.resolveInputParameters();
    // const { path, script } = taskParms;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // Trim build number
    if (taskParms["build-number-append"] === false) {
      log.sys("Stripping build number from version...");
      taskParms["version"] = taskParms["version"].substr(0, taskParms["version"].lastIndexOf("-"));
    }
    log.debug("  Version:", taskParms["version"]);

    try {
      await exec(`${shellDir}/common/initialize.sh ${taskParms["languageVersion"]}`);
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParms["languageVersion"]}`);
      await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh ${taskParms["buildTool"]} ${taskParms["buildToolVersion"]}`);

      shell.cd("/data/workspace");
      log.ci("Compile & Package Artifact(s)");
      await exec(`${shellDir}/build/compile-java.sh ${taskParms["buildTool"]} ${taskParms["buildToolVersion"]} ${taskParms["version"]} ${JSON.stringify(taskParms["repoUrl"])} ${taskParms["repoId"]} ${taskParms["repoUser"]} "${taskParms["repoPassword"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Java build activity");
    }
  },
  async execute() {
    log.debug("Started CICD Build Activity");

    //Destructure and get properties ready.
    const taskProps = utils.resolveCICDInputProperties();
    // const { path, script } = taskProps;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    try {
      if (taskProps["build.number.append"] === false) {
        log.sys("Stripping build number from version...");
        taskProps["version.name"] = taskProps["version.name"].substr(0, taskProps["version.name"].lastIndexOf("-"));
        log.debug("  Version:", taskProps["version.name"]);
      }

      await exec(`${shellDir} / common / initialize.sh "${taskProps["language.version"]}"`);
      log.ci("Initializing Dependencies");
      if (taskProps["system.mode"] === SystemMode.Jar || taskProps["system.mode"] === SystemMode.Java) {
        await exec(`${shellDir} / common / initialize - dependencies - java.sh "${taskProps["language.version"]}"`);
        await exec(`${shellDir} / common / initialize - dependencies - java - tool.sh "${taskProps["build.tool"]}" "${taskProps["build.tool.version"]}"`);
      } else if (taskProps["system.mode"] === SystemMode.Nodejs) {
        await exec(`${shellDir} / common / initialize - dependencies - node.sh "${taskProps["build.tool"]}" "${JSON.stringify(taskProps["global / artifactory.url"])}" "${taskProps["global / artifactory.user"]}" "${taskProps["global / artifactory.password"]}"`);
      } else if (taskProps["system.mode"] === SystemMode.Python || taskProps["system.mode"] === SystemMode.Wheel) {
        await exec(`${shellDir} / common / initialize - dependencies - python.sh "${taskProps["language.version"]}"`);
      } else if (taskProps["system.mode"] === SystemMode.Helm) {
        await exec(`${shellDir} / common / initialize - dependencies - helm.sh "${taskProps["build.tool"]}"`);
      }

      if (taskProps["build.before_clone.enable"] === "true") {
        log.ci("Retrieving Before_Clone Source Code");
        await exec(`${shellDir} / common / git - clone.sh "${taskProps["git.private.key"]}" "undefined" "${JSON.stringify(taskProps["stage / build.before_clone.git.repo.url"])}" "${taskProps["stage / build.before_clone.git.commit.id"]}" "${taskProps["stage / build.before_clone.git.lfs"]}"`);
      }

      log.ci("Retrieving Source Code");
      await exec(`${shellDir} / common / git - clone.sh "${taskProps["git.private.key"]}" "${JSON.stringify(taskProps["component / repoSshUrl"])}" "${JSON.stringify(taskProps["component / repoUrl"])}" "${taskProps["git.commit.id"]}" "${taskProps["git.lfs"]}"`);

      shell.cd("/data/workspace");
      log.ci("Compile & Package Artifact(s)");
      if (taskProps["system.mode"] === SystemMode.Jar) {
        await exec(
          `${shellDir} / build / compile - package - jar.sh "${taskProps["build.tool"]}" "${taskProps["build.tool.version"]}" "${taskProps["version.name"].substr(0, taskProps["version.name"].lastIndexOf(" - "))}" "${JSON.stringify(taskProps["global / maven.repo.url"])}" "${
            taskProps["global / maven.repo.id"]
          }" "${taskProps["global/artifactory.user"]} " "${taskProps["global/artifactory.password"]} " "${taskProps["global/artifactory.url"]} "`
        );
      } else if (taskProps["system.mode"] === SystemMode.NPM) {
        await exec(`${shellDir}/build/compile-package-npm.sh "${taskProps["build.tool"]}"`);
      } else if (taskProps["system.mode"] === SystemMode.Java) {
        await exec(
          `${shellDir}/build/compile-java.sh "${taskProps["build.tool"]}" "${taskProps["build.tool.version"]}" "${taskProps["version.name"]}" "${JSON.stringify(taskProps["global/maven.repo.url"])}" "${taskProps["global/maven.repo.id"]}" "${taskProps["global/artifactory.user"]}" "${
            taskProps["global/artifactory.password"]
          }"`
        );
      } else if (taskProps["system.mode"] === SystemMode.Nodejs) {
        await exec(`${shellDir}/build/compile-node.sh "${taskProps["build.tool"]}" "${taskProps["node.package.script"]}" "${taskProps["node.cypress.install.binary"]}"`);
      } else if (taskProps["system.mode"] === "python") {
        await exec(`${shellDir}/build/compile-python.sh "${taskProps["language.version"]}" "${JSON.stringify(taskProps["global/pypi.registry.host"])}" "${taskProps["global/pypi.repo.id"]}" "${taskProps["global/pypi.repo.user"]}" "${taskProps["global/pypi.repo.password"]}"`);
      } else if (taskProps["system.mode"] === SystemMode.Wheel) {
        await exec(
          `${shellDir}/build/compile-package-python-wheel.sh "${taskProps["language.version"]}" "${taskProps["version.name"].substr(0, taskProps["version.name"].lastIndexOf("-"))}" "${JSON.stringify(taskProps["global/pypi.repo.url"])}" "${taskProps["global/pypi.repo.id"]}" "${
            taskProps["global/pypi.repo.user"]
          }" "${taskProps["global/pypi.repo.password"]}"`
        );
      } else if (taskProps["system.mode"] === SystemMode.Helm) {
        await exec(
          `${shellDir}/build/package-helm.sh "${taskProps["build.tool"]}" "${taskProps["version.name"]}" "${taskProps["helm.repo.url"]}" "${taskProps["helm.chart.directory"]}" "${taskProps["helm.chart.ignore"]}" "${taskProps["helm.chart.version.increment"]}" "${taskProps["helm.chart.version.tag"]}" "${taskProps["git.ref"]}"`
        );
        await exec(
          `${shellDir}/build/validate-sync-helm.sh "${taskProps["build.tool"]}" "${taskProps["helm.repo.type"]}" "${taskProps["helm.repo.url"]}" "${taskProps["helm.repo.user"]}" "${taskProps["helm.repo.password"]}" "${taskProps["component/repoOwner"]}" "${taskProps["component/repoName"]}" "${taskProps["git.commit.id"]}" "${taskProps["helm.repo.index.branch"]}"`
        );
      }
      if (taskProps["system.mode"] === SystemMode.Docker || taskProps["docker.enable"]) {
        var dockerFile = taskProps["docker.file"] !== undefined && taskProps["docker.file"] !== null ? taskProps["docker.file"] : "";
        var dockerImageName =
          taskProps["docker.image.name"] !== undefined
            ? taskProps["docker.image.name"]
            : taskProps["system.component.name"]
                .toString()
                .replace(/[^a-zA-Z0-9\-]/g, "")
                .toLowerCase();
        var dockerImagePath =
          taskProps["docker.image.path"] !== undefined
            ? taskProps["docker.image.path"]
                .toString()
                .replace(/[^a-zA-Z0-9\-]/g, "")
                .toLowerCase()
            : taskProps["team.name"]
                .toString()
                .replace(/[^a-zA-Z0-9\-]/g, "")
                .toLowerCase();
        await exec(
          `${shellDir}/build/package-docker.sh "${dockerImageName}" "${taskProps["version.name"]}" "${dockerImagePath}" "${JSON.stringify(taskProps["global/container.registry.host"])}" "${taskProps["global/container.registry.port"]}" "${taskProps["global/container.registry.user"]}" "${
            taskProps["global/container.registry.password"]
          }" "${JSON.stringify(taskProps["global/artifactory.url"])}" "${taskProps["global/artifactory.user"]}" "${taskProps["global/artifactory.password"]}" "${JSON.stringify(taskProps["build.container.registry.host"])}" "${taskProps["build.container.registry.port"]}" "${
            taskProps["build.container.registry.user"]
          }" "${taskProps["build.container.registry.password"]}" "${dockerFile}"`
        );
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished CICD Build Activity");
    }
  }
};
