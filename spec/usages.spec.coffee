TestHelper = require "./test_helper"

describe 'usages', ->

  describe 'steroids', ->
    it "gives usage information when no params are given", ->
      session = TestHelper.run
        args: [""]

      runs =>
        expect( session.stdout ).toMatch("Creates a new application from the default template")

    #TODO: acually old usage
    it "gives usage an extended information with --help", ->
      session = TestHelper.run
        args: ["--help"]

      runs =>
        expect( session.stdout ).toMatch("xtended usage information")

  describe 'create', ->
    it "gives usage information when no params are given", ->
      session = TestHelper.run
        args: ["create"]

      runs =>
        expect( session.stdout ).toMatch(/Usage: steroids create <directoryName>/)

  describe 'generate', ->

    beforeEach =>
      @testHelper = new TestHelper
      @testHelper.prepare()

    it "gives usage information when no params are given", =>

      session = @testHelper.runInProject
        args: ["generate"]

      runs =>
        expect( session.stdout ).toMatch(/Usage: steroids generate module <moduleName>/)
