paths = require "./paths"
path = require "path"
sbawn = require("./sbawn")
chalk = require "chalk"

Help = require "./Help"

os = require "os"

class SafariDebug
  SafariDebugError: class SafariDebugError extends steroidsCli.SteroidsError

  constructor: (@callBackOnExit) ->  # @callBackOnExit is invoked when this class' methods exit - typically used to redisplay the interactive prompt.

  run: (options={}) =>
    new Promise (resolve, reject) =>
      unless steroidsCli.host.os.isOSX()
        reject new steroidsCli.PlatformError
        return

      if options.path
        @open(options.path)
      else
        console.log "Fetching location paths from Safari:\n"
        @callBackOnExit = ->
          console.log "Use path with --location=<part of the location path>"

        @listViews()

      resolve()

  listViews: ()=>
    new Promise (resolve, reject) =>
      unless steroidsCli.host.os.isOSX()
        reject new steroidsCli.PlatformError
        return

      getViews = if steroidsCli.host.os.osx.isYosemite()
        @runJavaScript "yosemite-safari.js", ["safari", "listviews"]
      else
        @runAppleScript "SafariDebugWebViewLister.scpt"

      getViews.then (viewList) =>
        resolve viewList
      .catch (error) =>
        reject error

  open: (argument) =>
    new Promise (resolve, reject) =>
      unless steroidsCli.host.os.isOSX()
        reject new steroidsCli.PlatformError
        return

      @runAppleScript("openSafariDevMenu.scpt", argument).then ->
        resolve()
      .catch (error) ->
        reject error

  runJavaScript: (scriptFileName, argument) =>
    new Promise (resolve, reject) =>
      views = []
      @ensureAssistiveAccess().then( =>
        scriptPath = path.join paths.scriptsDir, scriptFileName

        args = if argument?
          [scriptPath].concat argument
        else
          [scriptPath]

        session = sbawn
          cmd: "osascript"
          args: args

        session.on "exit", () =>
          steroidsCli.debug "SafariDebug started and killed."
          steroidsCli.debug "stderr: " + session.stderr
          steroidsCli.debug "stdout: " + session.stdout

          if session.code  # error occurred
            errMsg = 'ERROR: ' + (/\ execution error: ([\s\S]+)$/.exec(session.stderr)?[1] || session.stderr)
            console.error errMsg
            reject new SafariDebugError errMsg
          else
            for line in session.stderr.split("\n") when line isnt ""
              views.push line
              console.log line
            console.log ''
          resolve views
          @callBackOnExit?()

      ).catch (errMsg) =>
        console.error chalk.red errMsg
        reject errMsg
        @callBackOnExit?()

  runAppleScript: (scriptFileName, argument)=>
    new Promise (resolve, reject) =>
      @ensureAssistiveAccess().then( =>
        views = []
        scriptPath = path.join paths.scriptsDir, scriptFileName

        args = [scriptPath]
        if argument?
          args.push argument

        osascriptSbawn = sbawn
          cmd: "osascript"
          args: args

        osascriptSbawn.on "exit", () =>
          steroidsCli.debug "SafariDebug started and killed."
          steroidsCli.debug "stderr: " + osascriptSbawn.stderr
          steroidsCli.debug "stdout: " + osascriptSbawn.stdout

          if osascriptSbawn.code  # error occurred
            errMsg = 'ERROR: ' + (/\ execution error: ([\s\S]+)$/.exec(osascriptSbawn.stderr)?[1] || osascriptSbawn.stderr)
            console.error errMsg
            reject new SafariDebugError errMsg
          else unless argument?

            for line in osascriptSbawn.stdout.split("\n") when line isnt ""
              views.push line
              console.log line
            console.log ''

          resolve views
          @callBackOnExit?()

      ).catch (errMsg) =>
        console.error chalk.red errMsg
        reject errMsg
        @callBackOnExit?()

  ensureAssistiveAccess: =>
    new Promise (resolve, reject) ->
      scriptPath = path.join paths.scriptsDir, "ensureAssistiveAccess.scpt"

      ensureAssistiveAccessSbawn = sbawn
        cmd: "osascript"
        args: [scriptPath]

      ensureAssistiveAccessSbawn.on "exit", () =>
        steroidsCli.debug "Ensure assistive access started and killed"

        if ensureAssistiveAccessSbawn.code
          errMsg = '\nERROR: ' + (/\ execution error: ([\s\S]+)$/.exec(ensureAssistiveAccessSbawn.stderr)?[1] || ensureAssistiveAccessSbawn.stderr)
          reject new SafariDebugError errMsg
        else
          resolve()

module.exports = SafariDebug
