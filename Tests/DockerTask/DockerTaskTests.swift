import XCTest
@testable import DockerTask

class DockerTaskTests: XCTestCase {
    //let containerName = ProcessInfo.processInfo.environment["DOCKER_CONTAINER_NAME"] ?? ProcessInfo.processInfo.environment["PROJECT"]
    let imageName = "saltzmanjoelh/swiftubuntu"
    let command = ["/bin/bash", "-c", "whoami"]
    
//    override func setUp(){
//        continueAfterFailure = false
//        recordFailure(withDescription: "Forced Failure", inFile: String(#file), atLine: 19, expected: true)
//    }
    
    func testContainerNameOption() {
        let name = UUID()
        let command = ["whoami"]
        
        do {
            let result = try DockerTask.run(options: ["--name", String(name)], imageName: imageName, commandArgs:command)
            
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertEqual(result.error, "")
            XCTAssertNotNil(result.output)
            
        }catch let e {
            XCTFail("\(e)")
        }
        
        
    }
    func testDeleteExistingContainer(){
        var containerName = #function
        let range = containerName.index(containerName.endIndex, offsetBy: -2)..<containerName.endIndex
        containerName.removeSubrange(range)
        
        do{
            //don't use run to create the existing container, .run with delete it
            try DockerTask(command:"run", commandOptions:["--name", containerName], imageName:imageName, commandArgs:command).launch()
            
            //Now when we create it, the existing one should be deleted
            let result = try DockerTask.run(options: ["--name", containerName], imageName: imageName, commandArgs:command)
            
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertEqual(result.error, "")
            XCTAssertNotNil(result.output)
        }catch let e {
            XCTFail("\(e)")
        }
    }
    
    func testDoesRunInDocker(){
        let result = runTask(launchPath: "/bin/hostname", launchArguments: nil, environment: nil)
        let osxHostName = result.output.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
        do {
            let answer = "different hostname"
            let hostNameCommand = "[ `hostname` != \(osxHostName) ] && echo \"\(answer)\""
            let linuxResult = try DockerTask.run(options: ["--name", String(UUID()), "--rm"], imageName: imageName, commandArgs: ["/bin/bash", "-c", hostNameCommand])
            
            XCTAssertEqual(linuxResult.output.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet), answer)
            XCTAssertEqual(linuxResult.exitCode, 0)
        }catch let e{
            print("Exception: \(e)")
        }
    }

    private func runTask(launchPath:String, launchArguments:[String]?, environment:[String:String]?) -> (output: String, error: String, exitCode: Int32) {
        
        let task = Task()
        task.launchPath = launchPath
        if environment != nil {
            task.environment = environment
        }
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        task.launch()
        
        var output = String()
        var error = String()
        while(task.isRunning){
            if let outputString = String(data:outputPipe.fileHandleForReading.availableData, encoding:String.Encoding.utf8) {
                print("\(outputString)")
                output += outputString
            }
            if let errorString = String(data:errorPipe.fileHandleForReading.availableData, encoding:String.Encoding.utf8) {
                print("Error: \(errorString)")
                error += errorString
            }
        }
        return (output, error, task.terminationStatus)
    }
    
    static var allTests : [(String, (DockerTaskTests) -> () throws -> Void)] {
        return [
            ("testPassingOnLinux", testPassingOnLinux) //We only include these tests in allTests for now. It's the only tests that we end up running in Linux
        ]
    }
}
