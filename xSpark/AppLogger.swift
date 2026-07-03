//
//  AppLogger.swift
//  xSpark
//
//  Drop-in NSLog() replacement — silent in Release builds.
//

import Foundation

nonisolated func xsLog(_ format: String, _ args: CVarArg...) {
#if DEBUG
    Swift.print(String(format: format, arguments: args))
#endif
}
