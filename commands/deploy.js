const { log, utils, CICDError, common } = require("@boomerang-io/worker-core");
const shell = require("shelljs");

// const DeployTypes = {
//   Kubernetes: "kubernetes",
//   Helm: "helm",
//   Helm3: "helm3",
//   ContainerRegistry: "containerRegistry"
// };

// const ComponentMode = {
//   Nodejs: "nodejs",
//   Python: "python",
//   Java: "java",
//   Jar: "lib.jar",
//   Helm: "helm.chart"
// };

// const SystemMode = {
//   Java: "java",
//   Wheel: "lib.wheel",
//   Jar: "lib.jar",
//   NPM: "lib.npm",
//   Nodejs: "nodejs",
//   Python: "python",
//   Helm: "helm.chart",
//   Docker: "docker"
// };

// // Freeze so they can't be modified at runtime
// Object.freeze(DeployTypes);
// Object.freeze(ComponentMode);
// Object.freeze(SystemMode);

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

// TODO: Add to workflow as a pre-condition switch
// if (taskProps["deploy.git.clone"]) {
//   log.ci("Retrieving Source Code");
//   await exec(`${shellDir}/common/git-clone.sh "${taskProps["git.private.key"]}" "${JSON.stringify(taskProps["component/repoSshUrl"])}" "${JSON.stringify(taskProps["component/repoUrl"])}" "${taskProps["git.commit.id"]}" "${taskProps["git.lfs"]}"`);
// }

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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    log.ci("Initializing Dependencies");
    // await exec(`${shellDir}/deploy/initialize-dependencies.sh "${taskProps["deploy.type"]}" "${taskProps["deploy.kube.version"]}" "${taskProps["deploy.kube.namespace"]}" "${taskProps["deploy.kube.host"]}" "${taskProps["deploy.kube.ip"]}" "${taskProps["deploy.kube.token"]}" "${taskProps["deploy.helm.tls"]}"`);
    await exec(`${shellDir}/deploy/initialize-dependencies-kube.sh "${taskProps["kubeVersion"]}" "${taskProps["kubeNamespace"]}" "${taskProps["kubeHost"]}" "${taskProps["kubeIP"]}" "${taskProps["kubeToken"]}"`);

    log.ci("Deploy Artifacts");
    taskProps["process/org"] = taskProps["team.name"]
      .toString()
      .replace(/[^a-zA-Z0-9]/g, "")
      .toLowerCase();
    taskProps["process/component.name"] = taskProps["system.component.name"]
      .toString()
      .replace(/[^a-zA-Z0-9]/g, "")
      .toLowerCase();
    // Needs to follow Kubernetes allowed characters and patterns.
    taskProps["process/env"] = taskProps["system/stage.name"]
      .toString()
      .replace(/[^a-zA-Z0-9\-]/g, "")
      .toLowerCase();
    taskProps["process/container.port"] = taskProps["deploy.kubernetes.container.port"] !== undefined ? taskProps["deploy.kubernetes.container.port"] : "8080";
    taskProps["process/service.port"] = taskProps["deploy.kubernetes.service.port"] !== undefined ? taskProps["deploy.kubernetes.service.port"] : "80";
    taskProps["process/registry.key"] = taskProps["deploy.kubernetes.registry.key"] !== undefined ? taskProps["deploy.kubernetes.registry.key"] : "boomerang.registrykey";
    // The additional checks are required for deploy.container.registry.host/port/path as these properties are also used as STAGE properties which currently
    // are set to "" if they have no value. This will be solved if we move away from default STAGE properties.
    taskProps["process/container.registry.host"] =
      taskProps["deploy.container.registry.host"] !== undefined && taskProps["deploy.container.registry.host"] !== '""' ? taskProps["deploy.container.registry.host"] : taskProps["global/container.registry.host"] + ":" + taskProps["global/container.registry.port"];
    log.sys("Container Registry Host:", taskProps["process/container.registry.host"]);
    if (taskProps["deploy.container.registry.port"] !== undefined && taskProps["deploy.container.registry.port"] !== '""') {
      taskProps["process/container.registry.port"] = ":" + taskProps["deploy.container.registry.port"];
    } else {
      taskProps["process/container.registry.port"] = "";
    }
    log.sys("Container Registry Port:", taskProps["process/container.registry.port"]);
    taskProps["process/container.registry.path"] = taskProps["deploy.container.registry.path"] !== undefined && taskProps["deploy.container.registry.path"] !== '""' ? taskProps["deploy.container.registry.path"] : "/" + taskProps["process/org"];
    log.sys("Container Registry Path:", taskProps["process/container.registry.path"]);
    var dockerImageName = taskProps["docker.image.name"] !== undefined ? taskProps["docker.image.name"] : taskProps["system.component.name"];
    // Name specification reference: https://docs.docker.com/engine/reference/commandline/tag/
    taskProps["process/docker.image.name"] = dockerImageName
      .toString()
      .replace(/[^a-zA-Z0-9\-\_\.]/g, "")
      .toLowerCase();
    var kubePath = shellDir + "/deploy";
    var kubeFile = taskProps["deploy.kubernetes.ingress"] == undefined || taskProps["deploy.kubernetes.ingress"] == false ? "^kube.yaml$" : ".*.yaml$";
    if (taskProps["deploy.kubernetes.file"] !== undefined) {
      kubePath = taskProps["deploy.kubernetes.path"] !== undefined ? "/data/workspace" + taskProps["deploy.kubernetes.path"] : "/data/workspace";
      kubeFile = taskProps["deploy.kubernetes.file"];
    }
    var kubeFiles = await common.replaceTokensInFileWithProps(kubePath, kubeFile, "@", "@", taskProps, "g", "g", true);
    log.sys("Kubernetes files: ", kubeFiles);
    await exec(`${shellDir}/deploy/kubernetes.sh "${kubeFiles}"`);

    log.debug("Finished Boomerang CICD Kubernetes deploy activity...");
  },
  async helm3() {
    log.debug("Starting Boomerang CICD Helm deploy activity...");

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

    log.ci("Initializing Dependencies");
    // await exec(`${shellDir}/deploy/initialize-dependencies.sh "${taskProps["deploy.type"]}" "${taskProps["deploy.kube.version"]}" "${taskProps["deploy.kube.namespace"]}" "${taskProps["deploy.kube.host"]}" "${taskProps["deploy.kube.ip"]}" "${taskProps["deploy.kube.token"]}" "${taskProps["deploy.helm.tls"]}"`);
    await exec(`${shellDir}/deploy/initialize-dependencies-kube.sh "${taskProps["kubeVersion"]}" "${taskProps["kubeNamespace"]}" "${taskProps["kubeHost"]}" "${taskProps["kubeIP"]}" "${taskProps["kubeToken"]}"`);
    await exec(`${shellDir}/common/initialize-dependencies-helm.sh "${taskProps["helmVersion"]}"`);

    log.ci("Deploy Artifacts");
    var helmRepoURL = taskProps["deploy.helm.repo.url"] !== undefined ? taskProps["deploy.helm.repo.url"] : taskProps["global/helm.repo.url"];
    // await exec(`${shellDir}/deploy/helm.sh "${taskProps["deploy.type"]}" "${helmRepoURL}" "${taskProps["deploy.helm.chart"]}" "${taskProps["deploy.helm.release"]}" "${taskProps["helm.image.tag"]}" "${taskProps["version.name"]}" "${taskProps["deploy.kube.version"]}" "${taskProps["deploy.kube.namespace"]}" "${taskProps["deploy.kube.host"]}" "${taskProps["deploy.helm.tls"]}" "${taskProps["global/helm.repo.url"]}"`);
    await exec(`${shellDir}/deploy/helm.sh "${helmRepoURL}" "${taskProps["helmChart"]}" "${taskProps["helmRelease"]}" "${taskProps["helmImage.tag"]}" "${version}" "${taskProps["kubeVersion"]}" "${taskProps["kubeNamespace"]}" "${taskProps["kubeHost"]}" "${taskProps["helmRepoUrl"]}"`);

    // TODO: determine how to accommodate deploying the helm chart to an environment
    // await exec(`${shellDir}/deploy/helm-chart.sh "${JSON.stringify(taskProps["global/helm.repo.url"])} "${taskProps["deploy.helm.chart"]}" "${taskProps["deploy.helm.release"]}" "${version}" "${taskProps["deploy.kube.version"]}" "${taskProps["deploy.kube.namespace"]}" "${taskProps["deploy.kube.host"]}" "${taskProps["git.ref"]}"`);

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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    log.ci("Deploy Artifacts");
    try {
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
        `${shellDir}/deploy/containerregistry.sh "${dockerImageName}" "${taskProps["version.name"]}" "${dockerImagePath}" "${JSON.stringify(taskProps["deploy.container.registry.host"])}" "${taskProps["deploy.container.registry.port"]}" "${taskProps["deploy.container.registry.user"]}" "${
          taskProps["deploy.container.registry.password"]
        }" "${taskProps["deploy.container.registry.path"]}" "${JSON.stringify(taskProps["global/container.registry.host"])}" "${taskProps["global/container.registry.port"]}" "${taskProps["global/container.registry.user"]}" "${taskProps["global/container.registry.password"]}"`
      );
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Helm package activity");
    }
    log.debug("Finished Boomerang CICD Container Registry deploy activity...");
  }
};
