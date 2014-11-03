TestHelper = require "./test_helper"

describe 'Steroids Cli', ->

  describe 'without being in steroids project directory', =>

    it "gives error if command requires to be run in project directory", =>
      commandsThatRequireSteroidsProject = [
        "push"
        "make"
        "package"
        "debug"
        "emulate"
        "connect"
        "update"
        "generate"
        "deploy"
      ]

      for command in commandsThatRequireSteroidsProject
        do (command) ->

          session = TestHelper.run
            args: [command]

          session.run()

          runs ->
            expect( session.code ).toBe(1)
            expect( session.stdout ).toMatch /requires to be run in a Steroids project directory./


  describe 'when in a steroids project directory', =>

    beforeEach =>
      @testHelper = new TestHelper
      @testHelper.prepare()

    it "should run the commands", =>
      for command in [
        "debug"
        "emulate"
      ]
        do (command) =>

          session = @testHelper.runInProject
            args: [command]

          runs ->
            expect( session.code ).toBe(0)
