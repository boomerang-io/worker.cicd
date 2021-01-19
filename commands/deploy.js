const { log, utils, CICDError, common } = require("@boomerang-io/worker-core");
const shell = require("shelljs");
const properties = require("properties");

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
// if (taskParams["deploy.git.clone"]) {
//   log.ci("Retrieving Source Code");
//   await exec(`${shellDir}/common/git-clone.sh "${taskParams["git.private.key"]}" "${JSON.stringify(taskParams["component/repoSshUrl"])}" "${JSON.stringify(taskParams["component/repoUrl"])}" "${taskParams["git.commit.id"]}" "${taskParams["git.lfs"]}"`);
// }

module.exports = {
  async testAllParams() {
    PARAMS_PATTERN = /\"([\w\ \_\-]*)\=([\w\ \,.]+)\,\"/g;

    const taskParams = utils.resolveInputParameters();
    const allParams = taskParams["allParameters4"];

    log.debug("All Parameters String: " + allParams);
    const obj = JSON.parse(allParams);

    // var allParamsArray = allParams.split('","');

    // var allParamsArray = allParams.substring(1, allParams.length - 1).split('","');

    // log.debug(allParamsArray[0]);

    // allParamsArray.forEach(param => {
    //   log.debug(param);
    // });

    // ------------

    // var splits = allParams.split(",(?=([^\"]*\"[^\"]*\")*[^\"]*$)");
    // splits.forEach(param => {
    //   log.debug(param);
    // });

    // ------------

    // const matchedParams = allParams.match(PARAMS_PATTERN);

    // log.debug(matchedParams);

    // var allParamsObj = {};

    // allParamsArray.array.forEach(element => {
    //   allParamsObj[element[0]] = element[1]
    // });

    // ------------

    // var options = {
    //   comments: "#",
    //   separators: "=",
    //   strict: true,
    //   reviver: function (key, value) {
    //     if (key != null && value == null) {
    //       return '""';
    //     } else {
    //       //Returns all the lines
    //       return this.assert();
    //     }
    //   },
    // };
    // const parsedParams = properties.parse(allParams, options);
    // parsedParams.forEach(param => {
    //   log.debug(param);
    // });

    // ------------

    log.debug(obj["bigString"]);
  },
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
    // await exec(`${shellDir}/deploy/initialize-dependencies.sh "${taskParams["deploy.type"]}" "${taskParams["deploy.kube.version"]}" "${taskParams["deploy.kube.namespace"]}" "${taskParams["deploy.kube.host"]}" "${taskParams["deploy.kube.ip"]}" "${taskParams["deploy.kube.token"]}" "${taskParams["deploy.helm.tls"]}"`);
    await exec(`${shellDir}/deploy/initialize-dependencies-kube.sh "${taskParams["kubeVersion"]}" "${taskParams["kubeNamespace"]}" "${taskParams["kubeHost"]}" "${taskParams["kubeIP"]}" "${taskParams["kubeToken"]}"`);

    log.ci("Deploy Artifacts");
    // taskParams["process/org"] = taskParams["team.name"]
    //   .toString()
    //   .replace(/[^a-zA-Z0-9]/g, "")
    //   .toLowerCase();
    // taskParams["process/component.name"] = taskParams["system.component.name"]
    //   .toString()
    //   .replace(/[^a-zA-Z0-9]/g, "")
    //   .toLowerCase();
    // // Needs to follow Kubernetes allowed characters and patterns.
    // taskParams["process/env"] = taskParams["system/stage.name"]
    //   .toString()
    //   .replace(/[^a-zA-Z0-9\-]/g, "")
    //   .toLowerCase();
    // taskParams["process/container.port"] = taskParams["deploy.kubernetes.container.port"] !== undefined ? taskParams["deploy.kubernetes.container.port"] : "8080";
    // taskParams["process/service.port"] = taskParams["deploy.kubernetes.service.port"] !== undefined ? taskParams["deploy.kubernetes.service.port"] : "80";
    // taskParams["process/registry.key"] = taskParams["deploy.kubernetes.registry.key"] !== undefined ? taskParams["deploy.kubernetes.registry.key"] : "boomerang.registrykey";
    // // The additional checks are required for deploy.container.registry.host/port/path as these properties are also used as STAGE properties which currently
    // // are set to "" if they have no value. This will be solved if we move away from default STAGE properties.
    // taskParams["process/container.registry.host"] =
    //   taskParams["deploy.container.registry.host"] !== undefined && taskParams["deploy.container.registry.host"] !== '""' ? taskParams["deploy.container.registry.host"] : taskParams["global/container.registry.host"] + ":" + taskParams["global/container.registry.port"];
    // log.sys("Container Registry Host:", taskParams["process/container.registry.host"]);
    // if (taskParams["deploy.container.registry.port"] !== undefined && taskParams["deploy.container.registry.port"] !== '""') {
    //   taskParams["process/container.registry.port"] = ":" + taskParams["deploy.container.registry.port"];
    // } else {
    //   taskParams["process/container.registry.port"] = "";
    // }
    // log.sys("Container Registry Port:", taskParams["process/container.registry.port"]);
    // taskParams["process/container.registry.path"] = taskParams["deploy.container.registry.path"] !== undefined && taskParams["deploy.container.registry.path"] !== '""' ? taskParams["deploy.container.registry.path"] : "/" + taskParams["process/org"];
    // log.sys("Container Registry Path:", taskParams["process/container.registry.path"]);
    // var dockerImageName = taskParams["docker.image.name"] !== undefined ? taskParams["docker.image.name"] : taskParams["system.component.name"];
    // // Name specification reference: https://docs.docker.com/engine/reference/commandline/tag/
    // taskParams["process/docker.image.name"] = dockerImageName
    //   .toString()
    //   .replace(/[^a-zA-Z0-9\-\_\.]/g, "")
    //   .toLowerCase();
    // var kubePath = shellDir + "/deploy";
    // var kubeFile = taskParams["deploy.kubernetes.ingress"] == undefined || taskParams["deploy.kubernetes.ingress"] == false ? "^kube.yaml$" : ".*.yaml$";
    // if (taskParams["deploy.kubernetes.file"] !== undefined) {
    //   kubePath = taskParams["deploy.kubernetes.path"] !== undefined ? "/data/workspace" + taskParams["deploy.kubernetes.path"] : "/data/workspace";
    //   kubeFile = taskParams["deploy.kubernetes.file"];
    // }
    // var kubeFiles = await common.replaceTokensInFileWithProps(kubePath, kubeFile, "@", "@", taskParams, "g", "g", true);
    log.sys("Kubernetes files: ", kubeFiles);
    await exec(`${shellDir}/deploy/kubernetes.sh "${kubeFiles}"`);

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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    const version = parseVersion(taskParams["version"], false);

    log.ci("Initializing Dependencies");
    // await exec(`${shellDir}/deploy/initialize-dependencies.sh "${taskParams["deploy.type"]}" "${taskParams["deploy.kube.version"]}" "${taskParams["deploy.kube.namespace"]}" "${taskParams["deploy.kube.host"]}" "${taskParams["deploy.kube.ip"]}" "${taskParams["deploy.kube.token"]}" "${taskParams["deploy.helm.tls"]}"`);
    await exec(`${shellDir}/deploy/initialize-dependencies-kube.sh "${taskParams["kubeVersion"]}" "${taskParams["kubeNamespace"]}" "${taskParams["kubeHost"]}" "${taskParams["kubeIP"]}" "${taskParams["kubeToken"]}"`);
    await exec(`${shellDir}/common/initialize-dependencies-helm.sh "${taskParams["helmVersion"]}"`);

    log.ci("Deploy Artifacts");
    // TODO: teams using ${p:deploy.helm.repo.url} will need to switch to helm-repo-url as a custom property to override the global one.
    // await exec(`${shellDir}/deploy/helm.sh "${taskParams["deploy.type"]}" "${helmRepoURL}" "${taskParams["deploy.helm.chart"]}" "${taskParams["deploy.helm.release"]}" "${taskParams["helm.image.tag"]}" "${taskParams["version.name"]}" "${taskParams["deploy.kube.version"]}" "${taskParams["deploy.kube.namespace"]}" "${taskParams["deploy.kube.host"]}" "${taskParams["deploy.helm.tls"]}" "${taskParams["global/helm.repo.url"]}"`);
    await exec(`${shellDir}/deploy/helm.sh "${taskParams["repoUrl"]}" "${taskParams["helmChart"]}" "${taskParams["helmRelease"]}" "${taskParams["helmImageTag"]}" "${version}" "${taskParams["kubeVersion"]}" "${taskParams["kubeNamespace"]}" "${taskParams["kubeHost"]}"`);

    // TODO: determine how to accommodate deploying the helm chart to an environment
    // await exec(`${shellDir}/deploy/helm-chart.sh "${JSON.stringify(taskParams["global/helm.repo.url"])} "${taskParams["deploy.helm.chart"]}" "${taskParams["deploy.helm.release"]}" "${version}" "${taskParams["deploy.kube.version"]}" "${taskParams["deploy.kube.namespace"]}" "${taskParams["deploy.kube.host"]}" "${taskParams["git.ref"]}"`);

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

    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    log.ci("Deploy Artifacts");
    try {
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
        `${shellDir}/deploy/containerregistry.sh "${dockerImageName}" "${version}" "${dockerImagePath}" ${JSON.stringify(taskParams["containerRegistryHost"])} "${taskParams["containerRegistryPort"]}" "${taskParams["containerRegistryUser"]}" "${taskParams["containerRegistryPassword"]}" "${
          taskParams["containerRegistryPath"]
        }" ${JSON.stringify(taskParams["globalContainerRegistryHost"])} "${taskParams["globalContainerRegistryPort"]}" "${taskParams["globalContainerRegistryUser"]}" "${taskParams["globalContainerRegistryPassword"]}"`
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
