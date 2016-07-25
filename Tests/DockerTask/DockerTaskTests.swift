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

    static var allTests : [(String, (DockerTaskTests) -> () throws -> Void)] {
        return [
            ("testContainerNameOption", testContainerNameOption),
            ("testDeleteExistingContainer", testDeleteExistingContainer)
        ]
    }
}
