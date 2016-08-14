import XCTest
import SynchronousTask
@testable import DockerTask


class DockerTaskTests: XCTestCase {
    //let containerName = ProcessInfo.processInfo.environment["DOCKER_CONTAINER_NAME"] ?? ProcessInfo.processInfo.environment["PROJECT"]
    var classType : DockerTask?
    let imageName = "saltzmanjoelh/swiftubuntu"
    let command = ["/bin/bash", "-c", "whoami"]
    let containerName = String(UUID())
    
    override func setUp(){
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        continueAfterFailure = false
//        recordFailure(withDescription: "Forced Failure", inFile: String(#file), atLine: 19, expected: true)
    }
    override func tearDown() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        DockerToolboxTask(command:"rm", commandOptions:[containerName]).launch(silenceOutput: true)
    }
    
    func containerNameOption(taskClass:DockerTask.Type) {
        let command = ["whoami"]
        let result = taskClass.init(command:"run", commandOptions:["--name", containerName, "--rm"], imageName:imageName, commandArgs:command).launch(silenceOutput: false)
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.output)
    }
    func deleteExistingContainer(taskClass:DockerTask.Type){
        //create the container
        DockerToolboxTask(command:"run", commandOptions:["--name", containerName], imageName:imageName, commandArgs:command).launch(silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        let creationResult = taskClass.init(command:"ps", commandOptions:["-a"]).launch(silenceOutput: false)
        XCTAssertNil(creationResult.error)
        if let error = creationResult.error {
            XCTFail("\(error)")
        }
        XCTAssertNotNil(creationResult.output)
        if let output = creationResult.output {
            XCTAssertNotNil(output.contains(containerName), "\(output) should have containerName \(containerName)")
        }
        
        
        //delete the container
        DockerToolboxTask(command:"rm", commandOptions:[containerName]).launch(silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        //check if it exists
        let result = DockerToolboxTask(command:"ps", commandOptions:["-a"]).launch(silenceOutput: false)
        
        XCTAssertEqual(result.exitCode, 0)
        if let error = result.error {
            XCTFail("\(error)")
        }
        XCTAssertNotNil(result.output)
        if let output = result.output {
            XCTAssertNil(output.range(of: containerName))
        }
    }
    
    func doesRunInDocker(taskClass:DockerTask.Type){
        let macHostname = Task.run(launchPath:"/bin/hostname", arguments: nil).output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
        let hostNameCommand = "hostname"//can't call $(hostname) or `hostname` because the macOS interprets it before docker ; if [ `hostname` == \(name) ]; then echo \(name); fi.
        
        let linuxResult = taskClass.init(command: "run", commandOptions: ["--name", containerName, "--rm", "--hostname", containerName], imageName: imageName, commandArgs: ["/bin/bash", "-c", hostNameCommand]).launch(silenceOutput: false)
    
        let linuxHostname = linuxResult.output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
        XCTAssertEqual(linuxHostname, containerName)
        XCTAssertNotEqual(linuxHostname, macHostname)
        XCTAssertEqual(linuxResult.exitCode, 0)
    }
    
    func doesRunBashCommand(taskClass:DockerTask.Type){
        let bashCommand = "swift --version"
        let commandArgs = ["/bin/bash", "-c", bashCommand]
        
        let result = DockerToolboxTask(command: "run", commandOptions:nil, imageName: imageName, commandArgs: commandArgs).launch(silenceOutput: false)
        if let error = result.error, result.exitCode != 0 {
            XCTFail("Error: \(error)")
        }
        XCTAssertNotNil(result.output)
    }
}

class DockForMacTests : DockerTaskTests {
    func testContainerNameOption() {
        containerNameOption(taskClass:DockerForMacTask.self)
    }
    func testDeleteExistingContainer(){
        deleteExistingContainer(taskClass:DockerForMacTask.self)
    }
    func testDoesRunInDocker(){
        doesRunInDocker(taskClass:DockerForMacTask.self)
    }
    func testDoesRunBashCommand(){
        doesRunBashCommand(taskClass:DockerForMacTask.self)
    }
}

class DockToolboxTests : DockerTaskTests {
    func testVMExists(){
        let task = DockerToolboxTask(command: "")
        XCTAssertTrue(task.vmExists(name:"default"), "Failed to find Virtual Machine ")
    }
    func testVMDoesNotExist(){
        let task = DockerToolboxTask(command: "")
        XCTAssertFalse(task.vmExists(name:String(UUID())), "Unknown VM should not have been found.")
    }
    
    func testVmIsRunning(){
        let task = DockerToolboxTask(command: "")
        //        print("Preparing to stop VM. This may take a while")
        //        Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(task.machinePath) stop default"], silenceOutput: false)
        //        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        print("Preparing to start VM. This may take a while")
        Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(task.machinePath) start default"], silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        XCTAssertTrue(task.vmIsRunning(name:"default"), "Failed to find running Virtual Machine ")
    }
    
    func testVmIsNotRunning(){
        let task = DockerToolboxTask(command: "")
        
        print("Preparing to stop VM. This may take a while")
        Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(task.machinePath) stop default"], silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        XCTAssertFalse(task.vmIsRunning(name:"default"), "Machine should not be running")
    }
    func testEnvironment() {
        let task = DockerToolboxTask(command: "ps")
        do{
            try task.prepareVM()
            
            let environment = try task.environment()
            
            XCTAssertEqual(environment.count, 5, "There should have been 5 keys: \(environment)")
        }catch let error {
            XCTFail("Error: \(error)")
        }
        
    }
    func testContainerNameOption() {
        containerNameOption(taskClass: DockerToolboxTask.self)
    }
    func testDeleteExistingContainer(){
        deleteExistingContainer(taskClass: DockerToolboxTask.self)
    }
    func testDoesRunInDocker(){
        doesRunInDocker(taskClass: DockerToolboxTask.self)
    }
    func testDoesRunBashCommand(){
        doesRunBashCommand(taskClass:DockerToolboxTask.self)
    }
    func testDoesStripQuotes(){
        //Strip the quotes for the arg after -c
    }
}
