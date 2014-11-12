TestHelper = require "../test_helper"

describe 'packager', ->

  beforeEach =>
    @testHelper = new TestHelper
    @testHelper.prepare()

  describe 'zip', =>

    it 'should be created', =>
      # TODO: this shouldn't be required
      @testHelper.runInProject
        args: ["update"]

      # TODO: this shouldn't be required
      runs =>
        @testHelper.runInProject
          args: ["make"]

      runs =>
        @testHelper.runInProject
          args: ["package"]

      runs =>
        Paths = require "../../src/steroids/paths"
        fs = require "fs"

        expect(fs.existsSync Paths.temporaryZip).toBe true
