TestHelper = require "./test_helper"

describe 'Steroids Cli', ->

  beforeEach ->
    @testHelper = new TestHelper

    @testHelper.bootstrap()
    @testHelper.changeToWorkingDirectory()

  afterEach ->
    @testHelper.cleanUp()


  describe 'without being in steroids project directory', ->

    it "gives error if command requires to be run in project directory", ->

      commandsThatRequireSteroidsProject = ["push", "make", "package", "debug", "emulate", "connect", "update", "generate", "deploy"]

      for command in commandsThatRequireSteroidsProject
        do (command) ->

          requireRun = new TestHelper.CommandRunner
            cmd: TestHelper.steroidsBinPath
            args: [command]

          requireRun.run()

          runs ->
            expect( requireRun.code ).toBe(1)

            expect( requireRun.stdout ).toMatch /requires to be run in a Steroids project directory./
