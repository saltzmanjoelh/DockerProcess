import XCTest
import SynchronousProcess
@testable import DockerProcess

class DockerProcessTests : XCTestCase {
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
        DockerProcess(command:"rm", commandOptions:[containerName]).launch(silenceOutput: true)
    }

    func isRunningDockerForMac() -> Bool {
        let process = DockerProcess()
        return try! process.isDockerForMac()
    }
    
//    func testIsDockerForMac(){
//        do {
//            let process = DockerProcess()
//            
//            let result = try process.isDockerForMac()
//            
//            XCTAssertTrue(result)
//        }catch let error {
//            XCTFail("Error: \(error)")
//        }
//    }
    
    func testVMExists(){
        if isRunningDockerForMac() {
            return //no need to run this test
        }
        let process = DockerProcess(command: "")
        XCTAssertTrue(process.vmExists(name:"default"), "Failed to find Virtual Machine ")
    }
    func testVMDoesNotExist(){
        if isRunningDockerForMac() {
            return //no need to run this test
        }
        
        let process = DockerProcess(command: "")
        XCTAssertFalse(process.vmExists(name:String(describing:UUID())), "Unknown VM should not have been found.")
    }
    func testVmDelete(){
        if isRunningDockerForMac() {
            return //no need to run this test
        }
        
        let vmName = "vmDeleteTest" + UUID().uuidString//docker-machine or VBoxManage uses UUID internally for something, dont' use just UUID
        do {
            let process = DockerProcess()
            try process.vmCreate(name: vmName)
            
            try process.vmDelete(name: vmName)
            
            XCTAssertFalse(process.vmExists(name: vmName))
        }catch let error {
            XCTFail("Error: \(error)")
            
            let cleanupProcess = DockerProcess()
            try! cleanupProcess.vmDelete(name: vmName)//try to cleanup
        }
    }
    func testVmCreate(){
        if isRunningDockerForMac() {
            return //no need to run this test
        }
        
        do {
            let vmName = "vmCreateTest" + UUID().uuidString//docker-machine or VBoxManage uses UUID internally for something, dont' use just UUID
            let process = DockerProcess()
            
            try process.vmCreate(name: vmName)
            
            XCTAssertTrue(process.vmExists(name: vmName))
            try process.vmDelete(name: vmName)//cleanup
        }catch let error {
            XCTFail("Error: \(error)")
        }
    }
    
    func testVmIsRunning(){
        if isRunningDockerForMac() {
            return //no need to run this test
        }
        
        let process = DockerProcess(command: "")
        //        print("Preparing to stop VM. This may take a while")
        //        Process.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(process.machinePath) stop default"], silenceOutput: false)
        //        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        print("Preparing to start VM. This may take a while")
        Process.run("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(process.machinePath) start default"], silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        XCTAssertTrue(process.vmIsRunning(name:"default"), "Failed to find running Virtual Machine ")
    }
    
    func testVmIsNotRunning(){
        if isRunningDockerForMac() {
            return //no need to run this test
        }
        
        let process = DockerProcess(command: "")
        
        print("Preparing to stop VM. This may take a while")
        Process.run("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(process.machinePath) stop default"], silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give Docker a sec to cleanup
        
        XCTAssertFalse(process.vmIsRunning(name:"default"), "Machine should not be running")
    }
    func testEnvironment() {
        if isRunningDockerForMac() {
            return //no need to run this test
        }
        
        let process = DockerProcess(command: "ps")
        do{
            try process.prepareVM()
            
            let environment = try process.environment()
            
            XCTAssertEqual(environment.count, 5, "There should have been 5 keys: \(environment)")
        }catch let error {
            XCTFail("Error: \(error)")
        }
        
    }
    func testContainerNameOption() {
        let command = ["whoami"]
        let result = DockerProcess(command:"run", commandOptions:["--name", containerName, "--rm"], imageName:imageName, commandArgs:command).launch(silenceOutput: false)
        
        XCTAssertEqual(result.exitCode, 0, result.error!)
        XCTAssertNil(result.error)
        XCTAssertNotNil(result.output)
    }
    func testDeleteExistingContainer(){
        //create the container
        DockerProcess(command:"run", commandOptions:["--name", containerName], imageName:imageName, commandArgs:command).launch(silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        let creationResult = DockerProcess(command:"ps", commandOptions:["-a"]).launch(silenceOutput: false)
        XCTAssertNil(creationResult.error)
        if let error = creationResult.error {
            XCTFail("\(error)")
        }
        XCTAssertNotNil(creationResult.output)
        if let output = creationResult.output {
            XCTAssertNotNil(output.contains(containerName), "\(output) should have containerName \(containerName)")
        }
        
        
        //delete the container
        DockerProcess(command:"rm", commandOptions:[containerName]).launch(silenceOutput: false)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        //check if it exists
        let result = DockerProcess(command:"ps", commandOptions:["-a"]).launch(silenceOutput: false)
        
        XCTAssertEqual(result.exitCode, 0)
        if let error = result.error {
            XCTFail("\(error)")
        }
        XCTAssertNotNil(result.output)
        if let output = result.output {
            XCTAssertNil(output.range(of: containerName))
        }

    }
    func testDoesRunInDocker(){
        let macHostname = Process.run("/bin/hostname", arguments: nil).output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
        let hostNameCommand = "hostname"//can't call $(hostname) or `hostname` because the macOS interprets it before docker ; if [ `hostname` == \(name) ]; then echo \(name); fi.
        
        let linuxResult = DockerProcess.init(command: "run", commandOptions: ["--name", containerName, "--rm", "--hostname", containerName], imageName: imageName, commandArgs: ["/bin/bash", "-c", hostNameCommand]).launch(silenceOutput: false)
        
        let linuxHostname = linuxResult.output?.trimmingCharacters(in:NSMutableCharacterSet.newline() as CharacterSet)
        XCTAssertEqual(linuxHostname, containerName)
        XCTAssertNotEqual(linuxHostname, macHostname)
        XCTAssertEqual(linuxResult.exitCode, 0)
    }
    func testDoesRunBashCommand(){
        let bashCommand = "swift --version"
        let commandArgs = ["/bin/bash", "-c", bashCommand]
        
        let result = DockerProcess(command: "run", commandOptions:nil, imageName: imageName, commandArgs: commandArgs).launch(silenceOutput: false)
        if let error = result.error, result.exitCode != 0 {
            XCTFail("Error: \(error)")
        }
        XCTAssertNotNil(result.output)
    }
    func testDoesStripQuotes(){
        //Strip the quotes for the arg after -c
    }
}

