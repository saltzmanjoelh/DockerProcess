import Foundation
import SynchronousProcess

//public struct DockerProcessResult {
//    public let output : String
//    public let error : String
//    public let exitCode : Int32
//}

public struct DockerForMacProcess : DockerProcess {
    public var launchPath: String = "/usr/local/bin/docker"
    public var command: String? // run, exec, ps
    public var commandOptions: [String]?// --name
    public var imageName: String? // saltzmanojoelh/swiftubuntu
    //You have to be careful when populating this value. Everything after the -c is one string
    public var commandArgs: [String]?// ["/bin/bash", "-c", "echo something"]
    public var shouldSilenceOutput = false
    
    public init(){
        
    }
    
    @discardableResult
    public func launch(silenceOutput:Bool = false) -> DockerProcessResult {
        //Make sure that the image has been pulled first. Otherwise, the error output gets filled with "Unable to find image locally..."
        if let image = imageName {
            if shouldPull(image: image) {
                DockerForMacProcess(command: "pull", commandOptions: [image]).launch()
            }
        }
        
        //        print("DockerProcess Launching:\n\(launchPath) \(launchArguments.joined(separator: " "))")
        return Process.run(launchPath, arguments:launchArguments, silenceOutput:silenceOutput)
    }
}
