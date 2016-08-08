import Foundation
import TaskExtension
//TODO: split toolbox task out
//TODO: protocols?

public enum DockerTaskException: Error {
    case invalidConfiguration(message:String)
    case toolbox(message:String)
    
    var description : String {
        get {
            switch (self) {
            case let .invalidConfiguration(message): return message
            case let .toolbox(message): return message
            }
        }
    }
}
//public struct DockerTaskResult {
//    public let output : String
//    public let error : String
//    public let exitCode : Int32
//}

public struct DockerTask {
    public var launchPath = "/usr/local/bin/docker"
    public let command: String // run, exec, ps
    public let commandOptions: [String]?// --name
    public let imageName: String? // saltzmanojoelh/swiftubuntu
    //You have to be careful when populating this value. Everything after the -c is one string
    public let commandArgs: [String]?// ["/bin/bash", "-c", "echo something"]
    public var shouldSilenceOutput = false
    
    let machinePath = "/usr/local/bin/docker-machine"
    let vBoxManagePath = "/Applications/VirtualBox.app/Contents/MacOS/VBoxManage"
    let startupScript = "/Applications/Docker/Docker Quickstart Terminal.app/Contents/Resources/Scripts/start.sh"
    
    public init(command:String, commandOptions:[String]? = nil, imageName:String? = nil, commandArgs:[String]? = nil) {
        self.command = command
        self.commandOptions = commandOptions
        self.imageName = imageName
        self.commandArgs = commandArgs
    }
    
    public var launchArguments: [String] {
        get {
            var arguments = [command]
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
    public func shouldPull(image:String) -> Bool {
        let imagesResult = DockerTask(command:"images", commandOptions:["-a"]).launch(silenceOutput: true)
        var images = [String]()
        if let output = imagesResult.output {
            images = output.components(separatedBy: "\n").filter{ $0.hasPrefix(image) }
        }
        return images.count == 0
    }
    @discardableResult
    public func launch(silenceOutput:Bool = false) -> (output:String?, error:String?, exitCode:Int32) {
        //Make sure that the image has been pulled first. Otherwise, the error output gets filled with "Unable to find image locally..."
        if let image = imageName {
            if shouldPull(image: image) {
                DockerTask(command: "pull", commandOptions: [image]).launch()
            }
        }
        
        //        print("DockerTask Launching:\n\(launchPath) \(launchArguments.joined(separator: " "))")
        
        return Task.run(launchPath:launchPath, arguments:launchArguments, silenceOutput:silenceOutput)
    }
    
    func validateToolboxPaths() throws {
        
        //        let startupScript = "/Users/asdf/Sites/Linux/DockerTask/start.sh"
        let files = [("Docker Machine", machinePath), ("VBoxManage", vBoxManagePath), ("Docker Startup Script", startupScript)]
        for file in files {
            guard FileManager.default.fileExists(atPath: file.1) else {
                throw DockerTaskException.toolbox(message: "\(file.0) is missing from path: \(file.1)")
            }
        }
    }
    func vmExists(name:String = "default") -> Bool {
        let result = Task.run(launchPath:"/bin/bash", arguments: ["-c", "\(vBoxManagePath) list vms | grep \(name)"], silenceOutput: false)
        return result.output != nil && result.output!.contains(name)
    }
    func vmIsRunning(name:String = "default") -> Bool {
        let result = Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) status \(name)"], silenceOutput: false)
        return result.output != nil && result.output!.contains("Running")
    }
    func vmStart(name:String = "default") throws {
        let result = Task.run(launchPath:"/bin/bash", arguments: ["-c", "export PATH=/usr/local/bin:$PATH && \(machinePath) start default"], silenceOutput: false)
        guard result.output != nil else {
            throw DockerTaskException.toolbox(message: "Failed to start default machine.\n\(result.error)")
        }
    }
    
    @discardableResult
    public func launchFromToolbox(silenceOutput:Bool = false) throws -> (output:String?, error:String?, exitCode:Int32) {
        if(!vmExists()){
            //TODO: create VM
        }
        if(!vmIsRunning()){
            try vmStart()
        }
        let command = "\(launchPath) \(launchArguments.joined(separator: " "))"
        let export = "export PATH=/usr/local/bin:$PATH"
        let environmentVars = "eval $(/usr/local/bin/docker-machine env --shell=bash default)"
        let args = ["/bin/bash", "-c", "\(export); \(environmentVars); \(command)"]
        
//        print("DockerTask Launching:\n/usr/bin/env \(args.joined(separator: " "))")
        return Task.run(launchPath:"/usr/bin/env", arguments: args, silenceOutput: false)
    }
    
    /*
    if [ $DOCKER_REQUIRES_LOGIN -eq 1 ]; then
    #configure vars
    VM=default
    DOCKER_MACHINE=/usr/local/bin/docker-machine
    VBOXMANAGE=/Applications/VirtualBox.app/Contents/MacOS/VBoxManage
    unset DYLD_LIBRARY_PATH
    unset LD_LIBRARY_PATH
    
    #verify apps exist
    if [ ! -f $DOCKER_MACHINE ] || [ ! -f $VBOXMANAGE ]; then
    echo "Either VirtualBox or Docker Machine are not installed. Please re-run the Toolbox Installer and try again." >> $LOG_FILE 2>&1
    exit 1
    fi
    #verify vm exists
    $VBOXMANAGE showvminfo $VM &> /dev/null
    VM_EXISTS_CODE=$?
    
    #create and start if needed
    if [ $VM_EXISTS_CODE -eq 1 ]; then
    echo "Creating Machine $VM..." >> $LOG_FILE 2>&1
    $DOCKER_MACHINE rm -f $VM &> /dev/null
    rm -rf ~/.docker/machine/machines/$VM
    $DOCKER_MACHINE create -d virtualbox --virtualbox-memory 2048 $VM
    else
    echo "Machine $VM already exists in VirtualBox." >> $LOG_FILE 2>&1
    fi
    echo "Starting machine $VM..." >> $LOG_FILE 2>&1
    $DOCKER_MACHINE start $VM
    
    #prepare docker
    echo "Machine started, logging in." >> $LOG_FILE 2>&1
    eval "$(docker-machine env --shell=bash default)" > $LOG_FILE 2>&1
    bash --login >> $LOG_FILE 2>&1
    echo "Logged in, starting image ${DOCKER_IMAGE} and running \"$DOCKER_COMMAND\"" >> $LOG_FILE 2>&1
    fi
    */

    
}
