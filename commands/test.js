const { log, utils, CICDError, common } = require("@boomerang-io/worker-core");
const shell = require("shelljs");
const fs = require("fs");

const TestType = {
  Unit: "unit",
  Static: "static",
  Security: "security",
  SeleniumNative: "seleniumNative",
  SeleniumCustom: "seleniumCustom",
  Library: "library"
};

Object.freeze(TestType);

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
  log.debug("Version:", parsedVersion);
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
    log.debug("Started Boomerang CICD Java Test Activity");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);

    let workdir = dir + "/repository";
    log.debug("Working Directory: ", workdir);

    let testdir = "/test";
    shell.mkdir("-p", testdir);
    log.debug("Test Directory: ", testdir);

    let buildTool = taskParams["buildTool"];
    log.debug("Build Tool: ", buildTool);

    // log.debug("Copy source code from shared drive to container");
    // shell.mkdir("-p", workdir);
    // shell.cp("-R", dir + "/repository/*", testdir);

    const testTypes = typeof taskParams["testType"] === "string" ? taskParams["testType"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);      
      await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]}`);

      if (buildTool === "maven") {
        log.debug("Checking Maven Configuration");
        if (!common.checkFileContainsStringWithProps(workdir + "/pom.xml", "<plugins>", undefined, false)) {
          log.debug("No Maven plugins found, adding ...");
          const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-plugins.xml`, "utf-8");
          common.replaceStringInFileWithProps(workdir + "/pom.xml", "<plugins>", replacementString, undefined, false);
        }
        if (!common.checkFileContainsStringWithProps(workdir + "/pom.xml", "<artifactId>jacoco-maven-plugin</artifactId>", undefined, false)) {
          log.debug("Adding jacoco-maven-plugin ...");
          const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-jacoco.xml`, "utf-8");
          common.replaceStringInFileWithProps(workdir + "/pom.xml", "<plugins>", replacementString, undefined, false);
        }
        if (!common.checkFileContainsStringWithProps(workdir + "/pom.xml", "<artifactId>sonar-maven-plugin</artifactId>", undefined, false)) {
          log.debug("Adding sonar-maven-plugin ...");
          const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-sonar.xml`, "utf-8");
          common.replaceStringInFileWithProps(workdir + "/pom.xml", "<plugins>", replacementString, undefined, false);
        }
        if (!common.checkFileContainsStringWithProps(workdir + "/pom.xml", "<artifactId>maven-surefire-report-plugin</artifactId>", undefined, false)) {
          log.debug("Adding maven-surefire-report-plugin ...");
          const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-surefire.xml`, "utf-8");
          common.replaceStringInFileWithProps(workdir + "/pom.xml", "<plugins>", replacementString, undefined, false);
        }
      }

      log.debug("Testing artifacts");
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);  
      if (testTypes.includes(TestType.Static)) {
        log.debug("Commencing static tests");
        shell.cd(workdir);
        await exec(`${shellDir}/test/static-java.sh \
        ${taskParams["buildTool"]} \
        ${version} \
        ${taskParams["sonarUrl"]} \
        ${taskParams["sonarApiKey"]} \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \
        ${taskParams["sonarExclusions"]} \
        ${JSON.stringify(taskParams["artifactoryUrl"])} \
        ${taskParams["artifactoryUser"]} \
        ${taskParams["artifactoryPassword"]} \
        `);
      }      
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);
      if (testTypes.includes(TestType.Unit)) {
        log.debug("Commencing unit tests");
        await exec(`${shellDir}/test/initialize-dependencies-unit-java.sh`);
        shell.cd(workdir);
        await exec(`${shellDir}/test/unit-java.sh \
        ${taskParams["buildTool"]} \
        ${version} \
        ${taskParams["sonarUrl"]} \
        ${taskParams["sonarApiKey"]} \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \
        ${JSON.stringify(taskParams["artifactoryUrl"])} \
        ${taskParams["artifactoryUser"]} \
        ${taskParams["artifactoryPassword"]} \
        `);
      }
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);
      if (testTypes.includes(TestType.Security)) {
        log.debug("Commencing security tests");
        shell.cd(workdir);
        await exec(
          `${shellDir}/test/security-java.sh \
          ${taskParams["systemComponentName"]} \
          ${version} \
          ${JSON.stringify(taskParams["asocRepoUrl"])} \
          ${taskParams["asocRepoUser"]} \
          ${taskParams["asocRepoPassword"]} \
          ${taskParams["asocAppId"]} \
          ${taskParams["asocLoginKeyId"]} \
          ${taskParams["asocLoginSecret"]} \
          ${taskParams["asocClientCli"]} \
          ${taskParams["asocJavaRuntime"]} \
          ${shellDir} \
          ${testdir}`
        );
      }
      if (testTypes.includes(TestType.SeleniumNative)) {
        log.debug("Commencing automated Selenium native tests");
        shell.cd(workdir);
        await exec(`${shellDir}/test/selenium-native.sh \
        ${taskParams["systemComponentName"]} ${version} \
        ${taskParams["saucelabsApiKey"]} \
        ${taskParams["saucelabsApiUser"]} ${JSON.stringify(taskParams["saucelabsApiUrl"])} \
        ${taskParams["browserName"]} \
        ${taskParams["browserVersion"]} \
        ${taskParams["platformType"]} \
        ${taskParams["platformVersion"]} \
        ${taskParams["webTestsFolder"]} \
        ${taskParams["gitUser"]} \
        ${taskParams["gitPassword"]} \
        ${shellDir} \
        ${testdir}`);
      }
      if (testTypes.includes(TestType.SeleniumCustom)) {
        log.debug("Commencing automated Selenium custom tests");
        shell.cd(workdir);
        await exec(`${shellDir}/test/selenium-custom.sh "\
        ${taskParams["teamName"]}" \
        ${taskParams["systemComponentName"]} ${version} \
        ${taskParams["seleniumApplicationPropertiesFile"]} \
        ${taskParams["seleniumApplicationPropertiesKey"]} \
        ${taskParams["saucelabsApiUrlWithCredentials"]} \
        ${taskParams["seleniumReportFolder"]} \
        ${JSON.stringify(taskParams["artifactoryUrl"])} \
        ${taskParams["artifactoryUser"]} \
        ${taskParams["artifactoryPassword"]} \
        ${shellDir} \
        ${testdir}`);
      }
      if (testTypes.includes(TestType.Library)) {
        log.debug("Commencing WhiteSource scan");
        shell.cd(workdir);
        await exec(`${shellDir}/test/initialize-dependencies-whitesource.sh ${JSON.stringify(taskParams["whitesourceAgentDownloadUrl"])}`);
        await exec(`${shellDir}/test/whitesource.sh \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \
        ${taskParams["version"]} \
        ${version} \
        "${taskParams["teamName"]}" \
        ${taskParams["whitesourceApiKey"]} \
        ${taskParams["whitesourceUserKey"]} \
        ${taskParams["whitesourceProductName"]} \
        ${taskParams["whitesourceProductToken"]} \
        ${JSON.stringify(taskParams["whitesourceWssUrl"])} \
        `);
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Java test activity");
    }
  },
  async jar() {
    log.debug("Started Boomerang CICD Jar Test Activity");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);

    let workdir = dir + "/repository";
    log.debug("Working Directory: ", workdir);

    let testdir = "/test";
    shell.mkdir("-p", testdir);
    log.debug("Test Directory: ", testdir);

    let buildTool = taskParams["buildTool"];
    log.debug("Build Tool: ", buildTool);

    // log.debug("Copy source code from shared drive to container");
    // shell.mkdir("-p", workdir);
    // shell.cp("-R", dir + "/repository/*", testdir);

    const testTypes = typeof taskParams["testType"] === "string" ? taskParams["testType"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);
      await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]}`);

      if (buildTool === "maven") {
        log.debug("Checking Maven Configuration");
        if (!common.checkFileContainsStringWithProps(workdir + "/pom.xml", "<plugins>", undefined, false)) {
          log.debug("No Maven plugins found, adding ...");
          const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-plugins.xml`, "utf-8");
          common.replaceStringInFileWithProps(workdir + "/pom.xml", "<plugins>", replacementString, undefined, false);
        }
        if (!common.checkFileContainsStringWithProps(workdir + "/pom.xml", "<artifactId>jacoco-maven-plugin</artifactId>", undefined, false)) {
          log.debug("Adding jacoco-maven-plugin ...");
          const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-jacoco.xml`, "utf-8");
          common.replaceStringInFileWithProps(workdir + "/pom.xml", "<plugins>", replacementString, undefined, false);
        }
        if (!common.checkFileContainsStringWithProps(workdir + "/pom.xml", "<artifactId>sonar-maven-plugin</artifactId>", undefined, false)) {
          log.debug("Adding sonar-maven-plugin ...");
          const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-sonar.xml`, "utf-8");
          common.replaceStringInFileWithProps(workdir + "/pom.xml", "<plugins>", replacementString, undefined, false);
        }
        if (!common.checkFileContainsStringWithProps(workdir + "/pom.xml", "<artifactId>maven-surefire-report-plugin</artifactId>", undefined, false)) {
          log.debug("Adding maven-surefire-report-plugin ...");
          const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-surefire.xml`, "utf-8");
          common.replaceStringInFileWithProps(workdir + "/pom.xml", "<plugins>", replacementString, undefined, false);
        }
      }

      log.ci("Testing artifacts");
      if (testTypes.includes(TestType.Static)) {
        log.debug("Commencing static tests");
        shell.cd(workdir);
        await exec(`${shellDir}/test/static-java.sh \
        ${taskParams["buildTool"]} \
        ${version} \
        ${taskParams["sonarUrl"]} \
        ${taskParams["sonarApiKey"]} \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \
        ${taskParams["sonarExclusions"]}`);
      }
      if (testTypes.includes(TestType.Unit)) {
        log.debug("Commencing unit tests");
        await exec(`${shellDir}/test/initialize-dependencies-unit-java.sh`);
        shell.cd(workdir);
        await exec(`${shellDir}/test/unit-java.sh \
        ${taskParams["buildTool"]} \
        ${version} \
        ${taskParams["sonarUrl"]} \
        ${taskParams["sonarApiKey"]} \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]}`);
      }
      if (testTypes.includes(TestType.Security)) {
        log.debug("Commencing security tests");
        shell.cd(workdir);
        await exec(`${shellDir}/test/security-java.sh \
          ${taskParams["systemComponentName"]} \
          ${version} \
          ${JSON.stringify(taskParams["asocRepoUrl"])} \
          ${taskParams["asocRepoUser"]} \
          ${taskParams["asocRepoPassword"]} \
          ${taskParams["asocAppId"]} \
          ${taskParams["asocLoginKeyId"]} \
          ${taskParams["asocLoginSecret"]} \
          ${taskParams["asocClientCli"]} \
          ${taskParams["asocJavaRuntime"]} \
          ${shellDir} \
          ${testdir}`);
      }
      if (testTypes.includes(TestType.SeleniumNative)) {
        log.debug("Native Selenium testing type not supported for Jar");
      }
      if (testTypes.includes(TestType.SeleniumCustom)) {
        log.debug("Custom Selenium testing type not supported for Jar");
      }
      if (testTypes.includes(TestType.Library)) {
        log.debug("Commencing WhiteSource scan");
        shell.cd(workdir);
        await exec(`${shellDir}/test/initialize-dependencies-whitesource.sh ${JSON.stringify(taskParams["whitesourceAgentDownloadUrl"])}`);
        await exec(`${shellDir}/test/whitesource.sh \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \
        ${taskParams["version"]} \
        ${version} \
        "${taskParams["teamName"]}" \
        ${taskParams["whitesourceApiKey"]} \
        ${taskParams["whitesourceUserKey"]} \
        ${taskParams["whitesourceProductName"]} \
        ${taskParams["whitesourceProductToken"]} \
        ${JSON.stringify(taskParams["whitesourceWssUrl"])} \
        `);
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Jar test activity");
    }
  },
  async nodejs() {
    log.debug("Started Boomerang CICD Node.js Test Activity");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);

    let workdir = dir + "/repository";
    log.debug("Working Directory: ", workdir);

    let testdir = "/test";
    shell.mkdir("-p", testdir);
    log.debug("Test Directory: ", testdir);

    // log.debug("Copy source code from shared drive to container");
    // shell.mkdir("-p", workdir);
    // shell.cp("-R", dir + "/repository/*", testdir);

    const testTypes = typeof taskParams["testType"] === "string" ? taskParams["testType"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-node.sh \
      ${taskParams["languageVersion"]} \
      ${taskParams["buildTool"]} \
      ${JSON.stringify(taskParams["artifactoryUrl"])} \
      ${taskParams["artifactoryUser"]} \
      ${taskParams["artifactoryPassword"]} \
      "${taskParams["featureNodeCache"]}"`);

      log.ci("Test Artifacts");
      shell.cd(workdir);
      await exec(`${shellDir}/test/initialize-dependencies-node.sh \
      ${taskParams["languageVersion"]} \
      ${taskParams["buildTool"]} \
      ${taskParams["cypressInstallBinary"]}`);

      if (testTypes.includes(TestType.Unit)) {
        log.debug("Commencing unit tests");
        await exec(`${shellDir}/test/unit-node.sh \
        ${taskParams["languageVersion"]} \
        ${taskParams["buildTool"]} \
        ${version} \
        ${taskParams["sonarUrl"]} \
        ${taskParams["sonarApiKey"]} \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \\
        ${JSON.stringify(taskParams["artifactoryUrl"])} \
        ${taskParams["artifactoryUser"]} \
        ${taskParams["artifactoryPassword"]}`);
      }
      if (testTypes.includes(TestType.Static)) {
        log.debug("Commencing static tests");
        await exec(`${shellDir}/test/static-node.sh \
        ${taskParams["languageVersion"]} \
        ${taskParams["buildTool"]} \
        ${version} \
        ${taskParams["sonarUrl"]} \
        ${taskParams["sonarApiKey"]} \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \
        ${JSON.stringify(taskParams["artifactoryUrl"])} \
        ${taskParams["artifactoryUser"]} \
        ${taskParams["artifactoryPassword"]}`);
      }
      if (testTypes.includes(TestType.Security)) {
        log.debug("Commencing security tests");
        await exec(
          `${shellDir}/test/security-node.sh \
          ${taskParams["systemComponentName"]} \
          ${version} \
          ${JSON.stringify(taskParams["asocRepoUrl"])} \
          ${taskParams["asocRepoUser"]} \
          ${taskParams["asocRepoPassword"]} \
          ${taskParams["asocAppId"]} \
          ${taskParams["asocLoginKeyId"]} \
          ${taskParams["asocLoginSecret"]} \
          ${taskParams["asocClientCli"]} \
          ${taskParams["asocJavaRuntime"]} \
          ${shellDir} \
          ${testdir}`
        );
      }
      if (testTypes.includes(TestType.SeleniumNative)) {
        log.debug("Commencing automated Selenium native tests");
        await exec(
          `${shellDir}/test/selenium-native.sh \
          ${taskParams["systemComponentName"]} \
          ${version} \
          ${taskParams["saucelabsApiKey"]} \
          ${taskParams["saucelabsApiUser"]} \
          ${JSON.stringify(taskParams["saucelabsApiUrl"])} \
          ${taskParams["browserName"]} \
          ${taskParams["browserVersion"]} \
          ${taskParams["platformType"]} \
          ${taskParams["platformVersion"]} \
          ${taskParams["webTestsFolder"]} \
          ${taskParams["gitUser"]} \
          ${taskParams["gitPassword"]} \
          ${shellDir} \
          ${testdir}`
        );
      }
      if (testTypes.includes(TestType.SeleniumCustom)) {
        log.debug("Custom Selenium testing type not supported for Node.js");
      }
      if (testTypes.includes(TestType.Library)) {
        log.debug("Commencing WhiteSource scan");
        shell.cd(workdir);
        await exec(`${shellDir}/test/initialize-dependencies-whitesource.sh ${JSON.stringify(taskParams["whitesourceAgentDownloadUrl"])}`);
        await exec(`${shellDir}/test/whitesource.sh \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \
        ${taskParams["version"]} \
        ${version} \
        "${taskParams["teamName"]}" \
        ${taskParams["whitesourceApiKey"]} \
        ${taskParams["whitesourceUserKey"]} \
        ${taskParams["whitesourceProductName"]} \
        ${taskParams["whitesourceProductToken"]} \
        ${JSON.stringify(taskParams["whitesourceWssUrl"])} \
        `);
      }
    } catch (e) {
      log.err("Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Node.js test activity");
    }
  },
  async npm() {
    log.debug("Started Boomerang CICD npm Package Test Activity");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);

    let workdir = dir + "/repository";
    log.debug("Working Directory: ", workdir);

    let testdir = "/test";
    shell.mkdir("-p", testdir);
    log.debug("Test Directory: ", testdir);

    // log.debug("Copy source code from shared drive to container");
    // shell.mkdir("-p", workdir);
    // shell.cp("-R", dir + "/repository/*", testdir);

    const testTypes = typeof taskParams["testType"] === "string" ? taskParams["testType"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-node.sh \
      ${taskParams["languageVersion"]} \
      ${taskParams["buildTool"]} \
      ${JSON.stringify(taskParams["artifactoryUrl"])} \
      ${taskParams["artifactoryUser"]} \
      ${taskParams["artifactoryPassword"]} \
      "${taskParams["featureNodeCache"]}"`);

      log.ci("Test Artifacts");
      shell.cd(workdir);
      await exec(`${shellDir}/test/initialize-dependencies-node.sh \
      ${taskParams["languageVersion"]} \
      ${taskParams["buildTool"]} \
      ${taskParams["cypressInstallBinary"]}`);

      if (testTypes.includes(TestType.Static)) {
        log.debug("Commencing static tests");
        await exec(`${shellDir}/test/static-node.sh \
        ${taskParams["languageVersion"]} \
        ${taskParams["buildTool"]} \
        ${version} \
        ${taskParams["sonarUrl"]} \
        ${taskParams["sonarApiKey"]} \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]}`);
      }
      if (testTypes.includes(TestType.Unit)) {
        log.debug("Commencing unit tests");
        await exec(`${shellDir}/test/unit-node.sh \
        ${taskParams["languageVersion"]} \
        ${taskParams["buildTool"]} \
        ${version} \
        ${taskParams["sonarUrl"]} \
        ${taskParams["sonarApiKey"]} \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]}`);
      }
      if (testTypes.includes(TestType.Security)) {
        log.debug("Commencing security tests");
        await exec(
          `${shellDir}/test/security-node.sh \
          ${taskParams["systemComponentName"]} \
          ${version} \
          ${JSON.stringify(taskParams["asocRepoUrl"])} \
          ${taskParams["asocRepoUser"]} \
          ${taskParams["asocRepoPassword"]} \
          ${taskParams["asocAppId"]} \
          ${taskParams["asocLoginKeyId"]} \
          ${taskParams["asocLoginSecret"]} \
          ${taskParams["asocClientCli"]} \
          ${taskParams["asocJavaRuntime"]} \
          ${shellDir} \
          ${testdir}`
        );
      }
      if (testTypes.includes(TestType.SeleniumNative)) {
        log.debug("Native Selenium testing type not supported for npm packages");
      }
      if (testTypes.includes(TestType.SeleniumCustom)) {
        log.debug("Custom Selenium testing type not supported for npm packages");
      }
      if (testTypes.includes(TestType.Library)) {
        log.debug("Commencing WhiteSource scan");
        shell.cd(workdir);
        await exec(`${shellDir}/test/initialize-dependencies-whitesource.sh ${JSON.stringify(taskParams["whitesourceAgentDownloadUrl"])}`);
        await exec(`${shellDir}/test/whitesource.sh \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \
        ${taskParams["version"]} \
        ${version} \
        "${taskParams["teamName"]}" \
        ${taskParams["whitesourceApiKey"]} \
        ${taskParams["whitesourceUserKey"]} \
        ${taskParams["whitesourceProductName"]} \
        ${taskParams["whitesourceProductToken"]} \
        ${JSON.stringify(taskParams["whitesourceWssUrl"])} \
        `);
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Node.js test activity");
    }
  },
  async python() {
    log.debug("Started Boomerang CICD Python Test Activity");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);

    let workdir = dir + "/repository";
    log.debug("Working Directory: ", workdir);

    let testdir = "/test";
    shell.mkdir("-p", testdir);
    log.debug("Test Directory: ", testdir);

    // log.debug("Copy source code from shared drive to container");
    // shell.mkdir("-p", workdir);
    // shell.cp("-R", dir + "/repository/*", testdir);

    const testTypes = typeof taskParams["testType"] === "string" ? taskParams["testType"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-python.sh \
      ${taskParams["languageVersion"]}`);

      if (testTypes.includes(TestType.Static)) {
        log.ci("Commencing static tests");
        await exec(`${shellDir}/test/initialize-dependencies-static-python.sh \
        ${taskParams["languageVersion"]} \
        ${JSON.stringify(taskParams["pypiRegistryHost"])} \
        ${taskParams["pypiRepoId"]} \
        ${taskParams["pypiRepoUser"]} \
        ${taskParams["pypiRepoPassword"]}`);

        shell.cd(workdir);
        await exec(`${shellDir}/test/static-python.sh \
        ${taskParams["buildTool"]} ${version} \
        ${taskParams["sonarUrl"]} \
        ${taskParams["sonarApiKey"]} \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]}`);
      }
      if (testTypes.includes(TestType.Unit)) {
        log.debug("Unit tests not implemented for Python");
      }
      if (testTypes.includes(TestType.Security)) {
        log.debug("Security tests not implemented for Python");
      }
      if (testTypes.includes(TestType.SeleniumNative)) {
        log.debug("Commencing automated Selenium native tests");
        shell.cd(workdir);
        await exec(
          `${shellDir}/test/selenium-native.sh \
          ${taskParams["systemComponentName"]} \
          ${version} \
          ${taskParams["saucelabsApiKey"]} \
          ${taskParams["saucelabsApiUser"]} \
          ${JSON.stringify(taskParams["saucelabsApiUrl"])} \
          ${taskParams["browserName"]} \
          ${taskParams["browserVersion"]} \
          ${taskParams["platformType"]} \
          ${taskParams["platformVersion"]} \
          ${taskParams["webTestsFolder"]} \
          ${taskParams["gitUser"]} \
          ${taskParams["gitPassword"]} \
          ${shellDir} \
          ${testdir}`
        );
      }
      if (testTypes.includes(TestType.SeleniumCustom)) {
        log.debug("Custom Selenium testing type not supported for Python");
      }
      if (testTypes.includes(TestType.Library)) {
        log.debug("Commencing WhiteSource scan");
        shell.cd(workdir);
        await exec(`${shellDir}/test/initialize-dependencies-whitesource.sh ${JSON.stringify(taskParams["whitesourceAgentDownloadUrl"])}`);
        await exec(`${shellDir}/test/whitesource.sh \
        ${taskParams["systemComponentId"]} \
        ${taskParams["systemComponentName"]} \
        ${taskParams["version"]} \
        ${version} \
        "${taskParams["teamName"]}" \
        ${taskParams["whitesourceApiKey"]} \
        ${taskParams["whitesourceUserKey"]} \
        ${taskParams["whitesourceProductName"]} \
        ${taskParams["whitesourceProductToken"]} \
        ${JSON.stringify(taskParams["whitesourceWssUrl"])} \
        `);
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Python test activity");
    }
  },
  async helm() {
    log.debug("Started Boomerang CICD Helm Test Activity");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);

    let workdir = dir + "/repository";
    log.debug("Working Directory: ", workdir);

    let testdir = "/test";
    shell.mkdir("-p", testdir);
    log.debug("Test Directory: ", testdir);

    // log.debug("Copy source code from shared drive to container");
    // shell.mkdir("-p", workdir);
    // shell.cp("-R", dir + "/repository/*", testdir);

    const testTypes = typeof taskParams["testType"] === "string" ? taskParams["testType"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-helm.sh ${taskParams["buildToolVersion"]}"`);

      if (testTypes.includes(TestType.Static)) {
        log.debug("Linting Helm Chart(s)");
        shell.cd(workdir);
        await exec(`${shellDir}/test/lint-helm.sh \
        ${taskParams["buildTool"]} \
        ${taskParams["helmRepoUrl"]} \
        ${taskParams["helmChartDirectory"]} \
        ${taskParams["helmChartIgnore"]}`);
      }
      if (testTypes.includes(TestType.Unit)) {
        log.debug("Unit tests not implemented for Helm");
      }
      if (testTypes.includes(TestType.Security)) {
        log.debug("Security tests not implemented for Helm");
      }
      if (testTypes.includes(TestType.SeleniumNative)) {
        log.debug("Native Selenium testing type not supported for Helm");
      }
      if (testTypes.includes(TestType.SeleniumCustom)) {
        log.debug("Custom Selenium testing type not supported for Helm");
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Helm test activity");
    }
  }
};
