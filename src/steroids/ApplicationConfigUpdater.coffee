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
