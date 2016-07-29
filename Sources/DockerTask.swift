import Foundation

public enum DockerTaskException: ErrorProtocol {
    case invalidConfiguration(message:String)
    var description : String {
        get {
            switch (self) {
            case let .invalidConfiguration(message): return message
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
    public let command: String // run, exec, ps
    public let commandOptions: [String]?// --name
    public let imageName: String? // saltzmanojoelh/swiftubuntu
    //You have to be careful when populating this value. Everything after the -c is one string
    public let commandArgs: [String]?// ["/bin/bash", "-c", "echo something"]
    public var shouldSilenceOutput = false
    
    public init(command:String, commandOptions:[String]? = nil, imageName:String? = nil, commandArgs:[String]? = nil) {
        self.command = command
        self.commandOptions = commandOptions
        self.imageName = imageName
        self.commandArgs = commandArgs
    }
    
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
//    public func pullArguments() throws -> [String]  {
//        guard let image = imageName else {
//            throw DockerTaskException.invalidConfiguration(message:"You must set the imageName if you are going to pull")
//        }
//        return ["pull", image]
//    }
    
    @discardableResult
    public func launch(silenceOutput:Bool = false) -> (output:String?, error:String?, exitCode:Int32) {
        //Make sure that the image has been pulled first. Otherwise, the error output gets filled with "Unable to find image locally..."
        if let image = imageName {
            let imagesResult = DockerTask(command:"images", commandOptions:["-a"]).launch(silenceOutput: true)
            if let output = imagesResult.output {
                if output.components(separatedBy: "\n").filter({ (line:String) -> Bool in
                    return line.hasPrefix(image)
                }).count == 0 {
                    DockerTask(command: "pull", commandOptions: [image]).launch()
                }
                
            }
        }
        
//        print("DockerTask Launching:\n\(launchPath) \(launchArguments.joined(separator: " "))")
        
        return Task.runTask(launchPath:launchPath, arguments:launchArguments, silenceOutput:silenceOutput)
    }
}
