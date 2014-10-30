class ChromeDebug

  run: (opts = {}) ->
    new Promise (resolve, reject) ->
      unless steroidsCli.host.os.isOSX()
        reject new steroidsCli.PlatformError
        return

      Paths = require "./../paths"
      sbawn = require "../sbawn"

      chromeCliSession = sbawn
        cmd: Paths.chromeCli.path
        args: ["open", "chrome://inspect"]
        stdout: false

      chromeCliSession.on "exit", ->
        if chromeCliSession.stdout?.match "Loading: Yes"
          resolve()
        else
          reject()

module.exports = ChromeDebug
