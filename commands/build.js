const { log, utils, CICDError } = require("@boomerang-io/worker-core");
const shell = require("shelljs");

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
  var parsedVersion = version;
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
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);
    // To implement when we have custom working directories as part of advanced task configuration
    // ----------------
    // let dir;
    // if (!workingDir || workingDir === '""') {
    //   dir = "/data";
    //   log.debug("No directory specified. Defaulting...");
    // } else {
    //   dir = workingDir;
    // }
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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
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
        taskParams["imageName"] !== undefined && taskParams["imagePath"] !== '""'
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
        `${shellDir}/build/package-container.sh "${dockerImageName}" "${version}" "${dockerImagePath}" "${taskParams["buildArgs"]}" "${dockerFile}" ${JSON.stringify(taskParams["globalContainerRegistryHost"])} "${taskParams["globalContainerRegistryPort"]}" "${
          taskParams["globalContainerRegistryUser"]
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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-node.sh "${taskParams["buildTool"]}" ${JSON.stringify(taskParams["repoUrl"])} ${taskParams["repoId"]} ${taskParams["repoUser"]} "${taskParams["repoPassword"]}"`);

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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec(`${shellDir}/build/compile-package-npm.sh "${taskProps["buildTool"]}"`);
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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-python.sh "${taskProps["languageVersion"]}"`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec(`${shellDir}/build/compile-python.sh "${taskProps["languageVersion"]}" "${JSON.stringify(taskProps["repoUrl"])}" "${taskProps["repoId"]}" "${taskProps["repoUser"]}" "${taskProps["repoPassword"]}"`);
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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    const version = parseVersion(taskParams["version"], false);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-python.sh "${taskProps["languageVersion"]}"`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      await exec(`${shellDir}/build/compile-package-python-wheel.sh "${taskProps["languageVersion"]}" "${version}" "${JSON.stringify(taskProps["repoUrl"])}" "${taskProps["repoId"]}" "${taskProps["repoUser"]}" "${taskProps["repoPassword"]}"`);
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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-helm.sh "${taskProps["buildToolVersion"]}"`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      // await exec(`${shellDir}/build/package-helm.sh "${taskProps["build.tool"]}" "${taskProps["version.name"]}" "${taskProps["helm.repo.url"]}" "${taskProps["helm.chart.directory"]}" "${taskProps["helm.chart.ignore"]}" "${taskProps["helm.chart.version.increment"]}" "${taskProps["helm.chart.version.tag"]}" "${taskProps["git.ref"]}"`);
      // await exec(`${shellDir}/build/validate-sync-helm.sh "${taskProps["build.tool"]}" "${taskProps["helm.repo.type"]}" "${taskProps["helm.repo.url"]}" "${taskProps["helm.repo.user"]}" "${taskProps["helm.repo.password"]}" "${taskProps["component/repoOwner"]}" "${taskProps["component/repoName"]}" "${taskProps["git.commit.id"]}" "${taskProps["helm.repo.index.branch"]}"`);
      await exec(`${shellDir}/build/package-helm.sh "${taskProps["repoUrl"]}" "${taskProps["chartDirectory"]}" "${taskProps["chartIgnore"]}" "${taskProps["chartVersionIncrement"]}" "${taskProps["chartVersionTag"]}" "${taskProps["gitRef"]}"`);
      await exec(`${shellDir}/build/validate-sync-helm.sh "${taskProps["repoType"]}" "${taskProps["repoUrl"]}" "${taskProps["repoUser"]}" "${taskProps["repoPassword"]}" "${taskProps["gitRepoOwner"]}" "${taskProps["gitRepoName"]}" "${taskProps["gitCommitId"]}" "${taskProps["repoIndexBranch"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Helm package activity");
    }
  }
};
