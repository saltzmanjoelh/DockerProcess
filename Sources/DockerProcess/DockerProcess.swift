import Foundation
import ProcessRunner

public enum DockerRunOption {
    
    case removeWhenDone
    case container(name: String)
    case workingDirectory(at: String)
    case volume(source: String, destination: String)
    case custom(option: String)
    
    public var processValues: [String] {
        get {
            switch self {
            case .removeWhenDone:
                return ["--rm"]
            case .container(let name):
                return ["--name", name]
            case .workingDirectory(let sourcePath):
                return ["--workdir", sourcePath]
            case .volume(let source, let destination):
                return ["--volume", "\(source):\(destination)"]
            case .custom(let option):
                return [option]
            }
            
        }
    }
}

public enum DockerProcessError: Error {
    case typeDetection(message:String)
    case missingFile(message:String)
    case dockerMachine(message:String)
    case vmFailure(message:String)
    case badEnvironment(message:String)
    
    var description : String {
        get {
            switch (self) {
            case let .typeDetection(message): return message
            case let .missingFile(message): return message
            case let .dockerMachine(message): return message
            case let .vmFailure(message): return message
            case let .badEnvironment(message): return message
            }
        }
    }
}

//Cannot connect to the Docker daemon. Is the docker daemon running on this host?

public struct DockerProcess: DockerRunnable {
    
    public var processRunnable: ProcessRunnable.Type = ProcessRunner.self
    public var launchPath: String = "/usr/local/bin/docker"//"/bin/bash"
    public var command: String? // run, exec, ps
    public var commandOptions: [String]?// --name
    public var imageName: String? // swift
    //You have to be careful when populating this value. Everything after the -c is one string
    public var commandArgs: [String]?// ["/bin/bash", "-c", "echo something"]
    public var shouldSilenceOutput = false
    
    public init(){
        
    }
    public init(command:String, commandOptions:[String]? = nil) {
        self.init(command:command, commandOptions:commandOptions, imageName:nil, commandArgs:nil)
    }
    public init(command: String, commandOptions: [String]? = nil, imageName: String? = nil, commandArgs: [String]? = nil) {
        self.init()
        self.command = command
        self.commandOptions = commandOptions
        self.imageName = imageName
        self.commandArgs = commandArgs
    }
    public var launchArguments: [String] {
        get {
            var arguments = [String]()
            if let cmd = command {
                arguments += [cmd]
            }
            if let options = commandOptions {
                arguments += options
            }
            if let image = imageName{
                arguments += [image]
            }
            if let args = commandArgs {
                arguments += args
            }
            return arguments
        }
    }
    
    public func isDockerForMac() throws -> Bool {
        return true //Dropping docker for toolbox support for now
//        let result = ProcessRunner.synchronousRun("/bin/ls", arguments: ["-al", launchPath], printOutput: false)
//        if let output = result.output {
//            return output.contains("group.com.docker")//symlink to hyperkit container
//        }
//        throw DockerProcessError.typeDetection(message: result.error!)
    }
    
    public var machinePath : String {
        get {
            return URL(fileURLWithPath: launchPath).deletingLastPathComponent().path.appending("/docker-machine")
        }
    }
    public var vBoxManagePath : String {
        get {
            return URL(fileURLWithPath: launchPath).deletingLastPathComponent().path.appending("/VBoxManage")
        }
    }
    
    func validateToolboxPaths() throws {
        let files = [("Docker Machine", machinePath), ("VBoxManage", vBoxManagePath)]
        for file in files {
            guard FileManager.default.fileExists(atPath: file.1) else {
                throw DockerProcessError.missingFile(message: "\(file.0) is missing from path: \(file.1)")
            }
        }
    }
    func vmExists(name:String = "default") -> Bool {
        let result = ProcessRunner.synchronousRun("/bin/bash", arguments: ["-c", "\(vBoxManagePath) list vms | grep \(name)"], printOutput: true)
        return result.output != nil && result.output!.contains(name)
    }
    func vmDelete(name:String = "default") throws {
        //        $DOCKER_MACHINE rm -f $VM &> /dev/null
        let rmVmResult = ProcessRunner.synchronousRun("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) rm -f \(name)"], printOutput: true)
        if let rmVmError = rmVmResult.error, rmVmResult.exitCode != 0 {
            throw DockerProcessError.dockerMachine(message: rmVmError)
        }
        //        rm -rf ~/.docker/machine/machines/$VM
        let rmMachineResult = ProcessRunner.synchronousRun("/bin/rm", arguments: ["-rf", "~/.docker/machine/machines/\(name)"], printOutput: true)
        if let rmMachineError = rmMachineResult.error, rmMachineResult.exitCode != 0 {
            throw DockerProcessError.dockerMachine(message: rmMachineError)
        }
    }
    func vmCreate(name:String = "default") throws {
        //        echo "Creating Machine $VM..." >> $LOG_FILE 2>&1
        //        $DOCKER_MACHINE create -d virtualbox --virtualbox-memory 2048 $VM
        let createResult = ProcessRunner.synchronousRun("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) create -d virtualbox --virtualbox-memory 2048 \(name)"], printOutput: true)
        if let createError = createResult.error, createResult.exitCode != 0 {
            throw DockerProcessError.dockerMachine(message: createError)
        }
    }
    func vmIsRunning(name:String = "default") -> Bool {
        let result = ProcessRunner.synchronousRun("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) status \(name)"], printOutput: true)
        return result.output != nil && result.output!.contains("Running")
    }
    func vmStart(name:String = "default") -> ProcessResult {
        return ProcessRunner.synchronousRun("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) start default"], printOutput: true)
    }
    func getEnvironment(printOutput:Bool = false) throws -> [String:String] {
        let export = "export PATH=/usr/local/bin:$PATH"
        let machine = "/usr/local/bin/docker-machine env --shell=bash default"
        let result = ProcessRunner.synchronousRun("/usr/bin/env", arguments: ["/bin/bash", "-c", "\(export); \(machine)"], printOutput: printOutput)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        if let error = result.error {
            throw DockerProcessError.badEnvironment(message: "Error getting environment: \(error)")
        }
        guard let output = result.output else {
            throw DockerProcessError.badEnvironment(message: "Failed to get any output from docker-machine")
        }
        let lines = output.components(separatedBy: "\n").filter { $0.hasPrefix("export") }
        let environment = lines.reduce(["PATH":"/usr/local/bin"]){ env, line in
            let components = line.components(separatedBy: "=")
            if components.count == 2 {
                let key = components[0].replacingOccurrences(of: "export ", with: "")
                let value = components[1].replacingOccurrences(of: "\n", with: "").replacingOccurrences(of: "\"", with: "")
                var mutableEnv = env
                mutableEnv[key] = value
                return mutableEnv
            }
            return env
        }
        return environment
    }
    
    func prepareVM() throws {
        if(!vmExists()){
            try vmDelete()
            try vmCreate()
        }
        if(!vmIsRunning()){
            let vmResult = vmStart()
            guard vmResult.exitCode != 0  else {
                throw DockerProcessError.vmFailure(message: "Failed starting VM: exitCode: \(vmResult.exitCode)\n\(String(describing: vmResult.error))")
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        }
    }
    
    public func shouldPull(image:String) -> Bool {
        let imagesResult = DockerProcess(command:"images", commandOptions:["-a"], commandArgs:nil).launch(printOutput: false)
        var images = [String]()
        if let output = imagesResult.output {
            images = output.components(separatedBy: "\n").filter{ $0.hasPrefix(image) }
        }
        return images.count == 0
    }
    public static func containerExists(_ containerName: String) -> Bool {
        let containerResult = DockerProcess(command:"ps", commandOptions:["-a", "-f", "name=\(containerName)"], commandArgs:nil).launch(printOutput: false)
        if containerResult.output?.contains(containerName) == true {
            return true
        }
        return false
    }
    
    /*
     Throws if we can't start default virtual machine
     */
    @discardableResult
    public func launch(printOutput:Bool = true, outputPrefix: String? = nil) -> ProcessResult {
        
        print("DockerProcess Launching:\n \"\(launchPath) \(launchArguments.joined(separator: " "))\"")
        
        var isToolbox = false
        do{
            isToolbox = try !isDockerForMac()
            if isToolbox {
                try prepareVM()
            }
        }catch let e {
            //launchpath is not accessible? do you have execute access to the docker binary?
            print("error: \(e)")
            return ProcessResult(output:nil, error:nil, exitCode:-1)//trying to not have this func throw
        }
        
        //Make sure that the image has been pulled first. Otherwise, the error output gets filled with "Unable to find image locally..."
        if let image = imageName {
            if shouldPull(image: image) {
                DockerProcess(command: "pull", commandOptions: [image]).launch()
            }
        }
        
        var environment: [String:String]? = nil
        
        if isToolbox {
            do{
                environment = try getEnvironment(printOutput:printOutput)
            }catch let error {
                return ProcessResult(output:nil, error:"\(error)", exitCode:-1)//trying to not have this func throw
            }
        }
        return self.processRunnable.synchronousRun(launchPath, arguments: launchArguments, printOutput: printOutput, outputPrefix: outputPrefix, environment: environment)
        //        if let error = result.error {
        //            if error.contains("Segmentation fault") {//docker 💩👖, try again
        //                return result
        //            }else{
        //                return ProcessRunner.synchronousRun(printOutput: true)//try again
        //            }
        //        }
    }
    
    
    
}
