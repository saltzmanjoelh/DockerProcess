//
//  DockerRunnable.swift
//  DockerProcess
//
//  Created by Joel Saltzman on 12/11/16.
//
//

import Foundation

public protocol DockerRunnable {
    init(command: String, commandOptions: [String]?, imageName: String?, commandArgs: [String]?)
}
