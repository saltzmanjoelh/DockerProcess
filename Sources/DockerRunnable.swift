//
//  DockerRunnable.swift
//  DockerProcess
//
//  Created by Joel Saltzman on 12/11/16.
//
//

import Foundation
import AsyncProcess

public typealias ProcessResult = (output:String?, error:String?, exitCode:Int32)

public protocol DockerRunnable {
    init(command: String, commandOptions: [String]?, imageName: String?, commandArgs: [String]?)
    @discardableResult
    func launch(printOutput:Bool, outputPrefix: String?) -> ProcessResult
}

extension Process {
    @discardableResult
    static func run(_ launchPath: String, arguments: [String]?, printOutput: Bool = false, outputPrefix: String? = nil, environment: [String:String]? = nil) -> ProcessResult {
        do {
            var output = ""
            var error: String?
            let prefix = outputPrefix != nil ? "\(outputPrefix!): " : ""
            let process = try AsyncProcess(launchPath: launchPath, arguments: arguments)
            process.stdOut { (handle: FileHandle) in
                if let str = String.init(data: handle.availableData as Data, encoding: .utf8) {
                    let line =  "\(prefix)\(str)"
                    output.append(line)
                    if printOutput {
                        print(line)
                    }
                }
                
            }
            process.stdErr { (handle: FileHandle) in
                let str = String.init(data: handle.availableData as Data, encoding: .utf8)!
                print("stdErr: \(str)")
                if error == nil {
                    error = ""
                }
                error?.append(str)
            }
            process.launch()
            while process.executingProcess.isRunning {
                RunLoop.current.run(until: Date.init(timeIntervalSinceNow: TimeInterval(0.10)))
            }
            return (output, error, process.executingProcess.terminationStatus)
            
        } catch let e {
            return (nil, String(describing: e), -1)
        }
    }
    
//    @discardableResult
//    func run(_ printOutput: Bool, outputPrefix: String?) -> ProcessResult {
//        return Process.run(launchPath!, arguments: nil, printOutput: printOutput, outputPrefix: outputPrefix)
//    }
}
