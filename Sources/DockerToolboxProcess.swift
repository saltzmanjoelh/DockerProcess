import Foundation
import SynchronousProcess

public enum DockerToolboxError: Error {
    case missingFile(message:String)
    case dockerMachine(message:String)
    case vmFailure(message:String)
    case badEnvironment(message:String)
    
    var description : String {
        get {
            switch (self) {
                case let .missingFile(message): return message
                case let .dockerMachine(message): return message
                case let .vmFailure(message): return message
                case let .badEnvironment(message): return message
            }
        }
    }
}

public struct DockerToolboxProcess : DockerProcess {
    public var launchPath: String = "/usr/local/bin/docker"
    public var command: String? // run, exec, ps
    public var commandOptions: [String]?// --name
    public var imageName: String? // saltzmanojoelh/swiftubuntu
    //You have to be careful when populating this value. Everything after the -c is one string
    public var commandArgs: [String]?// ["/bin/bash", "-c", "echo something"]
    public var shouldSilenceOutput = false
    
    public init(){
        
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
                throw DockerToolboxError.missingFile(message: "\(file.0) is missing from path: \(file.1)")
            }
        }
    }
    func vmExists(name:String = "default") -> Bool {
        let result = Process.run("/bin/bash", arguments: ["-c", "\(vBoxManagePath) list vms | grep \(name)"], silenceOutput: false)
        return result.output != nil && result.output!.contains(name)
    }
//    func vmCreate(name:String = "default") {
//        #create and start if needed
//        if [ $VM_EXISTS_CODE -eq 1 ]; then
//        echo "Creating Machine $VM..." >> $LOG_FILE 2>&1
//        $DOCKER_MACHINE rm -f $VM &> /dev/null
//        rm -rf ~/.docker/machine/machines/$VM
//        $DOCKER_MACHINE create -d virtualbox --virtualbox-memory 2048 $VM
//        else
//        echo "Machine $VM already exists in VirtualBox." >> $LOG_FILE 2>&1
//        fi
//    }
    func vmIsRunning(name:String = "default") -> Bool {
        let result = Process.run("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) status \(name)"], silenceOutput: false)
        return result.output != nil && result.output!.contains("Running")
    }
    func vmStart(name:String = "default") -> ProcessResult {
        return Process.run("/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) start default"], silenceOutput: false)
    }
    func environment(silenceOutput:Bool = true) throws -> [String:String] {
        let export = "export PATH=/usr/local/bin:$PATH"
        let machine = "/usr/local/bin/docker-machine env --shell=bash default"
        let result = Process.run("/usr/bin/env", arguments: ["/bin/bash", "-c", "\(export); \(machine)"], silenceOutput: silenceOutput)
        RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        if let error = result.error {
            throw DockerToolboxError.badEnvironment(message: "Error getting environment: \(error)")
        }
        guard let output = result.output else {
            throw DockerToolboxError.badEnvironment(message: "Failed to get any output from docker-machine")
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
            //TODO: create VM
        }
        if(!vmIsRunning()){
            let vmResult = vmStart()
            guard vmResult.exitCode != 0  else {
                throw DockerToolboxError.vmFailure(message: "Failed starting VM: exitCode: \(vmResult.exitCode)\n\(vmResult.error)")
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        }
    }
    
    /*
     Throws if we can't start default virtual machine
    */
    @discardableResult
    public func launch(silenceOutput:Bool = false) -> ProcessResult {
    
        print("DockerProcess Launching:\n/usr/bin/env \(launchPath) \(launchArguments.joined(separator: " "))")
        
        do{
            try prepareVM()
        }catch _{
            return ProcessResult(output:nil, error:nil, exitCode:-1)//trying to not have this func throw
        }
        
        let process = Process()
        process.launchPath = launchPath
        process.arguments = launchArguments
        do{
            process.environment = try environment(silenceOutput:silenceOutput)
        }catch let error {
            return ProcessResult(output:nil, error:"\(error)", exitCode:-1)//trying to not have this func throw
        }
        
        let result = process.run(silenceOutput)
//        if let error = result.error {
//            if error.contains("Segmentation fault") {//docker 💩👖, try again
//                return result
//            }else{
//                return process.run(silenceOutput: false)//try again
//            }
//        }
        return result
    }
    
    
    
}
