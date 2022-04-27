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
  async clone() {
    log.sys("Starting Git Clone task...");

    //Destructure and get properties ready.
    const taskParams = utils.resolveInputParameters();
    // Do we need to destructure or use the alternate object retrieve
    // const { "version.name": versionName = '0.0.0', script } = taskProps;
    const shellDir = "/cli/scripts";

    // let dir = "/workspace/" + taskParams["workflow-activity-id"];
    let dir = workingDir(taskParams["workingDir"]);
    let repoDir = dir + "/repository";

    try {
      log.ci("Retrieving Source Code");
      await exec(`${shellDir}/common/git-clone.sh "${repoDir}" "${taskParams["privateKey"]}" ${JSON.stringify(taskParams["repoSshUrl"])} ${JSON.stringify(taskParams["repoUrl"])} ${taskParams["commitId"]} ${taskParams["lfsEnabled"]}`);

      log.sys("Finished Git Clone task...");
    } catch (e) {
      log.err("  Error encountered. Code: " + e.code + ", Message:", e.message);
      process.exit(1);
    } finally {
      log.debug("Finished CICD Build Activity");
    }
  }
};
