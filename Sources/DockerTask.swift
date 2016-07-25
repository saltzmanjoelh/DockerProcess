import Foundation

enum DockerTaskException: ErrorProtocol{
    case invalidConfiguration(message:String)
    var description : String {
        get {
            switch (self) {
            case let .invalidConfiguration(message): return message
            }
        }
    }
}

public struct DockerTask {
    public let command: String
    public let commandOptions: [String]?
    public let imageName: String?
    public let commandArgs: [String]?
    
    public var launchPath: String {
        return ProcessInfo.processInfo.environment["DOCKER_PATH"] ?? "/usr/local/bin/docker"
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
    public func pullArguments() throws -> [String]  {
        guard let image = imageName else {
            throw DockerTaskException.invalidConfiguration(message:"imageName was not set.")
        }
        return ["pull", image]
    }
    
    public static func run(options commandOptions:[String]?, imageName:String, commandArgs:[String]) throws -> (output: String, error: String, exitCode: Int32) {
        let instance = DockerTask(command:"run", commandOptions:commandOptions, imageName:imageName, commandArgs:commandArgs)
        if let options = commandOptions {
            if options.contains("-n") || options.contains("--name") {
                instance.deleteExistingContainer()
            }
        }
        return try instance.launch()
        
    }
    @discardableResult
    public func launch() throws -> (output: String, error: String, exitCode: Int32) {
        if imageName != nil {
            Task.launchedTask(withLaunchPath: launchPath, arguments: try pullArguments())
        }
        
        let task = Task()
        task.launchPath = launchPath
        task.arguments = launchArguments
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        task.launch()
        
        var output = String()
        var error = String()
        while(task.isRunning){
            if let outputString = String(data:outputPipe.fileHandleForReading.availableData, encoding:String.Encoding.utf8) {
                print("\(outputString)")
                output += outputString
            }
            if let errorString = String(data:errorPipe.fileHandleForReading.availableData, encoding:String.Encoding.utf8) {
                print("Error: \(errorString)")
                error += errorString
            }
        }
        
        return (output, error, task.terminationStatus)
    }
    
    public func deleteExistingContainer(){
        guard let options = commandOptions else { return }
        var containerName: String?
        if let index = options.index(of:"-n")  {
            containerName = options[index+1]
        }
        else if let index = options.index(of:"--name") {
            containerName = options[index+1]
        }
        guard let name = containerName else { return }
        
        do {
            try DockerTask(command:"rm", commandOptions:[name], imageName:nil, commandArgs:nil).launch()
        } catch let e {
            print("Exception: \(e)")
        }
    }
}
