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
    
    func testVMExists(){
        let task = DockerTask(command: "")
        XCTAssertTrue(task.vmExists(name:"default"), "Failed to find Virtual Machine ")
    }
    func testVMDoesNotExist(){
        let task = DockerTask(command: "")
        XCTAssertFalse(task.vmExists(name:String(UUID())), "Unknown VM should not have been found.")
    }
    func testVmIsRunning(){
        let task = DockerTask(command: "")
        XCTAssertTrue(task.vmIsRunning(name:"default"), "Failed to find running Virtual Machine ")
    }
    func testVmIsNotRunning(){
        let task = DockerTask(command: "")
        Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(task.machinePath) stop default"], silenceOutput: false)
        XCTAssertFalse(task.vmIsRunning(name:"default"), "Machine should not be running")
    }
    
    func testContainerNameOption() {
        let name = String(UUID())
        let command = ["whoami"]

        do{
            let result = try DockerTask(command:"run", commandOptions:["--name", name, "--rm"], imageName:imageName, commandArgs:command).launchFromToolbox(silenceOutput: false)
            
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.output)
        }catch let e{
            XCTFail("\(e)")
        }
    }
    func testDeleteExistingContainer(){
        var containerName = #function
        let range = containerName.index(containerName.endIndex, offsetBy: -2)..<containerName.endIndex
        containerName.removeSubrange(range)
        
        do{
            //create the container
            try DockerTask(command:"run", commandOptions:["--name", containerName], imageName:imageName, commandArgs:command).launchFromToolbox(silenceOutput: false)
            let creationResult = try DockerTask(command:"ps", commandOptions:["-a"]).launchFromToolbox(silenceOutput: false)
            XCTAssertNotNil(creationResult.output)
            XCTAssertNotNil(creationResult.output!.range(of: containerName))
            
            
            //delete the container
            try DockerTask(command:"rm", commandOptions:[containerName]).launchFromToolbox(silenceOutput: false)
            //check if it exists
            let result = try DockerTask(command:"ps", commandOptions:["-a"]).launchFromToolbox(silenceOutput: false)
            
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.output)
            XCTAssertNil(result.output!.range(of: containerName))
        }catch let e{
            XCTFail("\(e)")
        }
    }
    
    func testDoesRunInDocker(){
        do{
            let macHostname = Task.run(launchPath:"/bin/hostname", arguments: nil).output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
            let name = String(UUID())
            let hostNameCommand = "hostname"//can't call $(hostname) or `hostname` because the macOS interprets it before docker ; if [ `hostname` == \(name) ]; then echo \(name); fi.
            
            let linuxResult = try DockerTask(command: "run", commandOptions: ["--name", name, "--rm", "--hostname", name], imageName: imageName, commandArgs: ["/bin/bash", "-c", hostNameCommand]).launchFromToolbox(silenceOutput: false)
        
            let linuxHostname = linuxResult.output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
            XCTAssertEqual(linuxHostname, name)
            XCTAssertNotEqual(linuxHostname, macHostname)
            XCTAssertEqual(linuxResult.exitCode, 0)
        }catch let e{
            XCTFail("\(e)")
        }
    }
    
    static var allTests : [(String, (DockerTaskTests) -> () throws -> Void)] {
        return [
            ("testDoesRunInDocker", testDoesRunInDocker) //We only include these tests in allTests for now. It's the only tests that we end up running in Linux
        ]
    }
}
