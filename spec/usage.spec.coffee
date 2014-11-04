#     it "gives usage information when no params are given", ->
#       @createRun = new CommandRunner
#         cmd: TestHelper.steroidsBinPath
#         args: ["create"]
#
#       runs ()=>
#         @createRun.run()
#
#       runs ()=>
#         expect( @createRun.code ).toBe(1)
#         expect( @createRun.stdout ).toMatch /Usage: steroids create <directoryName>/


#   describe 'create', ->
#     it "prints usage instructions when no parameters", ->
#       @testHelper.createProjectSync()
#
#       cmd = @testHelper.runInProjectSync "generate",
#         args: []
#
#       runs ()=>
#         expect( cmd.stdout ).toMatch(/Usage: steroids generate ng-resource/)
#
