sbawn = require "../sbawn"

class Genymotion
  StoppedError: class StoppedError extends steroidsCli.SteroidsError
  NotInstalledError: class NotInstalledError extends steroidsCli.SteroidsError

  constructor: ->
    paths = require "../paths"
    @apkPath = paths.emulate.android.debug
    @genyPaths = Genymotion.paths()

    @applicationPackage = "com.appgyver.runtime.scanner.steroidscli"
    @applicationActivity = "com.appgyver.runtime.scanner.steroidscli.MainActivity"

    @vmName = "steroids"
    @running = false

  @paths: ->
    path = require "path"
    fs = require "fs"

    if steroidsCli.host.os.isWindows()
      genymotionHome = process.env.GENYMOTION_HOME ? path.join "C:", "Program Files", "Genymobile", "Genymotion"

      base = path.join genymotionHome
      player = path.join genymotionHome, "player"
      shell = path.join genymotionHome, "genyshell"

    else if steroidsCli.host.os.isOSX()
      genymotionHome = process.env.GENYMOTION_HOME ? path.join "/Applications", "Genymotion.app"
      genmotionShell = process.env.GENYMOTION_SHELL ? path.join "/Applications", "Genymotion Shell.app"

      base = path.join genymotionHome, "Contents", "MacOS"
      player = path.join genymotionHome, "Contents", "MacOS", "player"
      shell = path.join genmotionShell, "Contents", "MacOS", "genyshell"

    else if steroidsCli.host.os.isLinux()
      # TODO: Set default paths
      genymotionHome = process.env.GENYMOTION_HOME ? ""
      genmotionShell = process.env.GENYMOTION_SHELL ? ""

      base = path.join genymotionHome, "bin"
      player = path.join genymotionHome, "bin", "player"
      shell = path.join genmotionShell, "bin", "genyshell"

    geny =
      base: base
      player: player
      shell: shell
      adb: path.join base, "tools", "adb"

    return undefined for _, genyPath of geny when not fs.existsSync genyPath
    return geny

  run: (opts = {}) =>
    new Promise (resolve, reject) =>
      if steroidsCli.globals.genymotion?.running
        steroidsCli.debug "GENYMOTION", "previous genymotion found that is running, trying to stop it"

        steroidsCli.globals.genymotion.stop().then =>
          @killall()
          .then(@start).catch (error) =>
            reject error
          .then =>
            resolve()

      else
        @start().catch (error) =>
          reject error
        .then =>
          resolve()

  start: (opts = {}) =>
    new Promise (resolve, reject) =>
      steroidsCli.debug "GENYMOTION", "running, becoming the global genymotion"
      @running = true

      steroidsCli.globals.genymotion = @

      @killall()
      .then(@ensurePlayer)
      .then(@startPlayer)
      .then(@uninstallApplication)
      .then(@installApk)
      .then(@startApplication)
      .then(@unlockDevice)
      .then(@stop)
      .catch StoppedError, (err) =>
        0 # nop
      .catch (err) =>
        reject err
        @stop()
      .then =>
        resolve()

  startPlayer: (opts = {}) =>
    new Promise (resolve, reject) =>
      unless @running
        reject new StoppedError
        return

      unless @genyPaths?
        reject new NotInstalledError "Could not detect Genymotion application"
        return

      steroidsCli.log "Starting Genymotion Emulator. Please wait for Scanner to load..."
      steroidsCli.debug "GENYMOTION", "starting player"

      cmd = @genyPaths.player
      args = ["--vm-name", @vmName]

      @genymotionPlayerSession = sbawn
        cmd: cmd
        args: args

      @genymotionPlayerSession.on "exit", =>
        reject new Error "Could not start a virtual device named steroids"


      @waitForDevice()
      .then(resolve)
      .catch (err) ->
        reject err

  waitForDevice: (opts = {}) ->
    new Promise (resolve, reject) =>
      unless @running
        reject new StoppedError
        return

      steroidsCli.debug "GENYMOTION", "waiting for device to appear"

      cmd = @genyPaths.adb
      args = ["devices", "-l"]

      @deviceListSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout else false
        stderr: if opts.stderr? then opts.stderr else false

      @deviceListSession.on "exit", =>
        if @deviceListSession.stdout.match "model:steroids"
          steroidsCli.debug "GENYMOTION", "device found"
          resolve()
        else
          steroidsCli.debug "GENYMOTION", "device not found, retrying"

          setTimeout =>
            @waitForDevice()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000

  uninstallApplication: (opts = {}) =>
    new Promise (resolve, reject) =>
      unless @running
        reject new StoppedError
        return

      steroidsCli.debug "GENYMOTION", "uninstalling application"

      cmd = @genyPaths.adb
      args = ["uninstall", @applicationPackage]

      @uninstallSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout else false
        stderr: if opts.stderr? then opts.stderr else false

      @uninstallSession.on "exit", =>

        if @uninstallSession.stdout.match "Success"
          steroidsCli.debug "GENYMOTION", "uninstall success, continue"
          resolve()
        else if @uninstallSession.stdout.match "Failure"
          steroidsCli.debug "GENYMOTION", "uninstall failure, continue"
          resolve()
        else
          steroidsCli.debug "GENYMOTION", "uninstall not possible yet, retrying"
          setTimeout =>
            @uninstallApplication()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000

  installApk: (opts = {}) =>
    new Promise (resolve, reject) =>
      unless @running
        reject new StoppedError
        return

      steroidsCli.debug "GENYMOTION", "installing APK #{@apkPath}"
      cmd = @genyPaths.adb
      args = ["install", @apkPath]

      @installSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout  else false
        stderr: if opts.stderr? then opts.stderr else false

      @installSession.on "exit", =>

        if @installSession.stdout.match "Is the system running?"
          steroidsCli.debug "GENYMOTION", "system not running yet, retrying"

          setTimeout =>
            @installApk()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000

        else if @installSession.stdout.match "protocol failure"
          steroidsCli.debug "GENYMOTION", "protocol failure"
          setTimeout =>
            @installApk()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000
        else if @installSession.stdout.match "daemon not running. starting it now on port"
          setTimeout =>
            @installApk()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000
        else if @installSession.stdout.match "INSTALL_FAILED_ALREADY_EXISTS"
          steroidsCli.debug "GENYMOTION", "installed failed because already exists, uninstalling again"
          @uninstallApplication()
          .then(@installApk)
          .then(resolve)
        else if @installSession.stdout.match "INSTALL_FAILED_INVALID_APK"
          steroidsCli.debug "GENYMOTION", "installed failed because invalid apk, uninstalling again"
          @uninstallApplication()
          .then(@installApk)
          .then(resolve)
        else if @installSession.stdout.match "INSTALL_FAILED_INVALID_URI"
          steroidsCli.debug "GENYMOTION", "installed failed because invalid URI, uninstalling again"
          @uninstallApplication()
          .then(@installApk)
          .then(resolve)
        else if @installSession.stdout.match "rm failed for /data/local/tmp/"
          steroidsCli.debug "GENYMOTION", "installed failed on /data/local/tmp/*.apk failure, uninstalling again"
          @uninstallApplication()
          .then(@installApk)
          .then(resolve)
        else if @installSession.stdout.match "Success"
          steroidsCli.debug "GENYMOTION", "installed"
          resolve()
        else
          steroidsCli.debug "GENYMOTION", "Unknown error:"
          steroidsCli.debug "GENYMOTION", @installSession.stdout

          reject new Error "Install failed"

  startApplication: (opts = {}) =>
    new Promise (resolve, reject) =>
      unless @running
        reject new StoppedError
        return

      steroidsCli.debug "GENYMOTION", "starting application"

      ips = steroidsCli.server.ipAddresses()
      port = steroidsCli.server.port
      encodedJSONIPs = encodeURIComponent(JSON.stringify(ips))

      launchUrl = "appgyver://?ips=#{encodedJSONIPs}\&port=#{port}"
      steroidsCli.debug "GENYMOTION", "starting application with launchUrl: '#{launchUrl}'"

      cmd = @genyPaths.adb
      args = ["shell", "am start '#{launchUrl}'"]

      steroidsCli.debug "GENYMOTION", "Running #{cmd} with args: #{args}"
      @startSession = sbawn
        cmd: cmd
        args: args
        debug: steroidsCli.debugEnabled
        stdout: if opts.stdout? then opts.stdout else false
        stderr: if opts.stderr? then opts.stderr else false

      @startSession.on "exit", =>
        if @startSession.stdout.match "Starting: Intent"
          steroidsCli.debug "GENYMOTION", "started application"
          resolve()
        else
          steroidsCli.debug "GENYMOTION", "retrying application start.."
          setTimeout =>
            @startApplication()
            .then(resolve)
            .catch (err) ->
              reject err #perkele
          , 1000

  unlockDevice: (opts = {}) =>
    new Promise (resolve, reject) =>
      unless @running
        reject new StoppedError
        return

      steroidsCli.debug "GENYMOTION", "unlocking device"

      cmd = @genyPaths.adb
      args = ["shell", "input", "keyevent", "82"]

      @unlockSession = sbawn
        cmd: cmd
        args: args
        stdout: if opts.stdout? then opts.stdout else false
        stderr: if opts.stderr? then opts.stderr else false

      @unlockSession.on "exit", =>
        steroidsCli.debug "GENYMOTION", "unlock exit code: #{@unlockSession.code}"
        resolve()

  stop: () =>
    new Promise (resolve, reject) =>
      if @running
        steroidsCli.debug "GENYMOTION", "stop called"
        @running = false

      resolve()

  killall: =>
    new Promise (resolve) ->

      if steroidsCli.host.os.isOSX() or steroidsCli.host.os.isLinux()
        killGenymotion = sbawn
          cmd: "/usr/bin/pkill"
          args: ["-9", "player"]

        killGenymotion.on "exit", ->
          setTimeout resolve, 500
      else
       resolve()

module.exports = Genymotion
