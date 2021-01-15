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
  Security: "security"
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
    const testTypes = typeof taskProps["test.type"] === "string" ? taskProps["test.type"].split(",") : [];

    try {
      log.ci("Initializing Dependencies");
      await exec(`${shellDir}/common/initialize.sh`);
      await exec(`${shellDir}/common/initialize-dependencies-java.sh ${taskParams["languageVersion"]}`);
      await exec(`${shellDir}/common/initialize-dependencies-java-tool.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]}`);

      log.ci("Compile & Package Artifact(s)");
      shell.cd(dir + "/repository");
      // await exec(`${shellDir}/build/compile-java.sh ${taskParams["buildTool"]} ${taskParams["buildToolVersion"]} ${version} ${JSON.stringify(taskParams["repoUrl"])} ${taskParams["repoId"]} ${taskParams["repoUser"]} "${taskParams["repoPassword"]}"`);
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
      if (testTypes.includes(TestType.Static)) {
        log.debug("Commencing static tests");
        await exec(`${shellDir}/test/static-java.sh ${taskProps["build.tool"]} ${taskProps["version.name"]} ${taskProps["global/sonar.url"]} ${taskProps["global/sonar.api.key"]} ${taskProps["system.component.id"]} ${taskProps["system.component.name"]} ${taskProps["sonar.exclusions"]}`);
      }
      if (testTypes.includes(TestType.Unit)) {
        log.debug("Commencing unit tests");
        await exec(`${shellDir}/test/initialize-dependencies-unit-java.sh`);
        await exec(`${shellDir}/test/unit-java.sh ${taskProps["build.tool"]} ${taskProps["version.name"]} ${taskProps["global/sonar.url"]} ${taskProps["global/sonar.api.key"]} ${taskProps["system.component.id"]} ${taskProps["system.component.name"]}`);
      }
      if (testTypes.includes(TestType.Security)) {
        log.debug("Commencing security tests");
        await exec(
          `${shellDir}/build/compile-java.sh ${taskProps["build.tool"]} ${taskProps["build.tool.version"]} ${taskProps["version.name"]} ${JSON.stringify(taskProps["global/maven.repo.url"])} ${taskProps["global/maven.repo.id"]} ${taskProps["global/artifactory.user"]} ${
            taskProps["global/artifactory.password"]
          }`
        );
        await exec(
          `${shellDir}/test/security-java.sh ${taskProps["system.component.name"]} ${taskProps["version.name"]} ${JSON.stringify(taskProps["global/asoc.repo.url"])} ${taskProps["global/asoc.repo.user"]} ${taskProps["global/asoc.repo.password"]} ${taskProps["global/asoc.app.id"]} ${
            taskProps["global/asoc.login.key.id"]
          } ${taskProps["global/asoc.login.secret"]} ${taskProps["global/asoc.client.cli"]} ${taskProps["global/asoc.java.runtime"]} ${shellDir}`
        );
      }
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      await exec(shellDir + "/common/footer.sh");
      log.debug("Finished Boomerang CICD Java build activity");
    }
  },
  async execute() {
    log.debug("Started CICD Test Activity");

    const taskProps = utils.resolveCICDInputProperties();
    const shellDir = "/cli/scripts";
    config = {
      verbose: true
    };

    const testTypes = typeof taskProps["test.type"] === "string" ? taskProps["test.type"].split(",") : [];
    const componentMode = taskProps["system.mode"];

    try {
      if (taskProps["build.number.append"] === false) {
        log.sys("Stripping build number from version...");
        taskProps["version.name"] = taskProps["version.name"].substr(0, taskProps["version.name"].lastIndexOf("-"));
        log.debug("  Version:", taskProps["version.name"]);
      }

      if (!testTypes.length) {
        log.good("No test types specified.");
      } else {
        shell.cd("/data");
        log.ci("Initializing Dependencies");
        if (componentMode === ComponentMode.Jar || componentMode === ComponentMode.Java) {
        } else if (componentMode === ComponentMode.Nodejs) {
          await exec(`${shellDir}/common/initialize-dependencies-node.sh ${taskProps["build.tool"]} ${JSON.stringify(taskProps["global/artifactory.url"])} ${taskProps["global/artifactory.user"]} ${taskProps["global/artifactory.password"]}`);
        } else if (componentMode === ComponentMode.Python) {
          await exec(`${shellDir}/common/initialize-dependencies-python.sh ${taskProps["language.version"]}`);
        } else if (componentMode === ComponentMode.Helm) {
          await exec(`${shellDir}/common/initialize-dependencies-helm.sh ${taskProps["kube.version"]}`);
        }

        log.ci("Retrieving Source Code");
        await exec(`${shellDir}/common/git-clone.sh "${taskProps["git.private.key"]}" "${taskProps["component/repoSshUrl"]}" "${taskProps["component/repoUrl"]}" "${taskProps["git.commit.id"]}"`);
        shell.cd("/data/workspace");
        if (componentMode === ComponentMode.Jar || componentMode === ComponentMode.Java) {
        } else if (componentMode === ComponentMode.Nodejs) {
          log.debug("Install node.js dependencies");
          await exec(`${shellDir}/test/initialize-dependencies-node.sh ${taskProps["build.tool"]} ${taskProps["node.cypress.install.binary"]}`);
          if (testTypes.includes(TestType.Static)) {
            log.debug("Commencing static tests");
            await exec(`${shellDir}/test/static-node.sh ${taskProps["build.tool"]} ${taskProps["version.name"]} ${taskProps["global/sonar.url"]} ${taskProps["global/sonar.api.key"]} ${taskProps["system.component.id"]} ${taskProps["system.component.name"]}`);
          }
          if (testTypes.includes(TestType.Unit)) {
            log.debug("Commencing unit tests");
            await exec(`${shellDir}/test/unit-node.sh ${taskProps["build.tool"]} ${taskProps["version.name"]} ${taskProps["global/sonar.url"]} ${taskProps["global/sonar.api.key"]} ${taskProps["system.component.id"]} ${taskProps["system.component.name"]}`);
          }
          if (testTypes.includes(TestType.Security)) {
            log.debug("Commencing security tests");
            await exec(
              `${shellDir}/test/security-node.sh ${taskProps["system.component.name"]} ${taskProps["version.name"]} ${JSON.stringify(taskProps["global/asoc.repo.url"])} ${taskProps["global/asoc.repo.user"]} ${taskProps["global/asoc.repo.password"]} ${taskProps["global/asoc.app.id"]} ${
                taskProps["global/asoc.login.key.id"]
              } ${taskProps["global/asoc.login.secret"]} ${taskProps["global/asoc.client.cli"]} ${taskProps["global/asoc.java.runtime"]} ${shellDir}`
            );
          }
        } else if (componentMode === ComponentMode.Python) {
          if (testTypes.includes(TestType.Static)) {
            log.debug("Commencing static tests");
            await exec(`${shellDir}/test/initialize-dependencies-static-python.sh ${taskProps["language.version"]} ${JSON.stringify(taskProps["global/pypi.registry.host"])} ${taskProps["global/pypi.repo.id"]} ${taskProps["global/pypi.repo.user"]} ${taskProps["global/pypi.repo.password"]}`);
            await exec(`${shellDir}/test/static-python.sh ${taskProps["build.tool"]} ${taskProps["version.name"]} ${taskProps["global/sonar.url"]} ${taskProps["global/sonar.api.key"]} ${taskProps["system.component.id"]} ${taskProps["system.component.name"]}`);
          }
          if (testTypes.includes(TestType.Unit)) {
            log.debug("Unit tests not implemented");
          }
          if (testTypes.includes(TestType.Security)) {
            log.debug("Security tests not implemented");
          }
        } else if (componentMode === ComponentMode.Helm) {
          if (testTypes.includes(TestType.Static)) {
            log.debug("Linting Helm Chart(s)");
            await exec(`${shellDir}/test/lint-helm.sh ${taskProps["global/helm.repo.url"]} ${taskProps["helm.chart.directory"]} ${taskProps["helm.chart.ignore"]}`);
          }
        }
      }
    } catch (e) {
      log.err(`  Error encountered. Code: ${e.code}, Message: ${e.message}`);
      process.exit(1);
    } finally {
      await exec(`${shellDir}/common/footer.sh`);
      log.debug("Finished CICD Test Activity");
    }
  }
};
