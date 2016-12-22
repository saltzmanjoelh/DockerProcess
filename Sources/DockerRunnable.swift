//
//  DockerRunnable.swift
//  DockerProcess
//
//  Created by Joel Saltzman on 12/11/16.
//
//

import Foundation
import SynchronousProcess

public protocol DockerRunnable {
    init(command: String, commandOptions: [String]?, imageName: String?, commandArgs: [String]?)
    @discardableResult
    func launch(silenceOutput:Bool) -> ProcessResult
}
