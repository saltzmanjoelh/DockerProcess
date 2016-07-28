import Foundation

enum DockerTaskException: ErrorProtocol {
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
            throw DockerTaskException.invalidConfiguration(message:"You must set the imageName if you are going to pull")
        }
        return ["pull", image]
    }
    
    public static func run(options commandOptions:[String]?, imageName:String, commandArgs:[String]) throws -> (output: String, error: String, exitCode: Int32) {
        let instance = DockerTask(command:"run", commandOptions:commandOptions, imageName:imageName, commandArgs:commandArgs)
        if let options = commandOptions {
            if options.contains("--name") {
                instance.deleteExistingContainer()
            }
        }
        return try instance.launch()
        
    }
    @discardableResult
    public func launch() throws -> (output: String, error: String, exitCode: Int32) {
        if imageName != nil {
            //TODO: silence output
            let pullTask = Task()
            pullTask.launchPath = launchPath
            pullTask.arguments = try pullArguments()
            pullTask.standardOutput = nil
            pullTask.standardError = nil
            pullTask.launch()
        }
        
        let task = Task()
        task.launchPath = launchPath
        task.arguments = launchArguments
//        print("DockerTask Launching:\n\(task.launchPath!) \(task.arguments!.joined(separator: " "))")
        
        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        
        let errorPipe = Pipe()
        task.standardError = errorPipe
        
        task.launch()
        
        var output = String()
        var error = String()
        
        let read = { (pipe:Pipe, toEndOfFile:Bool) -> String? in
            let fileHandle = pipe.fileHandleForReading
            guard let outputString = toEndOfFile ? String(data:fileHandle.readDataToEndOfFile(), encoding:String.Encoding.utf8) : String(data:fileHandle.availableData, encoding:String.Encoding.utf8) else {
                return nil
            }
            if outputString.characters.count == 0 {
                return nil
            }
            for string in outputString.components(separatedBy: "\n") {
                print(string)
            }
            return outputString
        }
        while(task.isRunning){
            if let outputString = read(outputPipe, false) {
                output += outputString
            }
            if let errorString = read(errorPipe, false) {
                error += errorString
            }
        }
        if let outputString = read(outputPipe, true) {
            output += outputString
        }
        if let errorString = read(errorPipe, true) {
            error += errorString
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
