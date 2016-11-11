import Foundation
import SynchronousProcess

//Create struct Docker : DockerProcess
//Uses same init functions
//has a static var to see if we are using DockerToolbox or DockerForMac, when getting it if it isn't set, we check
//  docker ps, Cannot connect to the Docker daemon. Is the docker daemon running on this host? == DockerToolbox
//launch() checks for type in static var
//  launch creates a new process and calls launch on it to dynamically run the right one

public enum DockerProcessError: Error {
    case invalidConfiguration(message:String)
    
    var description : String {
        get {
            switch (self) {
            case let .invalidConfiguration(message): return message
            }
        }
    }
}

public protocol DockerProcess {
    var launchPath:String { get set }
    var command:String? { get set }
    var commandOptions:[String]? { get set }
    var imageName:String? { get set }
    var commandArgs:[String]? { get set }
    
    init()
    init(command:String, commandOptions:[String]?)//used with non-image related actions like "docker images -a"
    init(command:String, commandOptions:[String]?, imageName:String?, commandArgs:[String]?)
    func shouldPull(image:String) -> Bool
    func launch(silenceOutput:Bool) -> ProcessResult
}
extension DockerProcess {
    public func shouldPull(image:String) -> Bool {
        let imagesResult = Self.init(command:"images", commandOptions:["-a"], commandArgs:nil).launch(silenceOutput: true)
        var images = [String]()
        if let output = imagesResult.output {
            images = output.components(separatedBy: "\n").filter{ $0.hasPrefix(image) }
        }
        return images.count == 0
    }
    public init(command:String, commandOptions:[String]? = nil) {
        self.init(command:command, commandOptions:commandOptions, imageName:nil, commandArgs:nil)
    }
    public init(command:String, commandOptions:[String]? = nil, imageName:String? = nil, commandArgs:[String]? = nil) {
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
}
