const { log, utils, CICDError } = require("@boomerang-io/worker-core");
// const shell = require("shelljs");
const util = require("util");
const exec = util.promisify(require("child_process").exec);
async function execuateShell(command) {
  log.debug("Command to execute:", command);
  const { stdout, stderr } = await exec(command);
  log.debug("stdout:", stdout);
  log.debug("stderr:", stderr);
}

// function exec(command) {
//   return new Promise(function(resolve, reject) {
//     log.debug("Command directory:", shell.pwd().toString());
//     log.debug("Command to execute:", command);
//     shell.exec(command, config, function(code, stdout, stderr) {
//       if (code) {
//         reject(new CICDError(code, stderr));
//       }
//       resolve(stdout ? stdout : stderr);
//     });
//   });
// }

function parseVersion(version, appendBuildNumber) {
  var parsedVersion = version;
  // Trim build number
  if (appendBuildNumber === false) {
    log.sys("Stripping build number from version...");
    parsedVersion = version.substr(0, version.lastIndexOf("-"));
  }
  log.debug("  Version:", parsedVersion);
  return parsedVersion;
}

function workingDir(workingDir, subWorkingDir) {
  log.ci("Working Directory: " + workingDir);
  log.ci("Sub Working Directory: " + subWorkingDir);
  let dir;
  if (!workingDir || workingDir === '""') {
    dir = "/data/repository";
    log.ci("No working directory specified. Defaulting to " + dir);
  } else {
    dir = workingDir + "/repository";
  }
  log.ci("Navigate to Working Directory: " + dir);
  exec("cd " + dir);
  // shell.cd(dir);

  if (subWorkingDir && subWorkingDir != '""') {
    log.ci("Navigate to Sub Working Directory: " + subWorkingDir);
    exec("cd " + subWorkingDir);
    // shell.cd(subWorkingDir);
  }
}

module.exports = {
  async java() {
    log.debug("Starting Boomerang CICD Java build activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };
    let maxBufferSizeInMB = taskParams["maxBuffer"];
    if (maxBufferSizeInMB && maxBufferSizeInMB != '""') {
      log.debug("Using customized maxBuffer in MB: " + maxBufferSizeInMB);
      config.maxBuffer = Number(maxBufferSizeInMB) * 1024 * 1024;
    }

    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await execuateShell(`${shellDir}/common/initialize.sh`);
      // await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);
      // await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh \
      // ${taskParams["buildTool"]} \
      // ${taskParams["buildToolVersion"]}`);

      log.ci("Compile & Package Artifact(s)");
      // navigate to target working directory
      workingDir(taskParams["workingDir"], taskParams["subWorkingDir"]);
      await execuateShell(
        `${shellDir}/build/compile-java.sh \
      "${taskParams["languageVersion"]}" \
      ${taskParams["buildTool"]} \
      ${taskParams["buildToolVersion"]} \
      ${version} \
      ${JSON.stringify(taskParams["repoUrl"])} \
      ${taskParams["repoId"]} \
      ${taskParams["repoUser"]} \
      "${taskParams["repoPassword"]}"`
      );
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await execuateShell(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Java build activity");
    }
  },
  async jar() {
    log.debug("Starting Boomerang CICD Java Archive build activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    const version = parseVersion(taskParams["version"], false);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      // await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);
      await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]}`);

      log.ci("Compile & Package Artifact(s)");
      // navigate to target working directory
      workingDir(taskParams["workingDir"], taskParams["subWorkingDir"]);
      await exec(`${shellDir}/build/compile-package-jar.sh \
      "${taskParams["languageVersion"]}" \
      ${taskParams["buildTool"]} \
      ${taskParams["buildToolVersion"]} \
      ${version} \
      ${JSON.stringify(taskParams["repoUrl"])} \
      ${taskParams["repoId"]} \
      ${taskParams["repoUser"]} \
      "${taskParams["repoPassword"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Java Archive build activity");
    }
  },
  async container() {
    log.debug("Starting Boomerang CICD Container build activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);

      log.ci("Compile & Package Artifact(s)");
      // navigate to target working directory
      workingDir(taskParams["workingDir"], taskParams["subWorkingDir"]);
      await exec("ls -ltr");
      var dockerFile = taskParams["dockerfile"] !== undefined && taskParams["dockerfile"] !== null ? taskParams["dockerfile"] : "";
      var dockerImageName =
        taskParams["imageName"] !== undefined && taskParams["imageName"] !== '""'
          ? taskParams["imageName"]
          : taskParams["componentName"]
              .toString()
              .replace(/[^a-zA-Z0-9\-]/g, "")
              .toLowerCase();
      var dockerImagePath =
        taskParams["imagePath"] !== undefined && taskParams["imagePath"] !== '""'
          ? taskParams["imagePath"]
              .toString()
              .replace(/[^a-zA-Z0-9\-]/g, "")
              .toLowerCase()
          : taskParams["teamName"]
              .toString()
              .replace(/[^a-zA-Z0-9\-]/g, "")
              .toLowerCase();
      await exec(
        `${shellDir}/build/package-container.sh \
        "${dockerImageName}" \
        "${version}" \
        "${dockerImagePath}" \
        "${taskParams["buildArgs"]}" \
        "${dockerFile}" ${JSON.stringify(taskParams["globalContainerRegistryHost"])} \
        "${taskParams["globalContainerRegistryPort"]}" \
        "${taskParams["globalContainerRegistryUser"]}" \
        "${taskParams["globalContainerRegistryPassword"]}" ${JSON.stringify(taskParams["containerRegistryHost"])} \
        "${taskParams["containerRegistryPort"]}" \
        "${taskParams["containerRegistryUser"]}" \
        "${taskParams["containerRegistryPassword"]}"`
      );
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(`${shellDir}/common/footer.sh`);
      log.debug("Finished Boomerang CICD Container build activity");
    }
  },
  async nodejs() {
    log.debug("Starting Boomerang CICD Node.js build activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    log.debug({ taskParams });
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-node.sh \
      "${taskParams["languageVersion"]}" \
      "${taskParams["buildTool"]}" \
      ${JSON.stringify(taskParams["repoUrl"])} \
      ${taskParams["repoUser"]} \
      "${taskParams["repoPassword"]}" \
      "${taskParams["featureNodeCache"]}"`);

      log.ci("Compile & Package Artifact(s)");
      // navigate to target working directory
      workingDir(taskParams["workingDir"], taskParams["subWorkingDir"]);
      await exec(`${shellDir}/build/initialize-dependencies-node.sh \
      "${taskParams["languageVersion"]}" \
      "${taskParams["buildTool"]}" \
      "${taskParams["carbonTelemetryDisabled"]}"`);

      await exec(`${shellDir}/build/compile-node.sh \
      "${taskParams["languageVersion"]}" \
      "${taskParams["buildScript"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Node.js build activity");
    }
  },
  async npm() {
    log.debug("Starting Boomerang CICD NPM package activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    log.debug({ taskParams });
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-node.sh \
      "${taskParams["languageVersion"]}" \
      "${taskParams["buildTool"]}" ${JSON.stringify(taskParams["repoUrl"])} ${taskParams["repoUser"]} \
      "${taskParams["repoPassword"]}" \
      "${taskParams["featureNodeCache"]}"`);

      log.ci("Compile & Package Artifact(s)");
      // navigate to target working directory
      workingDir(taskParams["workingDir"], taskParams["subWorkingDir"]);
      await exec(`${shellDir}/build/initialize-dependencies-node.sh \
      "${taskParams["languageVersion"]}" \
      "${taskParams["buildTool"]}" \
      "${taskParams["carbonTelemetryDisabled"]}"`);

      await exec(`${shellDir}/build/compile-package-npm.sh \
      "${taskParams["languageVersion"]}" \
      ${JSON.stringify(taskParams["artifactoryUrl"])} \
      ${taskParams["artifactoryUser"]} \
      ${taskParams["artifactoryPassword"]}`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD NPM package activity");
    }
  },
  async python() {
    log.debug("Starting Boomerang CICD Python build activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-python.sh "${taskParams["languageVersion"]}"`);

      log.ci("Compile & Package Artifact(s)");
      // navigate to target working directory
      workingDir(taskParams["workingDir"], taskParams["subWorkingDir"]);
      await exec(`${shellDir}/build/compile-python.sh \
      "${taskParams["languageVersion"]}" \
      "${JSON.stringify(taskParams["repoUrl"])}" \
      "${taskParams["repoId"]}" \
      "${taskParams["repoUser"]}" \
      "${taskParams["repoPassword"]}" \
      "${taskParams["requirementsFileName"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Python build activity");
    }
  },
  async wheel() {
    log.debug("Starting Boomerang CICD Python Wheel package activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    const version = parseVersion(taskParams["version"], false);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-python.sh "${taskParams["languageVersion"]}"`);

      log.ci("Compile & Package Artifact(s)");
      // navigate to target working directory
      workingDir(taskParams["workingDir"], taskParams["subWorkingDir"]);
      await exec(`${shellDir}/build/compile-package-python-wheel.sh \
      "${taskParams["languageVersion"]}" \
      "${version}" \
      "${JSON.stringify(taskParams["repoUrl"])}" \
      "${taskParams["repoId"]}" \
      "${taskParams["repoUser"]}" \
      "${taskParams["repoPassword"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Python Wheel package activity");
    }
  },
  async helm() {
    log.debug("Starting Boomerang CICD Helm package activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-helm.sh \
      "${taskParams["buildToolVersion"]}"`);

      log.ci("Compile & Package Artifact(s)");
      // navigate to target working directory
      workingDir(taskParams["workingDir"], taskParams["subWorkingDir"]);
      await exec(`${shellDir}/build/package-helm.sh \
      "${taskParams["repoUrl"]}" \
      "${taskParams["chartDirectory"]}" \
      "${taskParams["chartIgnore"]}" \
      "${taskParams["chartVersionIncrement"]}" \
      "${taskParams["chartVersionTag"]}" \
      "${taskParams["gitRef"]}"`);

      await exec(
        `${shellDir}/build/validate-sync-helm.sh \
        "${taskParams["repoType"]}" \
        "${taskParams["repoUrl"]}" \
        "${taskParams["repoUser"]}" \
        "${taskParams["repoPassword"]}" \
        "${taskParams["gitRepoOwner"]}" \
        "${taskParams["gitRepoName"]}" \
        "${taskParams["gitCommitId"]}" \
        "${taskParams["repoIndexBranch"]}"`
      );
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Helm package activity");
    }
  }
};
