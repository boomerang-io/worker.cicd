const { log, utils, CICDError } = require("@boomerang-io/worker-core");
const shell = require("shelljs");

function exec(command) {
  return new Promise(function(resolve, reject) {
    log.debug("Command directory:", shell.pwd().toString());
    log.debug("Command to execute:", command);
    shell.exec(command, { verbose: true }, function(code, stdout, stderr) {
      if (code) {
        reject(new CICDError(code, stderr));
      }
      resolve(stdout ? stdout : stderr);
    });
  });
}

module.exports = {
  async clone() {
    log.sys("Starting Git Clone task...");

    //Destructure and get properties ready.
    const taskProps = utils.resolveInputParameters();
    // Do we need to destructure or use the alternate object retrieve
    // const { "version.name": versionName = '0.0.0', script } = taskProps;
    const shellDir = "/cli/scripts";
    // const shellDir = "./commands";
    // log.debug("  Version:", taskProps["version-name"]);
    // log.debug("  repoURL:", taskProps["repoUrl"]);

    try {
      //   if (taskProps["build-number-append"] === false) {
      //     log.sys("Stripping build number from version...");
      //     taskProps["version-name"] = taskProps["version-name"].substr(0, taskProps["version-name"].lastIndexOf("-"));
      //     log.debug("  Version:", taskProps["version-name"]);
      //   }

      log.ci("Retrieving Source Code...");
      await exec(
        shellDir +
          '/common/git-clone.sh "' +
          utils.resolveInputParameters("privateKey") +
          '" "' +
          JSON.stringify(utils.resolveInputParameters("repoSshUrl")) +
          '" "' +
          JSON.stringify(utils.resolveInputParameters("repoUrl")) +
          '" "' +
          utils.resolveInputParameters("commitId") +
          '" "' +
          utils.resolveInputParameters("lfsEnabled") +
          '"'
      );

      log.sys("Finished Git Clone task...");
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      log.debug("Finished CICD Build Activity");
    }
  }
};
