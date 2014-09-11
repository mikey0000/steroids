semver = require "semver"
rimraf = require "rimraf"
path = require "path"
fs = require "fs"

paths = require "./paths"
sbawn = require "./sbawn"

events = require "events"
Q = require "q"
chalk = require "chalk"
Help = require "./Help"
inquirer = require "inquirer"

class ApplicationConfigUpdater extends events.EventEmitter

  validateSteroidsEngineVersion: (versionNumber)->
    semver.satisfies @getSteroidsEngineVersion(), versionNumber

  getSteroidsEngineVersion: ->
    packageJson = if fs.existsSync paths.application.configs.packageJson
      packageJsonContents = fs.readFileSync paths.application.configs.packageJson, 'utf-8'
      JSON.parse packageJsonContents

    packageJson?.engines?.steroids

  updateTo3_1_9: ->
    deferred = Q.defer()

    if @validateSteroidsEngineVersion(">=3.1.9")
      deferred.resolve()
    else
      steroidsEngineVersion = @getSteroidsEngineVersion() || "undefined"
      Help.attention()
      console.log(
        """
        #{chalk.bold("engine.steroids")} was #{chalk.bold(steroidsEngineVersion)} in #{chalk.bold("package.json")}, expected #{chalk.bold(">=3.1.9")}

        This is likely because your project was created with an older version of Steroids CLI. We will
        now run through a few migration tasks to ensure that your project functions correctly.

        """
      )

      promptConfirm().then( =>
        @updateTo3_1_0()
      ).then( =>
        @updateTo3_1_4()
      ).then( =>
        @ensurePackageJsonExists()
      ).then( =>
        @ensureNoBadGruntDeps()
      ).then( =>
        @ensureSteroidsEngineIsDefinedWithVersion("3.1.9")
      ).then( =>
        Help.SUCCESS()
        console.log chalk.green("Migration successful, moving on!")
        deferred.resolve()
      ).fail (msg)->
        msg = msg ||
          """
          \n#{chalk.bold.red("Migration aborted")}
          #{chalk.bold.red("=================")}

          Please read through the instructions again!

          """
        deferred.reject(msg)

    return deferred.promise

  ensurePackageJsonExists: ->
    deferred = Q.defer()

    console.log("Checking to see if #{chalk.bold("package.json")} exists in project root...")

    if fs.existsSync paths.application.configs.packageJson
      console.log chalk.green("OK!")
      deferred.resolve()
    else
      console.log(
        """
          \n#{chalk.red.bold("Could not find package.json in project root")}
          #{chalk.red.bold("===========================================")}

          We could not find a #{chalk.bold("package.json")} file in project root. This is required
          for project npm dependencies and the #{chalk.bold("engines.steroids")} field.

          We will create the file now.

        """
      )

      promptConfirm().then( ->
        console.log("\nCreating #{chalk.bold("package.json")} in project root...")
        fs.writeFileSync paths.application.configs.packageJson, fs.readFileSync(paths.templates.packageJson)
        console.log("#{chalk.green("OK!")}")
        deferred.resolve()
      ).fail ->
        deferred.reject()

    return deferred.promise

  ensureSteroidsEngineIsDefinedWithVersion: (version)->
    deferred = Q.defer()

    if @validateSteroidsEngineVersion(version)
      console.log("\n#{chalk.bold("engine.steroids")} in #{chalk.bold("package.json")} is #{chalk.bold(version)}, moving on!")
      deferred.resolve()
    else
      console.log("Setting #{chalk.bold("engine.steroids")} in #{chalk.bold("package.json")} to #{chalk.bold(version)}...")
      if fs.existsSync paths.application.configs.packageJson
        packageJsonData = fs.readFileSync paths.application.configs.packageJson, 'utf-8'
        packageJson = JSON.parse(packageJsonData)

        if !packageJson.engines?
          packageJson.engines = { steroids: version }
        else
          packageJson.engines.steroids = version

        packageJsonData = JSON.stringify packageJson, null, 2
        fs.writeFileSync paths.application.configs.packageJson, packageJsonData
        console.log chalk.green("OK!")
        deferred.resolve()
      else
        deferred.reject()

    return deferred.promise

  ensureNodeModulesDir: ->
    deferred = Q.defer()

    if !fs.existsSync(paths.application.nodeModulesDir)
      msg =
        """
        \n#{chalk.bold.red("node_modules directory not found")}
        #{chalk.bold.red("================================")}

        Directory #{chalk.bold("node_modules")} not found in project root. Steroid requires
        certain npm dependencies to work. Please run

          #{chalk.bold("steroids update")}

        in your project root now to install the required dependencies.

        """
      deferred.reject(msg)
    else
      deferred.resolve()

    return deferred.promise

  addGruntSteroidsDependency: ->
    deferred = Q.defer()

    console.log("Adding #{chalk.bold("grunt-steroids")} devDependency to #{chalk.bold("package.json")}...")

    packageJsonData = fs.readFileSync paths.application.configs.packageJson, 'utf-8'
    packageJson = JSON.parse(packageJsonData)

    if packageJson.devDependencies?
      packageJson.devDependencies["grunt-steroids"] = "0.x"
    else
      packageJson["devDependencies"] =
        "grunt-steroids":"0.x"

    packageJsonData = JSON.stringify packageJson, null, 2
    fs.writeFileSync paths.application.configs.packageJson, packageJsonData

    console.log chalk.green("OK!")

    deferred.resolve()

    return deferred.promise

  ensureNoBadGruntDeps: ->
    deferred = Q.defer()

    console.log "Checking for erroneous npm dependencies..."

    packageJsonData = fs.readFileSync paths.application.configs.packageJson, 'utf-8'
    packageJson = JSON.parse(packageJsonData)

    if (packageJson?.devDependencies?["grunt-extend-config"]? ||
       packageJson?.devDependencies?["grunt-contrib-clean"]? ||
       packageJson?.devDependencies?["grunt-contrib-concat"]? ||
       packageJson?.devDependencies?["grunt-contrib-copy"]? ||
       packageJson?.devDependencies?["grunt-contrib-sass"]? ||
       packageJson?.devDependencies?["grunt-contrib-coffee"]? ||
       packageJson?.devDependencies?["grunt"]?)

      Help.error()
      console.log(
        """
        #{chalk.red.bold("Erroneous npm dependencies found")}
        #{chalk.red.bold("================================")}

        Due to an oversight in our previous migration script, migrated projects' #{chalk.bold("package.json")}
        files ended up having several #{chalk.bold("devDependencies")} that should not be there.

        The misplaced dependencies cause errors if the user removes his #{chalk.bold("node_modules")} directory
        and then runs #{chalk.bold("npm install")} afterwards (this is due to #{chalk.bold("grunt-steroids")} using absolute
        version numbers for its peerDependencies, and npm wanting to use the latest patch
        version).

        Unless you know what you're doing, ensure that your #{chalk.bold("package.json")} has none of the
        following #{chalk.bold("devDependencies")} by deleting them from the file:

          "grunt-extend-config"
          "grunt-contrib-clean"
          "grunt-contrib-concat"
          "grunt-contrib-copy"
          "grunt-contrib-sass"
          "grunt-contrib-coffee"
          "grunt"

        Note that you shouldn't remove the #{chalk.bold("grunt-steroids")} dependency, as that's required by
        Steroids CLI to work!

        """
      )

      promptUnderstood().then( ->
        deferred.resolve()
      ).fail ->
        deferred.reject()

    else
      console.log chalk.green("OK!")
      deferred.resolve()

    return deferred.promise

  # Inquirer utils

  promptConfirm = ->
    prompt "confirm", "Can we go ahead?", true

  promptUnderstood = ->
    prompt "input", "Write here with uppercase letters #{chalk.bold("I UNDERSTAND THIS")}", "I UNDERSTAND THIS"

  promptRunNpmInstall = ->
    prompt "input", "Write #{chalk.bold("npm install grunt-steroids --save-dev")} to continue", "npm install grunt-steroids --save-dev"

  prompt = (type, message, answer) ->
    deferred = Q.defer()

    inquirer.prompt [
        {
          type: type
          name: "userAnswer"
          message: message
        }
      ], (answers) ->
        if answers.userAnswer is answer
          deferred.resolve()
        else
          deferred.reject()

    return deferred.promise

module.exports = ApplicationConfigUpdater
