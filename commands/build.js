const { log, utils, CICDError } = require("@boomerang-io/worker-core");
const shell = require("shelljs");

function exec(command) {
  return new Promise(function (resolve, reject) {
    log.debug("Command directory:", shell.pwd().toString());
    log.debug("Command to execute:", command);
    shell.exec(command, config, function (code, stdout, stderr) {
      if (code) {
        reject(new CICDError(code, stderr));
      }
      resolve(stdout ? stdout : stderr);
    });
  });
}

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

function workingDir(workingDir) {
  let dir;
  if (!workingDir || workingDir === '""') {
    dir = "/data";
    log.debug("No working directory specified. Defaulting...");
  } else {
    dir = workingDir;
  }
  log.debug("Working Directory: ", dir);
  return dir;
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

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    log.debug("Working Directory: ", dir);

    // ----------------
    // shell.config.silent = true; //set to silent otherwise CD will print out no such file or directory if the directory doesn't exist
    // shell.cd(dir);
    // //shell.cd -> does not have an error handling call back and will default to current directory of /cli
    // if (shell.pwd().toString() !== dir.toString()) {
    //   log.err("No such file or directory:", dir);
    //   return process.exit(1);
    // }
    // shell.config.silent = false;
    // ----------------

    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);
      await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]}`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec(`${shellDir}/build/compile-java.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]} ${version} ${JSON.stringify(taskParams["repoUrl"])} ${taskParams["repoId"]} ${taskParams["repoUser"]} "${taskParams["repoPassword"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
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

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    log.debug("Working Directory: ", dir);

    const version = parseVersion(taskParams["version"], false);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);
      await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]}`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec(`${shellDir}/build/compile-package-jar.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]} ${version} ${JSON.stringify(taskParams["repoUrl"])} ${taskParams["repoId"]} ${taskParams["repoUser"]} "${taskParams["repoPassword"]}"`);
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

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    log.debug("Working Directory: ", dir);

    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec("ls -ltr");
      var dockerFile = taskParams["dockerFile"] !== undefined && taskParams["dockerFile"] !== null ? taskParams["dockerFile"] : "";
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
        `${shellDir}/build/package-container.sh "${dockerImageName}" "${version}" "${dockerImagePath}" "${taskParams["buildArgs"]}" "${dockerFile}" ${JSON.stringify(taskParams["globalContainerRegistryHost"])} "${taskParams["globalContainerRegistryPort"]}" "${taskParams["globalContainerRegistryUser"]
        }" "${taskParams["globalContainerRegistryPassword"]}" ${JSON.stringify(taskParams["containerRegistryHost"])} "${taskParams["containerRegistryPort"]}" "${taskParams["containerRegistryUser"]}" "${taskParams["containerRegistryPassword"]}"`
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
    log.debug("Starting Boomerang CICD NodeJS build activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    log.debug("Working Directory: ", dir);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-node.sh "${taskParams["buildTool"]}" ${JSON.stringify(taskParams["repoUrl"])} ${taskParams["repoUser"]} "${taskParams["repoPassword"]}"`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec(`${shellDir}/build/compile-node.sh "${taskParams["buildTool"]}" "${taskParams["packageScript"]}" "${taskParams["node-cypress-install-binary"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD NodeJS build activity");
    }
  },
  async npm() {
    log.debug("Starting Boomerang CICD NPM package activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    log.debug("Working Directory: ", dir);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec(`${shellDir}/build/compile-package-npm.sh "${taskParams["buildTool"]}"`);
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

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    log.debug("Working Directory: ", dir);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-python.sh "${taskParams["languageVersion"]}"`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec(`${shellDir}/build/compile-python.sh "${taskParams["languageVersion"]}" "${JSON.stringify(taskParams["repoUrl"])}" "${taskParams["repoId"]}" "${taskParams["repoUser"]}" "${taskParams["repoPassword"]}"`);
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

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    log.debug("Working Directory: ", dir);

    const version = parseVersion(taskParams["version"], false);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-python.sh "${taskParams["languageVersion"]}"`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec(`${shellDir}/build/compile-package-python-wheel.sh "${taskParams["languageVersion"]}" "${version}" "${JSON.stringify(taskParams["repoUrl"])}" "${taskParams["repoId"]}" "${taskParams["repoUser"]}" "${taskParams["repoPassword"]}"`);
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

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    log.debug("Working Directory: ", dir);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-helm.sh "${taskParams["buildToolVersion"]}"`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      // await exec(`${shellDir}/build/package-helm.sh "${taskParams["build.tool"]}" "${taskParams["version.name"]}" "${taskParams["helm.repo.url"]}" "${taskParams["helm.chart.directory"]}" "${taskParams["helm.chart.ignore"]}" "${taskParams["helm.chart.version.increment"]}" "${taskParams["helm.chart.version.tag"]}" "${taskParams["git.ref"]}"`);
      // await exec(`${shellDir}/build/validate-sync-helm.sh "${taskParams["build.tool"]}" "${taskParams["helm.repo.type"]}" "${taskParams["helm.repo.url"]}" "${taskParams["helm.repo.user"]}" "${taskParams["helm.repo.password"]}" "${taskParams["component/repoOwner"]}" "${taskParams["component/repoName"]}" "${taskParams["git.commit.id"]}" "${taskParams["helm.repo.index.branch"]}"`);
      await exec(`${shellDir}/build/package-helm.sh "${taskParams["repoUrl"]}" "${taskParams["chartDirectory"]}" "${taskParams["chartIgnore"]}" "${taskParams["chartVersionIncrement"]}" "${taskParams["chartVersionTag"]}" "${taskParams["gitRef"]}"`);
      await exec(
        `${shellDir}/build/validate-sync-helm.sh "${taskParams["repoType"]}" "${taskParams["repoUrl"]}" "${taskParams["repoUser"]}" "${taskParams["repoPassword"]}" "${taskParams["gitRepoOwner"]}" "${taskParams["gitRepoName"]}" "${taskParams["gitCommitId"]}" "${taskParams["repoIndexBranch"]}"`
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
