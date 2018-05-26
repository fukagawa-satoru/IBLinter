//
//  Runner.swift
//  iblinter
//
//  Created by SaitoYuta on 2018/05/22.
//

import Foundation
import PathKit
import Files

class IBLinterRunner {
    let ibLinterFile: Path
    init(ibLinterFile: Path) {
        self.ibLinterFile = ibLinterFile
    }

    let potentialFolders = [
        Path.current + "/Pods/IBLinter/lib",
        Path("/usr/local/lib/iblinter")
    ]

    func dylibPath() -> Path? {
        guard let libPath = potentialFolders.first(where: { ($0 + "libIBLinterKit.dylib").exists }) else {
            return nil
        }
        return libPath
    }

    func run() {

        func which(_ command: String) -> Path {
            let process = Process()
            process.launchPath = "/bin/sh"
            process.arguments = ["-l", "-c", "which \(command)"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.launch()
            process.waitUntilExit()
            let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
            guard var pathString = String(data: outputData, encoding: .utf8) else {
                exit(1)
            }
            if pathString.count > 0 {
                pathString.removeLast()
            }
            return Path.init(pathString)
        }

        guard let dylib = dylibPath() else {
            print("Could not find a libIBLinterKit to link against at any of: \(potentialFolders)")
            exit(1)
        }

        let marathonPath = try! resolvePackages()
        let artifactPaths = [".build/debug", ".build/release"]

        var arguments = [
            "-L", dylib.string,
            "-I", dylib.string,
            "-lIBLinterKit"
        ]
        if let marathonLibPath = artifactPaths.map({ marathonPath + $0 }).first(where: { $0.exists }) {
            arguments += [
                "-L", marathonLibPath.string,
                "-I", marathonLibPath.string,
                "-lMarathonDependencies",
            ]
        }
        arguments += [ibLinterFile.string]
        let process = Process()
        let swift = which("swift")

        process.launchPath = swift.string
        process.arguments = arguments

        process.launch()
        process.waitUntilExit()
        exit(process.terminationStatus)
    }

    func resolvePackages() throws -> Path {
        let tmpFolder = ".iblinter-tmp"
        let scriptManager = try getScriptManager(tmpFolder: tmpFolder)
        let importExternalDeps = try ibLinterFile.read().components(separatedBy: .newlines)
            .filter { $0.hasPrefix("import") && $0.contains("package: ") }
        let tmpFileName = "_iblinter_imports.swift"
        try Folder(path: tmpFolder).createFileIfNeeded(withName: tmpFileName)
        let tmpFile = try File(path: "\(tmpFolder)/\(tmpFileName)")
        try tmpFile.write(string: importExternalDeps.joined(separator: "\n"))

        let script = try scriptManager.script(atPath: tmpFile.path, allowRemote: true)
        try script.build()

        return Path(script.folder.path)
    }
}
