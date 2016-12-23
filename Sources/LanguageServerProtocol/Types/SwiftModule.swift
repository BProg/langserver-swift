//
//  SwiftModule.swift
//  langserver-swift
//
//  Created by Ryan Lovelett on 12/18/16.
//
//

import Argo
import Curry
import Foundation
import Runes
import YamlConvertable
import Yams

/// A module, typically defined and managed by [SwiftPM](), that manages the sources and the compiler arguments
/// that should be sent to SourceKit.
struct SwiftModule {

    let name: String

    let sources: [URL : TextDocument]

    let otherArguments: [String]

    var arguments: [String] {
        return sources.map({ $0.key.path }) + otherArguments
    }

    /// Create a false module that is just a collection of source files in a directory. Ideally
    /// this should not be used since SwiftPM defined modules are preferred.
    ///
    /// - Parameter directory: A directory containing a collection of Swift source files.
    init(_ directory: URL) {
        name = directory.lastPathComponent
        let s = WorkspaceSequence(root: directory).lazy
            .filter({ $0.isFileURL && $0.isFile })
            .filter({ $0.pathExtension.lowercased() == "swift" }) // Check if file is a Swift source file (e.g., has `.swift` extension)
            .flatMap(TextDocument.init)
            .map({ (key: $0.file, value: $0) })
        sources = Dictionary(s)
        otherArguments = []
    }

    /// <#Description#>
    ///
    /// - Parameters:
    ///   - moduleName: <#moduleName description#>
    ///   - locations: <#locations description#>
    ///   - arguments: <#arguments description#>
    init(_ moduleName: String, locations: [URL], arguments: [String] = []) {
        name = moduleName
        sources = Dictionary(locations
            .flatMap(TextDocument.init)
            .map({ (key: $0.file, value: $0) }))
        otherArguments = arguments
    }

}

extension SwiftModule : YamlConvertable {

    /// - TODO: This really should really be part of `YamlConvertable`. Unfortunately the generic version of this
    /// causes the compiler to die.
    /// e.g., this signature
    /// static func decodeAndFilterFailed<T: YamlConvertable>(_ yaml: Node) -> Decoded<[T]> where T == T.DecodedType {
    static func decodeAndFilterFailed(_ yaml: Node) -> Decoded<[SwiftModule]> {
        switch yaml {
        case .mapping(let o):
            //        return .typeMismatch(expected: "Array", actual: "")
            return pure(o.flatMap({ SwiftModule.decode($0.1).value }))
        default:
            return .typeMismatch(expected: "Array", actual: "")
        }
    }


    static func decode(_ yaml: Node) -> Decoded<SwiftModule> {
        let name = flatReduce(["module-name"], initial: yaml, combine: convertedYAML).flatMap(String.decode)
        let sources = flatReduce(["sources"], initial: yaml, combine: convertedYAML).flatMap(Array<URL>.decode)
        let otherArguments = flatReduce(["other-args"], initial: yaml, combine: convertedYAML).flatMap(Array<String>.decode)

        return curry(SwiftModule.init) <^> name <*> sources <*> otherArguments
    }

}
