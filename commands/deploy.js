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
  async kubernetes() {
    log.debug("Starting Boomerang CICD Kubernetes deploy activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/deploy/initialize-dependencies-kube.sh "${taskParams["kubeVersion"]}" "${taskParams["kubeNamespace"]}" "${taskParams["kubeHost"]}" "${taskParams["kubeIP"]}" "${taskParams["kubeToken"]}"`);

      log.ci("Deploying...");
      var kubeFiles = taskParams["kubeFiles"];
      log.sys("Kubernetes files: ", kubeFiles);
      await exec(`${shellDir}/deploy/kubernetes.sh "${kubeFiles}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
    }
    log.debug("Finished Boomerang CICD Kubernetes deploy activity...");
  },
  async helm() {
    log.debug("Starting Boomerang CICD Helm deploy activity...");

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
      await exec(`${shellDir}/deploy/initialize-dependencies-kube.sh "${taskParams["kubeVersion"]}" "${taskParams["kubeNamespace"]}" "${taskParams["kubeHost"]}" "${taskParams["kubeIP"]}" "${taskParams["kubeToken"]}"`);
      await exec(`${shellDir}/common/initialize-dependencies-helm.sh "${taskParams["helmVersion"]}"`);

      log.ci("Deploying../");
      await exec(`${shellDir}/deploy/helm.sh "${taskParams["repoUrl"]}" "${taskParams["helmChart"]}" "${taskParams["helmRelease"]}" "${taskParams["helmImageTag"]}" "${version}" "${taskParams["kubeVersion"]}" "${taskParams["kubeNamespace"]}" "${taskParams["kubeHost"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
    }
    log.debug("Finished Boomerang CICD Helm deploy activity...");
  },
  async helmUpgrade() {
    log.debug("Starting Boomerang CICD Helm deploy activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);
    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/deploy/initialize-dependencies-kube.sh "${taskParams["kubeVersion"]}" "${taskParams["kubeNamespace"]}" \
      "${taskParams["kubeHost"]}" "${taskParams["kubeIP"]}" "${taskParams["kubeToken"]}"`);
      await exec(`${shellDir}/common/initialize-dependencies-helm.sh "${taskParams["helmVersion"]}"`);

      log.ci("Deploying...");
      await exec(`${shellDir}/deploy/helm-upgrade.sh --kube-host "${taskParams["kubeHost"]}" \
      --kube-namespace "${taskParams["kubeNamespace"]}" --kube-version "${taskParams["kubeVersion"]}" \
      --release-name "${taskParams["releaseName"]}" --chart-repo-url "${taskParams["chartRepoUrl"]}" \
      --chart-repo-name "${taskParams["chartRepoName"]}" --chart-name "${taskParams["chartName"]}" \
      --chart-version "${taskParams["chartVersion"]}" --helm-set-args "${taskParams["helmSetArgs"]}" \
      --git-values-file "${taskParams["gitValuesFile"]}" --git-values-custom-dir "${taskParams["gitValuesCustomDir"]}" \
      --working-dir "${taskParams["workingDir"]}" --rollback-release "${taskParams["rollbackRelease"]}" \
      --debug "${taskParams["debug"]}"`);
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
    }
    log.debug("Finished Boomerang CICD Helm deploy activity...");
  },
  async containerRegistry() {
    log.debug("Starting Boomerang CICD Container Registry deploy activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);

    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    log.ci("Deploying...");
    try {
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
        `${shellDir}/deploy/containerregistry.sh "${dockerImageName}" "${version}" "${dockerImagePath}" ${JSON.stringify(taskParams["containerRegistryHost"])} "${taskParams["containerRegistryPort"]}" "${taskParams["containerRegistryUser"]}" "${taskParams["containerRegistryPassword"]}" "${taskParams["containerRegistryPath"]
        }" ${JSON.stringify(taskParams["globalContainerRegistryHost"])} "${taskParams["globalContainerRegistryPort"]}" "${taskParams["globalContainerRegistryUser"]}" "${taskParams["globalContainerRegistryPassword"]}"`
      );
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
    }
    log.debug("Finished Boomerang CICD Container Registry deploy activity...");
  },
  async container() {
    log.debug("Starting Boomerang CICD Container Registry deploy activity...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    log.ci("Deploying...");
    let dir = workingDir(taskParams["workingDir"]);
    log.debug("Working Directory: ", dir);
    shell.cd(dir + "/repository");
    await exec("ls -ltr");
    try {
      await exec(
        `${shellDir}/deploy/containerregistry-tar.sh "${taskParams["imageName"]}" "${taskParams["version"]}" "${taskParams["imagePath"]}" ${JSON.stringify(taskParams["globalContainerRegistryHost"])} "${taskParams["globalContainerRegistryPort"]}" "${taskParams["globalContainerRegistryUser"]
        }" "${taskParams["globalContainerRegistryPassword"]}" ${JSON.stringify(taskParams["containerRegistryHost"])} "${taskParams["containerRegistryPort"]}" "${taskParams["containerRegistryUser"]}" "${taskParams["containerRegistryPassword"]}"`
      );
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
    }
    log.debug("Finished Boomerang CICD Container Registry deploy activity...");
  }
  // async helmChart() {
  //   log.debug("Starting Boomerang CICD Helm deploy activity...");

  //   //Destructure and get properties ready.
  //   const taskParams = utils.resolveInputParameters();
  //   // const { path, script } = taskParams;
  //   const shellDir = "/cli/scripts";
  //   config = {
  //     verbose: true
  //   };

  //   let dir = "/workspace/" + taskParams["workflow-activity-id"];
  //   log.debug("Working Directory: ", dir);

  //   const version = parseVersion(taskParams["version"], false);

  //   log.ci("Initializing Dependencies");
  //   await exec(`${shellDir}/deploy/initialize-dependencies-kube.sh "${taskParams["kubeVersion"]}" "${taskParams["kubeNamespace"]}" "${taskParams["kubeHost"]}" "${taskParams["kubeIP"]}" "${taskParams["kubeToken"]}"`);
  //   await exec(`${shellDir}/common/initialize-dependencies-helm.sh "${taskParams["helmVersion"]}"`);

  //   // TODO: determine how to accommodate deploying the helm chart to an environment
  //   await exec(`${shellDir}/deploy/helm-chart.sh "${JSON.stringify(taskParams["global/helm.repo.url"])} "${taskParams["deploy.helm.chart"]}" "${taskParams["deploy.helm.release"]}" "${version}" "${taskParams["deploy.kube.version"]}" "${taskParams["deploy.kube.namespace"]}" "${taskParams["deploy.kube.host"]}" "${taskParams["git.ref"]}"`);

  //   log.debug("Finished Boomerang CICD Helm deploy activity...");
  // }
};
