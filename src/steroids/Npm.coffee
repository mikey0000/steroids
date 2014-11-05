chalk = require "chalk"

class Npm

  install: (args)->
    new Promise (resolve, reject) ->
      if args?
        argsString = args.join(" ")
        console.log(
          """
          \n#{chalk.bold.green("Installing npm package")}
          #{chalk.bold.green("======================")}

          Running #{chalk.bold("npm install #{argsString}")} to install a project dependency...
          If this fails, try running the command manually in the project directory.
          """
        )
      else
        console.log(
          """
          \n#{chalk.bold.green("Installing npm dependencies")}
          #{chalk.bold.green("===========================")}

          Running #{chalk.bold("npm install")} to install project npm dependencies...
          If this fails, try running the command manually.

          """
        )
      argsToRun = ["install"]

      if args?
        argsToRun = argsToRun.concat(args)

      sbawn = require "./sbawn"
      npmRun = sbawn
        cmd: "npm"
        args: argsToRun
        appendNode: false
        stdout: true
        stderr: true

      npmRun.on "exit", =>
        if npmRun.code != 0
          reject new Error "#{chalk.bold("npm install")} returned a non 0 exit code, try running the command manually"

        resolve()

module.exports = Npm
