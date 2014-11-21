Help = require "./Help"
paths = require "./paths"
Grunt = require "./Grunt"
Project = require "./Project"

chalk = require "chalk"


class Prompt

  prompt: null

  constructor: (@options) ->
    @prompt = require('prompt')

    @prompt.message = "#{chalk.cyan("AppGyver")} #{chalk.magenta("Steroids")}"
    @prompt.delimiter = " "

    @prompt.start();
    @buildServer = @options.buildServer

  refresh: () =>
    process.stdout.write @prompt.message + @prompt.delimiter + chalk.grey("command  ")

  cleanUp: () =>
    console.log "Shutting down Steroids ..."
    console.log "... done."

  connectLoop: =>
    onInput = (err, result) =>
      skipLoop = false

      command = if result? and result.command?
        result.command
      else
        "quit"

      [mainCommand, commandOptions...] = command.split(' ')

      switch mainCommand
        when "quit", "exit", "q"
          @cleanUp()
          console.log "Bye"
          process.exit(0)

        when "", "push"
          project = new Project
          project.make
            onSuccess: =>
              project.package
                onSuccess: =>
                  steroidsCli.log
                    message: "Restarting all connected devices ..."
                    refresh: true

        when "sd", "safari"
          SafariDebug = require "./SafariDebug"
          safariDebug = new SafariDebug => @connectLoop()
          if commandOptions[0]?
            safariDebug.open(commandOptions[0])
          else
            safariDebug.listViews()
          return # Exit now and later let the callback passed to SafarDebug's constructor re-enter the loop once its methods exit.

        when "cd", "chrome"
          ChromeDebug = require "./debug/chrome"
          chromeDebug = new ChromeDebug
          chromeDebug.run()

        when "a", "and", "android"
          Android = require "./emulate/android"
          android = new Android
          android.run().catch (error) ->
            Help.error()
            steroidsCli.log
              message: error.message

        when "g", "gen", "genymotion"
          Genymotion = require "./emulate/genymotion"
          genymotion = new Genymotion

          device = commandOptions[0] if commandOptions[0]

          genymotion.run(
            device: device
          ).catch (error) ->
            Help.error()
            steroidsCli.log
              message: error.message

        when "s", "sim", "simulator"
          Simulator = require "./Simulator"
          simulator = new Simulator()

          device = if commandOptions[0]
            commandOptions[0]
          else if steroidsCli.options.argv.device
            steroidsCli.options.argv.deviceType

          simulator.run(
            device: device
          ).catch (error) ->
            Help.error()
            steroidsCli.log
              message: error.message

        when "conn", "c", "qr"
          QRCode = require "./QRCode"
          QRCode.showLocal
            port: @buildServer.port

        when "e", "edit"
          unless process.env.EDITOR?
            steroidsCli.log "EDITOR environment variable not set"
          else
            sbawn = require "./sbawn"
            editor = sbawn
              cmd: process.env.EDITOR
              args: [paths.applicationDir]

        when "h", "help", "?", "usage"
          Help.connect()

        when "$", "§"
          skipLoop = true

          cmd = commandOptions[0]
          args = commandOptions.splice(1)

          sbawn = require "./sbawn"

          cmd = sbawn
            cmd: cmd
            args: args
            cwd: paths.applicationDir
            stdout: true
            stderr: true
            onExit: =>
              console.log ""
              setTimeout =>
                @connectLoop()
              , 10

        else
          steroidsCli.log "Unknown command: #{mainCommand}, did you mean:\n\t$ #{mainCommand} #{commandOptions.join(' ')}"
      unless skipLoop
        @connectLoop()

    @get
      onInput: onInput



  get: (options)->
    @prompt.get
      properties:
        command:
          message: ""
    , (options.onInput ? @options.onInput?)



module.exports = Prompt
