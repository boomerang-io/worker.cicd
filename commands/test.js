const { log, utils, CICDError, common } = require("@boomerang-io/worker-core");
const shell = require("shelljs");
const fs = require("fs");

// TODO: Move enums to a shared constants file to be used for other commands
const ComponentMode = {
  Nodejs: "nodejs",
  Python: "python",
  Java: "java",
  Jar: "lib.jar",
  Helm: "helm.chart"
};

const TestType = {
  Unit: "unit",
  Static: "static",
  Security: "security",
  SeleniumNative: "seleniumNative",
  SeleniumCustom: "seleniumCustom"
};

// Freeze so they can't be modified at runtime
Object.freeze(ComponentMode);
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
  log.debug("  Version:", parsedVersion);
  return parsedVersion;
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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    const testTypes = typeof taskParams["test.type"] === "string" ? taskParams["test.type"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);
      await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]}`);

      if (!common.checkFileContainsStringWithProps("/data/workspace/pom.xml", "<plugins>", undefined, false)) {
        log.debug("No Maven plugins found, adding...");
        const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-plugins.xml`, "utf-8");
        common.replaceStringInFileWithProps("/data/workspace/pom.xml", "<plugins>", replacementString, undefined, false);
      }
      if (!common.checkFileContainsStringWithProps("/data/workspace/pom.xml", "<artifactId>jacoco-maven-plugin</artifactId>", undefined, false)) {
        log.debug("...adding jacoco-maven-plugin.");
        const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-jacoco.xml`, "utf-8");
        common.replaceStringInFileWithProps("/data/workspace/pom.xml", "<plugins>", replacementString, undefined, false);
      }
      if (!common.checkFileContainsStringWithProps("/data/workspace/pom.xml", "<artifactId>sonar-maven-plugin</artifactId>", undefined, false)) {
        log.debug("...adding sonar-maven-plugin.");
        const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-sonar.xml`, "utf-8");
        common.replaceStringInFileWithProps("/data/workspace/pom.xml", "<plugins>", replacementString, undefined, false);
      }
      if (!common.checkFileContainsStringWithProps("/data/workspace/pom.xml", "<artifactId>maven-surefire-report-plugin</artifactId>", undefined, false)) {
        log.debug("...adding maven-surefire-report-plugin.");
        const replacementString = fs.readFileSync(`${shellDir}/test/unit-java-maven-surefire.xml`, "utf-8");
        common.replaceStringInFileWithProps("/data/workspace/pom.xml", "<plugins>", replacementString, undefined, false);
      }

      log.ci("Testing artifacts");
      if (testTypes.includes(TestType.Static)) {
        log.debug("Commencing static tests");
        await exec(`${shellDir}/test/static-java.sh ${taskParams["build.tool"]} ${version} ${taskParams["global/sonar.url"]} ${taskParams["global/sonar.api.key"]} ${taskParams["system.component.id"]} ${taskParams["system.component.name"]} ${taskParams["sonar.exclusions"]}`);
      }
      if (testTypes.includes(TestType.Unit)) {
        log.debug("Commencing unit tests");
        await exec(`${shellDir}/test/initialize-dependencies-unit-java.sh`);
        await exec(`${shellDir}/test/unit-java.sh ${taskParams["build.tool"]} ${version} ${taskParams["global/sonar.url"]} ${taskParams["global/sonar.api.key"]} ${taskParams["system.component.id"]} ${taskParams["system.component.name"]}`);
      }
      if (testTypes.includes(TestType.Security)) {
        log.debug("Commencing security tests");
        shell.cd(dir + "/repository");
        await exec(`${shellDir}/build/compile-java.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]} ${version} ${JSON.stringify(taskParams["repoUrl"])} ${taskParams["repoId"]} ${taskParams["repoUser"]} "${taskParams["repoPassword"]}"`);
        await exec(`${shellDir}/test/security-java.sh ${taskParams["system.component.name"]} ${version} ${JSON.stringify(taskParams["global/asoc.repo.url"])} ${taskParams["global/asoc.repo.user"]} ${taskParams["global/asoc.repo.password"]} ${taskParams["global/asoc.app.id"]} ${taskParams["global/asoc.login.key.id"]} ${taskParams["global/asoc.login.secret"]} ${taskParams["global/asoc.client.cli"]} ${taskParams["global/asoc.java.runtime"]} ${shellDir}`);
      }
      if (testTypes.includes(TestType.SeleniumNative)) {
        log.debug("Commencing automated Selenium native tests");
        await exec(`${shellDir}/test/selenium-native.sh ${taskParams["system.component.name"]} ${version} ${taskParams["global/saucelabs.api.key"]} ${taskParams["global/saucelabs.api.user"]} ${JSON.stringify(taskParams["global/saucelabs.api.url"])} ${taskParams["browser.name"]} ${taskParams["browser.version"]} ${taskParams["platform.type"]} ${taskParams["platform.version"]} ${taskParams["web.tests.folder"]} ${taskParams["git.user"]} ${taskParams["git.password"]} ${shellDir}`);
      }
      if (testTypes.includes(TestType.SeleniumCustom)) {
        log.debug("Commencing automated Selenium custom tests");
        await exec(`${shellDir}/test/selenium-custom.sh ${taskParams["team.name"]} ${taskParams["system.component.name"]} ${version} ${taskParams["selenium.application.properties.file"]} ${taskParams["selenium.application.properties.key"]} ${taskParams["global/saucelabs.api.url.with.credentials"]} ${taskParams["selenium.report.folder"]} ${JSON.stringify(taskParams["global/artifactory.url"])} ${taskParams["global/artifactory.user"]} ${taskParams["global/artifactory.password"]} ${shellDir}`);
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Java test activity");
    }
  },
  async nodejs() {
    log.debug("Started Boomerang CICD NodeJS Test Activity");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // const { path, script } = taskParams;
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    const testTypes = typeof taskParams["test.type"] === "string" ? taskParams["test.type"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-node.sh ${taskParams["build.tool"]} ${JSON.stringify(taskParams["global/artifactory.url"])} ${taskParams["global/artifactory.user"]} ${taskParams["global/artifactory.password"]}`);

      await exec(`${shellDir}/test/initialize-dependencies-node.sh ${taskParams["build.tool"]} ${taskParams["node.cypress.install.binary"]}`);
      if (testTypes.includes(TestType.Static)) {
        log.debug("Commencing static tests");
        await exec(`${shellDir}/test/static-node.sh ${taskParams["build.tool"]} ${version} ${taskParams["global/sonar.url"]} ${taskParams["global/sonar.api.key"]} ${taskParams["system.component.id"]} ${taskParams["system.component.name"]}`);
      }
      if (testTypes.includes(TestType.Unit)) {
        log.debug("Commencing unit tests");
        await exec(`${shellDir}/test/unit-node.sh ${taskParams["build.tool"]} ${version} ${taskParams["global/sonar.url"]} ${taskParams["global/sonar.api.key"]} ${taskParams["system.component.id"]} ${taskParams["system.component.name"]}`);
      }
      if (testTypes.includes(TestType.Security)) {
        log.debug("Commencing security tests");
        await exec(`${shellDir}/test/security-node.sh ${taskParams["system.component.name"]} ${version} ${JSON.stringify(taskParams["global/asoc.repo.url"])} ${taskParams["global/asoc.repo.user"]} ${taskParams["global/asoc.repo.password"]} ${taskParams["global/asoc.app.id"]} ${taskParams["global/asoc.login.key.id"]} ${taskParams["global/asoc.login.secret"]} ${taskParams["global/asoc.client.cli"]} ${taskParams["global/asoc.java.runtime"]} ${shellDir}`);
      }
      if (testTypes.includes(TestType.SeleniumNative)) {
        log.debug("Commencing automated Selenium native tests");
        await exec(`${shellDir}/test/selenium-native.sh ${taskParams["system.component.name"]} ${version} ${taskParams["global/saucelabs.api.key"]} ${taskParams["global/saucelabs.api.user"]} ${JSON.stringify(taskParams["global/saucelabs.api.url"])} ${taskParams["browser.name"]} ${taskParams["browser.version"]} ${taskParams["platform.type"]} ${taskParams["platform.version"]} ${taskParams["web.tests.folder"]} ${taskParams["git.user"]} ${taskParams["git.password"]} ${shellDir}`);
      }
      if (testTypes.includes(TestType.SeleniumCustom)) {
        log.debug("Custom Selenium testing type not supported for NodeJS");
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Java test activity");
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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    const testTypes = typeof taskParams["test.type"] === "string" ? taskParams["test.type"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-python.sh ${taskParams["language.version"]}`);

      if (testTypes.includes(TestType.Static)) {
        log.debug("Commencing static tests");
        await exec(`${shellDir}/test/initialize-dependencies-static-python.sh ${taskParams["language.version"]} ${JSON.stringify(taskParams["global/pypi.registry.host"])} ${taskParams["global/pypi.repo.id"]} ${taskParams["global/pypi.repo.user"]} ${taskParams["global/pypi.repo.password"]}`);
        await exec(`${shellDir}/test/static-python.sh ${taskParams["build.tool"]} ${version} ${taskParams["global/sonar.url"]} ${taskParams["global/sonar.api.key"]} ${taskParams["system.component.id"]} ${taskParams["system.component.name"]}`);
      }
      if (testTypes.includes(TestType.Unit)) {
        log.debug("Unit tests not implemented for Python");
      }
      if (testTypes.includes(TestType.Security)) {
        log.debug("Security tests not implemented for Python");
      }
      if (testTypes.includes(TestType.SeleniumNative)) {
        log.debug("Commencing automated Selenium native tests");
        await exec(`${shellDir}/test/selenium-native.sh ${taskParams["system.component.name"]} ${version} ${taskParams["global/saucelabs.api.key"]} ${taskParams["global/saucelabs.api.user"]} ${JSON.stringify(taskParams["global/saucelabs.api.url"])} ${taskParams["browser.name"]} ${taskParams["browser.version"]} ${taskParams["platform.type"]} ${taskParams["platform.version"]} ${taskParams["web.tests.folder"]} ${taskParams["git.user"]} ${taskParams["git.password"]} ${shellDir}`);
      }
      if (testTypes.includes(TestType.SeleniumCustom)) {
        log.debug("Custom Selenium testing type not supported for Python");
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Java test activity");
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

    let dir = "/workspace/" + taskParams["workflow-activity-id"];
    log.debug("Working Directory: ", dir);

    const testTypes = typeof taskParams["test.type"] === "string" ? taskParams["test.type"].split(",") : [];
    const version = parseVersion(taskParams["version"], taskParams["appendBuildNumber"]);

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-helm.sh ${taskParams["kube.version"]}`);

      if (testTypes.includes(TestType.Static)) {
        log.debug("Linting Helm Chart(s)");
        await exec(`${shellDir}/test/lint-helm.sh ${taskProps["global/helm.repo.url"]} ${taskProps["helm.chart.directory"]} ${taskProps["helm.chart.ignore"]}`);
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
      log.debug("Finished Boomerang CICD Java test activity");
    }
  }
};
