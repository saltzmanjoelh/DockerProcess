import XCTest
import TaskExtension
@testable import DockerTask


class DockerTaskTests: XCTestCase {
    //let containerName = ProcessInfo.processInfo.environment["DOCKER_CONTAINER_NAME"] ?? ProcessInfo.processInfo.environment["PROJECT"]
    let imageName = "saltzmanjoelh/swiftubuntu"
    let command = ["/bin/bash", "-c", "whoami"]
    let containerName = String(UUID())
    
    override func setUp(){
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        continueAfterFailure = false
//        recordFailure(withDescription: "Forced Failure", inFile: String(#file), atLine: 19, expected: true)
    }
    override func tearDown() {
        do {
            RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
            try DockerTask(command:"rm", commandOptions:[containerName]).launchFromToolbox(silenceOutput: false)
        }catch let e{
            
        }
    }
    
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
        print("Preparing to stop VM. This may take a while")
        Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(task.machinePath) stop default"], silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        print("Preparing to start VM. This may take a while")
        Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(task.machinePath) start default"], silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        XCTAssertTrue(task.vmIsRunning(name:"default"), "Failed to find running Virtual Machine ")
    }
    
    func testVmIsNotRunning(){
        let task = DockerTask(command: "")
        
        print("Preparing to stop VM. This may take a while")
        Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(task.machinePath) stop default"], silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        XCTAssertFalse(task.vmIsRunning(name:"default"), "Machine should not be running")
    }
    
    func testContainerNameOption() {
        let command = ["whoami"]

        do{
            print("DockerTask RUN")
            let result = try DockerTask(command:"run", commandOptions:["--name", containerName, "--rm"], imageName:imageName, commandArgs:command).launchFromToolbox(silenceOutput: false)
            
            XCTAssertEqual(result.exitCode, 0)
            XCTAssertNil(result.error)
            XCTAssertNotNil(result.output)
        }catch let e{
            XCTFail("\(e)")
        }
    }
    func testDeleteExistingContainer(){
        do{
            //create the container
            try DockerTask(command:"run", commandOptions:["--name", containerName], imageName:imageName, commandArgs:command).launchFromToolbox(silenceOutput: false)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
            var creationResult = try DockerTask(command:"ps", commandOptions:["-a"]).launchFromToolbox(silenceOutput: false)
//            if creationResult.error != nil {
//                creationResult = try DockerTask(command:"ps", commandOptions:["-a"]).launchFromToolbox(silenceOutput: false)//try again
//            }
            XCTAssertNil(creationResult.error)
            if let error = creationResult.error {
                XCTFail("\(error)")
            }
            XCTAssertNotNil(creationResult.output)
            if let output = creationResult.output {
                XCTAssertNotNil(output.contains(containerName), "\(output) should have containerName \(containerName)")
            }
            
            
            //delete the container
            try DockerTask(command:"rm", commandOptions:[containerName]).launchFromToolbox(silenceOutput: false)
            RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
            //check if it exists
            let result = try DockerTask(command:"ps", commandOptions:["-a"]).launchFromToolbox(silenceOutput: false)
            
            XCTAssertEqual(result.exitCode, 0)
            if let error = result.error {
                XCTFail("\(error)")
            }
            XCTAssertNotNil(result.output)
            if let output = result.output {
                XCTAssertNil(output.range(of: containerName))
            }
        }catch let e{
            XCTFail("\(e)")
        }
    }
    
    func testDoesRunInDocker(){
        do{
            let macHostname = Task.run(launchPath:"/bin/hostname", arguments: nil).output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
            let hostNameCommand = "hostname"//can't call $(hostname) or `hostname` because the macOS interprets it before docker ; if [ `hostname` == \(name) ]; then echo \(name); fi.
            
            let linuxResult = try DockerTask(command: "run", commandOptions: ["--name", containerName, "--rm", "--hostname", containerName], imageName: imageName, commandArgs: ["/bin/bash", "-c", hostNameCommand]).launchFromToolbox(silenceOutput: false)
        
            let linuxHostname = linuxResult.output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
            XCTAssertEqual(linuxHostname, containerName)
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
