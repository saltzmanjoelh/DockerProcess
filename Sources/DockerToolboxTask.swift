import Foundation
import TaskExtension

public enum DockerToolboxError: Error {
    case missingFile(message:String)
    case dockerMachine(message:String)
    
    var description : String {
        get {
            switch (self) {
                case let .missingFile(message): return message
                case let .dockerMachine(message): return message
            }
        }
    }
}

public struct DockerToolboxTask : DockerTask {
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
        let result = Task.run(launchPath:"/bin/bash", arguments: ["-c", "\(vBoxManagePath) list vms | grep \(name)"], silenceOutput: false)
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
        let result = Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) status \(name)"], silenceOutput: false)
        return result.output != nil && result.output!.contains("Running")
    }
    func vmStart(name:String = "default") -> DockerTaskResult {
        return Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) start default"], silenceOutput: false)
    }
    
    /*
     Throws if we can't start default virtual machine
    */
    @discardableResult
    public func launch(silenceOutput:Bool = false) -> DockerTaskResult {
        if(!vmExists()){
            //TODO: create VM
        }
        if(!vmIsRunning()){
            let vmResult = vmStart()
            guard vmResult.exitCode != 0 else {
                return vmResult
            }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: TimeInterval(0.2)))//give it a sec to clean up
        }
        
        
        let command = "\(launchPath) \(launchArguments.joined(separator: " "))"
        let export = "export PATH=/usr/local/bin:$PATH"
        let environmentVars = "eval $(/usr/local/bin/docker-machine env --shell=bash default)"
        let args = ["/bin/bash", "-c", "\(export); \(environmentVars); \(command)"]
        
        //        print("DockerTask Launching:\n/usr/bin/env \(args.joined(separator: " "))")
        
        let result = Task.run(launchPath:"/usr/bin/env", arguments: args, silenceOutput: false)
        if let error = result.error {
            if error.contains("Segmentation fault") {//docker 💩👖, try again
                return result
            }else{
                return Task.run(launchPath:"/usr/bin/env", arguments: args, silenceOutput: false)//try again
            }
        }
        return result
    }
    
    
    
}
