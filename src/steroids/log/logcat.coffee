class LogCat

  constructor: (@options={}) ->
    @options.lines ||= 1000000
    @options.match ||= "com\.appgyver\."

  run: (options={}) =>

    paths = require "../paths"

    new Promise (resolve, reject) =>
      sbawn = require "../sbawn"

      args = ["logcat"]
      debug = false

      if options.tail
        debug = true
      else
        args.push "-t #{@options.lines}"
        args.push "-d"

      args.push "*:V"

      session = sbawn
        cmd: paths.android.adb
        args: args
        debug: debug

      session.on "exit", =>
        return resolve() if options.tail

        lines = session.stdout.split("\n")
        ourLines = []
        for line in lines
          do (line) =>
            ourLines.push(line) if line.match(@options.match)

        resolve(ourLines)



module.exports = LogCat
