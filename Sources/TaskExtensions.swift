//
//  TaskExtensions.swift
//  DockerTask
//
//  Created by Joel Saltzman on 7/27/16.
//
//

import Foundation


extension Task {
    
    public class func runTask(launchPath:String, arguments:[String]?, silenceOutput:Bool = false) -> (output:String?, error:String?, exitCode:Int32) {
        let task = Task()
        task.launchPath = launchPath
        if let launchArguments = arguments {
            task.arguments = launchArguments
        }
        
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
            if !silenceOutput {
                for string in outputString.components(separatedBy: "\n") {
                    print(string)
                }
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
        
        let outputResult : String? = output != "" ? output : nil
        let errorResult : String? = error != "" ? error : nil
        
        return (outputResult, errorResult, task.terminationStatus)
    }
}
