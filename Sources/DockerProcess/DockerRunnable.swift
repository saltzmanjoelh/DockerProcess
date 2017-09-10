//
//  DockerRunnable.swift
//  DockerProcess
//
//  Created by Joel Saltzman on 12/11/16.
//
//

import Foundation
import ProcessRunner

public typealias ProcessResult = (output:String?, error:String?, exitCode:Int32)

public protocol DockerRunnable {
    var processRunnable: ProcessRunnable.Type { get set }
    init(command: String, commandOptions: [String]?, imageName: String?, commandArgs: [String]?)
    @discardableResult
    func launch(printOutput:Bool, outputPrefix: String?) -> ProcessResult
}
