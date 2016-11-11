import XCTest
import SynchronousProcess
@testable import DockerProcess


class DockerProcessTests: XCTestCase {
    //let containerName = ProcessInfo.processInfo.environment["DOCKER_CONTAINER_NAME"] ?? ProcessInfo.processInfo.environment["PROJECT"]
    var classType : DockerProcess?
    let imageName = "saltzmanjoelh/swiftubuntu"
    let command = ["/bin/bash", "-c", "whoami"]
    let containerName = String(describing:UUID())
    
    override func setUp(){
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        continueAfterFailure = false
//        recordFailure(withDescription: "Forced Failure", inFile: String(#file), atLine: 19, expected: true)
    }
    override func tearDown() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        DockerToolboxProcess(command:"rm", commandOptions:[containerName]).launch(silenceOutput: true)
    }
    
    func containerNameOption(processClass:DockerProcess.Type) {
        let command = ["whoami"]
        let result = processClass.init(command:"run", commandOptions:["--name", containerName, "--rm"], imageName:imageName, commandArgs:command).launch(silenceOutput: false)
        
        XCTAssertEqual(result.exitCode, 0)
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.output)
    }
    func deleteExistingContainer(processClass:DockerProcess.Type){
        //create the container
        DockerToolboxProcess(command:"run", commandOptions:["--name", containerName], imageName:imageName, commandArgs:command).launch(silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        let creationResult = processClass.init(command:"ps", commandOptions:["-a"]).launch(silenceOutput: false)
        XCTAssertNil(creationResult.error)
        if let error = creationResult.error {
            XCTFail("\(error)")
        }
        XCTAssertNotNil(creationResult.output)
        if let output = creationResult.output {
            XCTAssertNotNil(output.contains(containerName), "\(output) should have containerName \(containerName)")
        }
        
        
        //delete the container
        DockerToolboxProcess(command:"rm", commandOptions:[containerName]).launch(silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        //check if it exists
        let result = DockerToolboxProcess(command:"ps", commandOptions:["-a"]).launch(silenceOutput: false)
        
        XCTAssertEqual(result.exitCode, 0)
        if let error = result.error {
            XCTFail("\(error)")
        }
        XCTAssertNotNil(result.output)
        if let output = result.output {
            XCTAssertNil(output.range(of: containerName))
        }
    }
    
    func doesRunInDocker(processClass:DockerProcess.Type){
        let macHostname = Process.run("/bin/hostname", arguments: nil).output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
        let hostNameCommand = "hostname"//can't call $(hostname) or `hostname` because the macOS interprets it before docker ; if [ `hostname` == \(name) ]; then echo \(name); fi.
        
        let linuxResult = processClass.init(command: "run", commandOptions: ["--name", containerName, "--rm", "--hostname", containerName], imageName: imageName, commandArgs: ["/bin/bash", "-c", hostNameCommand]).launch(silenceOutput: false)
    
        let linuxHostname = linuxResult.output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
        XCTAssertEqual(linuxHostname, containerName)
        XCTAssertNotEqual(linuxHostname, macHostname)
        XCTAssertEqual(linuxResult.exitCode, 0)
    }
    
    func doesRunBashCommand(processClass:DockerProcess.Type){
        let bashCommand = "swift --version"
        let commandArgs = ["/bin/bash", "-c", bashCommand]
        
        let result = DockerToolboxProcess(command: "run", commandOptions:nil, imageName: imageName, commandArgs: commandArgs).launch(silenceOutput: false)
        if let error = result.error, result.exitCode != 0 {
            XCTFail("Error: \(error)")
        }
        XCTAssertNotNil(result.output)
    }
}



class DockForMacTests : DockerProcessTests {
    func testContainerNameOption() {
        containerNameOption(processClass:DockerForMacProcess.self)
    }
    func testDeleteExistingContainer(){
        deleteExistingContainer(processClass:DockerForMacProcess.self)
    }
    func testDoesRunInDocker(){
        doesRunInDocker(processClass:DockerForMacProcess.self)
    }
    func testDoesRunBashCommand(){
        doesRunBashCommand(processClass:DockerForMacProcess.self)
    }
}



class DockToolboxTests : DockerProcessTests {
    
    func testVMExists(){
        let process = DockerToolboxProcess(command: "")
        XCTAssertTrue(process.vmExists(name:"default"), "Failed to find Virtual Machine ")
    }
    func testVMDoesNotExist(){
        let process = DockerToolboxProcess(command: "")
        XCTAssertFalse(process.vmExists(name:String(describing:UUID())), "Unknown VM should not have been found.")
    }
    func testVmDelete(){
        do {
            let vmName = "vmDeleteTest" + UUID().uuidString//docker-machine or VBoxManage uses UUID internally for something, dont' use just UUID
            let process = DockerToolboxProcess()
            try process.vmCreate(name: vmName)
            
            try process.vmDelete(name: vmName)
            
            XCTAssertFalse(process.vmExists(name: vmName))
        }catch let error {
            XCTFail("Error: \(error)")
        }
    }
    func testVmCreate(){
        do {
            let vmName = "vmCreateTest" + UUID().uuidString//docker-machine or VBoxManage uses UUID internally for something, dont' use just UUID
            let process = DockerToolboxProcess()
            
            try process.vmCreate(name: vmName)
            
            XCTAssertTrue(process.vmExists(name: vmName))
            try process.vmDelete(name: vmName)//cleanup
        }catch let error {
            XCTFail("Error: \(error)")
        }
    }
    
    func testVmIsRunning(){
        let process = DockerToolboxProcess(command: "")
        //        print("Preparing to stop VM. This may take a while")
        //        Process.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(process.machinePath) stop default"], silenceOutput: false)
        //        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        print("Preparing to start VM. This may take a while")
        Process.run("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(process.machinePath) start default"], silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        XCTAssertTrue(process.vmIsRunning(name:"default"), "Failed to find running Virtual Machine ")
    }
    
    func testVmIsNotRunning(){
        let process = DockerToolboxProcess(command: "")
        
        print("Preparing to stop VM. This may take a while")
        Process.run("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(process.machinePath) stop default"], silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        XCTAssertFalse(process.vmIsRunning(name:"default"), "Machine should not be running")
    }
    func testEnvironment() {
        let process = DockerToolboxProcess(command: "ps")
        do{
            try process.prepareVM()
            
            let environment = try process.environment()
            
            XCTAssertEqual(environment.count, 5, "There should have been 5 keys: \(environment)")
        }catch let error {
            XCTFail("Error: \(error)")
        }
        
    }
    func testContainerNameOption() {
        containerNameOption(processClass: DockerToolboxProcess.self)
    }
    func testDeleteExistingContainer(){
        deleteExistingContainer(processClass: DockerToolboxProcess.self)
    }
    func testDoesRunInDocker(){
        doesRunInDocker(processClass: DockerToolboxProcess.self)
    }
    func testDoesRunBashCommand(){
        doesRunBashCommand(processClass:DockerToolboxProcess.self)
    }
    func testDoesStripQuotes(){
        //Strip the quotes for the arg after -c
    }
}

