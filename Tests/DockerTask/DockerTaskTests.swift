import XCTest
import TaskExtension
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
        let name = String(UUID())
        let command = ["whoami"]

        let result = DockerTask(command:"run", commandOptions:["--name", name, "--rm"], imageName:imageName, commandArgs:command).launch()
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.output)
        
        
    }
    func testDeleteExistingContainer(){
        var containerName = #function
        let range = containerName.index(containerName.endIndex, offsetBy: -2)..<containerName.endIndex
        containerName.removeSubrange(range)
        
        //create the container
        DockerTask(command:"run", commandOptions:["--name", containerName], imageName:imageName, commandArgs:command).launch(silenceOutput: true)
        let creationResult = DockerTask(command:"ps", commandOptions:["-a"]).launch(silenceOutput: true)
        XCTAssertNotNil(creationResult.output)
        XCTAssertNotNil(creationResult.output!.range(of: containerName))
        
        
        //delete the container
        DockerTask(command:"rm", commandOptions:[containerName]).launch(silenceOutput: true)
        //check if it exists
        let result = DockerTask(command:"ps", commandOptions:["-a"]).launch(silenceOutput: true)
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.output)
        XCTAssertNil(result.output!.range(of: containerName))
    }
    
    func testDoesRunInDocker(){
        let macHostname = Task.run(launchPath:"/bin/hostname", arguments: nil).output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
        let name = String(UUID())
        let hostNameCommand = "if [ `hostname` == \(name) ]; then echo \(name); fi"
        
        let linuxResult = DockerTask(command: "run", commandOptions: ["--name", name, "--rm", "--hostname", name], imageName: imageName, commandArgs: ["/bin/bash", "-c", hostNameCommand]).launch()
    
        let linuxHostname = linuxResult.output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
        XCTAssertEqual(linuxHostname, name)
        XCTAssertNotEqual(linuxHostname, macHostname)
        XCTAssertEqual(linuxResult.exitCode, 0)
    }
    
    static var allTests : [(String, (DockerTaskTests) -> () throws -> Void)] {
        return [
            ("testDoesRunInDocker", testDoesRunInDocker) //We only include these tests in allTests for now. It's the only tests that we end up running in Linux
        ]
    }
}
